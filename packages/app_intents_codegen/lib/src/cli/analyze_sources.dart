// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart' show InvalidGenerationSourceError;

import '../analyzer/entity_analyzer.dart';
import '../analyzer/enum_analyzer.dart';
import '../analyzer/intent_analyzer.dart';
import '../analyzer/shortcut_analyzer.dart';
import '../analyzer/union_analyzer.dart';
import '../analyzer/widget_configuration_analyzer.dart';
import '../generator/swift_generator.dart';
import '../models/entity_info.dart';
import '../models/enum_info.dart';
import '../models/intent_info.dart';
import '../models/union_info.dart';
import '../models/widget_configuration_info.dart';

/// Result of analyzing source files for annotations.
class AnalyzeResult {
  /// Intents found in the source files.
  final List<IntentInfo> intents;

  /// Entities found in the source files.
  final List<EntityInfo> entities;

  /// Enums found in the source files.
  final List<EnumInfo> enums;

  /// Shortcuts found in the source files.
  final List<AppShortcutInfo> shortcuts;

  /// `@UnionValueSpec` sealed classes found in the source files (#53, #133).
  ///
  /// Collected independently of intent parameters: a union that only exists to
  /// be returned by an `IntentValueQuery` is referenced by no parameter, so
  /// scanning parameters alone would never find it.
  final List<UnionInfo> unions;

  /// Widget configuration intents found in the source files (#98).
  ///
  /// These are generated into a separate Widget Extension file, never into the
  /// app target's output — see [WidgetSwiftGenerator].
  final List<WidgetConfigurationInfo> widgetConfigurations;

  const AnalyzeResult({
    required this.intents,
    required this.entities,
    required this.enums,
    required this.shortcuts,
    this.widgetConfigurations = const [],
    this.unions = const [],
  });

  /// Whether any annotations were found.
  bool get isEmpty => !hasAppTargetAnnotations && widgetConfigurations.isEmpty;

  /// Whether anything the **app target** generator consumes was found.
  ///
  /// [widgetConfigurations] are deliberately excluded: they are generated into
  /// a separate Widget Extension file by `generate_widget_swift`, so a project
  /// that declares only widget configurations has nothing for `generate_swift`
  /// to emit and should not get an otherwise-empty `GeneratedAppIntents.swift`.
  bool get hasAppTargetAnnotations =>
      intents.isNotEmpty ||
      entities.isNotEmpty ||
      enums.isNotEmpty ||
      shortcuts.isNotEmpty ||
      unions.isNotEmpty;
}

/// An annotation an analyzer rejected, with the file it was found in.
class InvalidAnnotation {
  /// Absolute path of the Dart file declaring the annotation.
  final String filePath;

  /// The analyzer's error.
  final InvalidGenerationSourceError error;

  const InvalidAnnotation({required this.filePath, required this.error});

  @override
  String toString() => '$filePath: $error';
}

/// Thrown by [analyzeSourceFiles] when one or more annotations are invalid.
///
/// Every file is still scanned first, so all invalid specs are reported in one
/// run rather than one per invocation.
class InvalidAnnotationsException implements Exception {
  /// The rejected annotations, in scan order.
  final List<InvalidAnnotation> annotations;

  const InvalidAnnotationsException(this.annotations);

  @override
  String toString() =>
      'Found ${annotations.length} invalid annotation(s):\n'
      '${annotations.map((a) => '  $a').join('\n')}';
}

/// Scans and analyzes Dart source files for @IntentSpec, @EntitySpec,
/// @EnumSpec, and @AppShortcutsProvider annotations.
///
/// [inputDir] is the directory to scan (absolute or relative to cwd).
/// Returns an [AnalyzeResult] with all found annotations.
///
/// Throws [InvalidAnnotationsException] if any analyzer rejects an annotation.
/// A file that fails to resolve is skipped with a warning instead.
Future<AnalyzeResult> analyzeSourceFiles(String inputDir) async {
  final currentDir = Directory.current.path;
  final absoluteInputDir = path.isAbsolute(inputDir)
      ? inputDir
      : path.join(currentDir, inputDir);

  if (!Directory(absoluteInputDir).existsSync()) {
    stderr.writeln('Error: Input directory does not exist: $absoluteInputDir');
    exit(1);
  }

  stdout.writeln(
    'Scanning $inputDir for @IntentSpec and @EntitySpec annotations...',
  );

  // Find all Dart files
  final dartFiles = <String>[];
  final glob = Glob('**.dart');
  await for (final entity in glob.list(root: absoluteInputDir)) {
    if (entity is File) {
      final fileName = path.basename(entity.path);
      if (!fileName.endsWith('.g.dart') &&
          !fileName.endsWith('.intent.dart') &&
          !fileName.startsWith('_')) {
        dartFiles.add(entity.path);
      }
    }
  }

  if (dartFiles.isEmpty) {
    stdout.writeln('No Dart files found in $inputDir');
    return const AnalyzeResult(
      intents: [],
      entities: [],
      enums: [],
      shortcuts: [],
      widgetConfigurations: [],
      unions: [],
    );
  }

  stdout.writeln('Found ${dartFiles.length} Dart files');

  // Analyze files (use Maps to deduplicate by identifier)
  final intentsMap = <String, IntentInfo>{};
  final entitiesMap = <String, EntityInfo>{};
  final enumsMap = <String, EnumInfo>{};
  final widgetConfigurationsMap = <String, WidgetConfigurationInfo>{};
  final unionsMap = <String, UnionInfo>{};

  final collection = AnalysisContextCollection(
    includedPaths: [absoluteInputDir],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  final intentAnalyzer = const IntentAnalyzer();
  final entityAnalyzer = const EntityAnalyzer();
  final shortcutAnalyzer = const ShortcutAnalyzer();
  final enumAnalyzer = const EnumAnalyzer();
  final widgetConfigurationAnalyzer = const WidgetConfigurationAnalyzer();
  final unionAnalyzer = const UnionAnalyzer();
  final allShortcuts = <AppShortcutInfo>[];

  final invalidAnnotations = <InvalidAnnotation>[];

  for (final filePath in dartFiles) {
    // Only resolution is recoverable: a file the analyzer cannot resolve is
    // skipped with a warning, as before.
    final ResolvedLibraryResult resolved;
    try {
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedLibrary(filePath);
      if (result is! ResolvedLibraryResult) continue;
      resolved = result;
    } catch (e) {
      stderr.writeln('  Warning: Could not analyze $filePath: $e');
      continue;
    }

    // An analyzer rejecting an annotation is not. Swallowing it here used to
    // drop the spec from the output while the CLI still exited 0.
    try {
      final library = resolved.element;

      for (final element in library.classes) {
        // Check for @IntentSpec
        if (intentAnalyzer.hasIntentSpecAnnotation(element)) {
          final info = intentAnalyzer.analyze(element);
          if (info != null && !intentsMap.containsKey(info.identifier)) {
            intentsMap[info.identifier] = info;
            stdout.writeln('  Found intent: ${info.className}');
          }
        }

        // Check for @EntitySpec
        if (entityAnalyzer.hasEntitySpecAnnotation(element)) {
          final info = entityAnalyzer.analyze(element);
          if (info != null && !entitiesMap.containsKey(info.identifier)) {
            entitiesMap[info.identifier] = info;
            stdout.writeln('  Found entity: ${info.className}');
          }
        }

        // Check for @WidgetConfigurationSpec
        if (widgetConfigurationAnalyzer.hasWidgetConfigurationSpecAnnotation(
          element,
        )) {
          final info = widgetConfigurationAnalyzer.analyze(element);
          if (info != null &&
              !widgetConfigurationsMap.containsKey(info.identifier)) {
            widgetConfigurationsMap[info.identifier] = info;
            stdout.writeln('  Found widget configuration: ${info.className}');
          }
        }

        // Check for @UnionValueSpec
        if (unionAnalyzer.hasUnionValueSpecAnnotation(element)) {
          final info = unionAnalyzer.analyze(element);
          if (info != null && !unionsMap.containsKey(info.identifier)) {
            unionsMap[info.identifier] = info;
            stdout.writeln('  Found union: ${info.className}');
          }
        }

        // Check for @AppShortcutsProvider
        if (shortcutAnalyzer.hasAppShortcutsProviderAnnotation(element)) {
          final shortcuts = shortcutAnalyzer.analyze(element);
          for (final shortcut in shortcuts) {
            allShortcuts.add(shortcut);
            stdout.writeln('  Found shortcut: ${shortcut.shortTitle}');
          }
        }
      }

      // Check for @EnumSpec on enums
      for (final element in library.enums) {
        if (enumAnalyzer.hasEnumSpecAnnotation(element)) {
          final info = enumAnalyzer.analyze(element);
          if (info != null && !enumsMap.containsKey(info.identifier)) {
            enumsMap[info.identifier] = info;
            stdout.writeln('  Found enum: ${info.className}');
          }
        }
      }
    } on InvalidGenerationSourceError catch (e) {
      invalidAnnotations.add(InvalidAnnotation(filePath: filePath, error: e));
    }
  }

  if (invalidAnnotations.isNotEmpty) {
    throw InvalidAnnotationsException(invalidAnnotations);
  }

  final intents = intentsMap.values.toList();
  final entities = entitiesMap.values.toList();
  final enums = enumsMap.values.toList();
  final widgetConfigurations = widgetConfigurationsMap.values.toList();
  final unions = unionsMap.values.toList();

  // Resolve shortcut intentIdentifier to intent className
  final identifierToClassName = <String, String>{
    for (final intent in intents) intent.identifier: intent.className,
  };
  final resolvedShortcuts = allShortcuts.map((s) {
    final className =
        identifierToClassName[s.intentClassName] ?? s.intentClassName;
    return AppShortcutInfo(
      intentClassName: className,
      phrases: s.phrases,
      shortTitle: s.shortTitle,
      systemImageName: s.systemImageName,
    );
  }).toList();

  stdout.writeln('');
  stdout.writeln(
    'Found ${intents.length} intents, ${entities.length} entities, '
    '${enums.length} enums, ${resolvedShortcuts.length} shortcuts, '
    '${unions.length} unions, and '
    '${widgetConfigurations.length} widget configurations',
  );

  return AnalyzeResult(
    intents: intents,
    entities: entities,
    enums: enums,
    shortcuts: resolvedShortcuts,
    widgetConfigurations: widgetConfigurations,
    unions: unions,
  );
}

/// [analyzeSourceFiles] for the CLIs: an invalid annotation is printed to
/// stderr and the process exits 1, instead of generating incomplete output.
Future<AnalyzeResult> analyzeSourceFilesOrExit(String inputDir) async {
  try {
    return await analyzeSourceFiles(inputDir);
  } on InvalidAnnotationsException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
