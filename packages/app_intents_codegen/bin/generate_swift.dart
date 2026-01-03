// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:app_intents_codegen/app_intents_codegen.dart';
import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as path;

/// CLI tool for generating Swift code from @IntentSpec and @EntitySpec annotations.
///
/// Usage:
///   dart run app_intents_codegen:generate_swift [options]
///
/// Options:
///   -i, --input     Input directory containing Dart files (default: lib)
///   -o, --output    Output directory for Swift files (default: ios/Runner/GeneratedIntents)
///   -f, --file      Output filename (default: GeneratedAppIntents.swift)
///   -h, --help      Show usage information
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'input',
      abbr: 'i',
      help: 'Input directory containing Dart files',
      defaultsTo: 'lib',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for Swift files',
      defaultsTo: 'ios/Runner/GeneratedIntents',
    )
    ..addOption(
      'file',
      abbr: 'f',
      help: 'Output filename',
      defaultsTo: 'GeneratedAppIntents.swift',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information',
    );

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln();
    _printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  final inputDir = results['input'] as String;
  final outputDir = results['output'] as String;
  final outputFile = results['file'] as String;

  await generateSwift(
    inputDir: inputDir,
    outputDir: outputDir,
    outputFile: outputFile,
  );
}

void _printUsage(ArgParser parser) {
  stdout.writeln('Generate Swift code from @IntentSpec and @EntitySpec annotations.');
  stdout.writeln();
  stdout.writeln('Usage: dart run app_intents_codegen:generate_swift [options]');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(parser.usage);
}

/// Generates Swift code from annotated Dart files.
Future<void> generateSwift({
  required String inputDir,
  required String outputDir,
  required String outputFile,
}) async {
  stdout.writeln('Scanning $inputDir for @IntentSpec and @EntitySpec annotations...');

  final currentDir = Directory.current.path;
  final absoluteInputDir = path.isAbsolute(inputDir)
      ? inputDir
      : path.join(currentDir, inputDir);

  if (!Directory(absoluteInputDir).existsSync()) {
    stderr.writeln('Error: Input directory does not exist: $absoluteInputDir');
    exit(1);
  }

  // Find all Dart files
  final dartFiles = <String>[];
  final glob = Glob('**.dart');
  await for (final entity in glob.list(root: absoluteInputDir)) {
    if (entity is File) {
      // Skip generated files and part files
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
    exit(0);
  }

  stdout.writeln('Found ${dartFiles.length} Dart files');

  // Analyze files (use Maps to deduplicate by identifier)
  final intentsMap = <String, IntentInfo>{};
  final entitiesMap = <String, EntityInfo>{};

  final collection = AnalysisContextCollection(
    includedPaths: [absoluteInputDir],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  final intentAnalyzer = const IntentAnalyzer();
  final entityAnalyzer = const EntityAnalyzer();

  for (final filePath in dartFiles) {
    try {
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedLibrary(filePath);

      if (result is ResolvedLibraryResult) {
        for (final unit in result.units) {
          final library = unit.unit.declaredElement?.library;
          if (library == null) continue;

          for (final element in library.topLevelElements) {
            if (element is ClassElement) {
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
            }
          }
        }
      }
    } catch (e) {
      // Skip files that can't be analyzed (might have syntax errors or missing imports)
      stderr.writeln('  Warning: Could not analyze $filePath: $e');
    }
  }

  final intents = intentsMap.values.toList();
  final entities = entitiesMap.values.toList();

  if (intents.isEmpty && entities.isEmpty) {
    stdout.writeln('No @IntentSpec or @EntitySpec annotations found.');
    exit(0);
  }

  stdout.writeln('');
  stdout.writeln('Found ${intents.length} intents and ${entities.length} entities');

  // Generate Swift code
  final generator = SwiftGenerator();
  final swiftCode = generator.generateAll(
    intents: intents,
    entities: entities,
    shortcuts: [], // TODO: Support shortcuts from annotations
  );

  // Write output
  final absoluteOutputDir = path.isAbsolute(outputDir)
      ? outputDir
      : path.join(currentDir, outputDir);

  final outputDirectory = Directory(absoluteOutputDir);
  if (!outputDirectory.existsSync()) {
    outputDirectory.createSync(recursive: true);
    stdout.writeln('Created output directory: $absoluteOutputDir');
  }

  final outputPath = path.join(absoluteOutputDir, outputFile);
  final file = File(outputPath);

  // Add header comment
  final output = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// Generated by app_intents_codegen')
    ..writeln('// Run `dart run app_intents_codegen:generate_swift` to regenerate')
    ..writeln()
    ..write(swiftCode);

  file.writeAsStringSync(output.toString());

  stdout.writeln('');
  stdout.writeln('Generated Swift code written to: $outputPath');
  stdout.writeln('');
  stdout.writeln('Add this file to your Xcode project to use the generated intents.');
}
