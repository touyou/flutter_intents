// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as path;

import '../analyzer/entity_analyzer.dart';
import '../analyzer/enum_analyzer.dart';
import '../analyzer/intent_analyzer.dart';
import '../analyzer/shortcut_analyzer.dart';
import '../analyzer/widget_configuration_analyzer.dart';
import '../generator/swift_generator.dart';
import '../models/entity_info.dart';
import '../models/enum_info.dart';
import '../models/intent_info.dart';
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
      shortcuts.isNotEmpty;
}

/// Scans and analyzes Dart source files for @IntentSpec, @EntitySpec,
/// @EnumSpec, and @AppShortcutsProvider annotations.
///
/// [inputDir] is the directory to scan (absolute or relative to cwd).
/// Returns an [AnalyzeResult] with all found annotations.
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
    );
  }

  stdout.writeln('Found ${dartFiles.length} Dart files');

  // Analyze files (use Maps to deduplicate by identifier)
  final intentsMap = <String, IntentInfo>{};
  final entitiesMap = <String, EntityInfo>{};
  final enumsMap = <String, EnumInfo>{};
  final widgetConfigurationsMap = <String, WidgetConfigurationInfo>{};

  final collection = AnalysisContextCollection(
    includedPaths: [absoluteInputDir],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  final intentAnalyzer = const IntentAnalyzer();
  final entityAnalyzer = const EntityAnalyzer();
  final shortcutAnalyzer = const ShortcutAnalyzer();
  final enumAnalyzer = const EnumAnalyzer();
  final widgetConfigurationAnalyzer = const WidgetConfigurationAnalyzer();
  final allShortcuts = <AppShortcutInfo>[];

  for (final filePath in dartFiles) {
    try {
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedLibrary(filePath);

      if (result is ResolvedLibraryResult) {
        final library = result.element;

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
      }
    } catch (e) {
      stderr.writeln('  Warning: Could not analyze $filePath: $e');
    }
  }

  final intents = intentsMap.values.toList();
  final entities = entitiesMap.values.toList();
  final enums = enumsMap.values.toList();
  final widgetConfigurations = widgetConfigurationsMap.values.toList();

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
    '${enums.length} enums, ${resolvedShortcuts.length} shortcuts, and '
    '${widgetConfigurations.length} widget configurations',
  );

  return AnalyzeResult(
    intents: intents,
    entities: entities,
    enums: enums,
    shortcuts: resolvedShortcuts,
    widgetConfigurations: widgetConfigurations,
  );
}
