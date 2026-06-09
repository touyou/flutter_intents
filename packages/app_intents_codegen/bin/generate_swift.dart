import 'dart:io';

import 'package:app_intents_codegen/app_intents_codegen.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'package:app_intents_codegen/src/cli/analyze_sources.dart';

/// CLI tool for generating Swift code from @IntentSpec and @EntitySpec annotations.
///
/// Usage:
///   dart run app_intents_codegen:generate_swift [options]
///
/// Options:
///   -i, --input            Input directory containing Dart files (default: lib)
///   -o, --output           Output directory for Swift files (default: ios/Runner/GeneratedIntents)
///   -f, --file             Output filename (default: GeneratedAppIntents.swift)
///       --xcstrings        Output path for .xcstrings String Catalog file
///   -t, --translations     Path to translations YAML file
///       --source-language  Source language code (default: en)
///   -h, --help             Show usage information
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
    ..addOption(
      'xcstrings',
      help: 'Output path for .xcstrings String Catalog file',
    )
    ..addOption(
      'translations',
      abbr: 't',
      help: 'Path to translations YAML file',
    )
    ..addOption(
      'source-language',
      help: 'Source language code for String Catalog',
      defaultsTo: 'en',
    )
    ..addFlag(
      'experimental-wwdc26',
      negatable: false,
      help:
          'Master switch for opt-in WWDC26 experimental code generation '
          '(default off). Generated code is wrapped in #if APP_INTENTS_WWDC26.',
    )
    ..addMultiOption(
      'experimental',
      help:
          'Narrow experimental generation to specific features '
          '(comma-separated). Requires --experimental-wwdc26. '
          'When omitted (with the master switch on), all features are emitted.',
      allowed: ExperimentalFeature.allFlags,
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
  final xcstringsPath = results['xcstrings'] as String?;
  final translationsPath = results['translations'] as String?;
  final sourceLanguage = results['source-language'] as String;
  final experimental = _resolveExperimental(results);

  await generateSwift(
    inputDir: inputDir,
    outputDir: outputDir,
    outputFile: outputFile,
    xcstringsPath: xcstringsPath,
    translationsPath: translationsPath,
    sourceLanguage: sourceLanguage,
    experimental: experimental,
  );
}

/// Builds the [ExperimentalFeatures] configuration from CLI results.
ExperimentalFeatures _resolveExperimental(ArgResults results) {
  final masterEnabled = results['experimental-wwdc26'] as bool;
  final flags = results['experimental'] as List<String>;

  if (flags.isNotEmpty && !masterEnabled) {
    stderr.writeln(
      'Warning: --experimental was given without --experimental-wwdc26; '
      'no experimental code will be emitted.',
    );
  }

  final enabled = <ExperimentalFeature>{};
  for (final flag in flags) {
    final feature = ExperimentalFeature.fromFlag(flag);
    if (feature != null) enabled.add(feature);
  }

  return ExperimentalFeatures(masterEnabled: masterEnabled, enabled: enabled);
}

void _printUsage(ArgParser parser) {
  stdout.writeln(
    'Generate Swift code from @IntentSpec and @EntitySpec annotations.',
  );
  stdout.writeln();
  stdout.writeln(
    'Usage: dart run app_intents_codegen:generate_swift [options]',
  );
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(parser.usage);
}

/// Generates Swift code from annotated Dart files.
Future<void> generateSwift({
  required String inputDir,
  required String outputDir,
  required String outputFile,
  String? xcstringsPath,
  String? translationsPath,
  String sourceLanguage = 'en',
  ExperimentalFeatures experimental = ExperimentalFeatures.none,
}) async {
  final analyzeResult = await analyzeSourceFiles(inputDir);

  if (analyzeResult.isEmpty) {
    stdout.writeln(
      'No @IntentSpec, @EntitySpec, @EnumSpec, or @AppShortcutsProvider annotations found.',
    );
    exit(0);
  }

  // Generate Swift code
  final generator = SwiftGenerator(experimental: experimental);
  final swiftCode = generator.generateAll(
    intents: analyzeResult.intents,
    entities: analyzeResult.entities,
    shortcuts: analyzeResult.shortcuts,
    enums: analyzeResult.enums,
  );

  // Write output
  final currentDir = Directory.current.path;
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
    ..writeln(
      '// Run `dart run app_intents_codegen:generate_swift` to regenerate',
    )
    ..writeln()
    ..write(swiftCode);

  file.writeAsStringSync(output.toString());

  stdout.writeln('');
  stdout.writeln('Generated Swift code written to: $outputPath');

  // Generate .xcstrings String Catalog if requested
  if (xcstringsPath != null) {
    final absoluteXcstringsPath = path.isAbsolute(xcstringsPath)
        ? xcstringsPath
        : path.join(currentDir, xcstringsPath);

    final xcstringsGenerator = XcstringsGenerator(
      sourceLanguage: sourceLanguage,
    );

    final translations = translationsPath != null
        ? xcstringsGenerator.loadTranslations(
            path.isAbsolute(translationsPath)
                ? translationsPath
                : path.join(currentDir, translationsPath),
          )
        : <String, Map<String, String>>{};

    final xcstringsJson = xcstringsGenerator.generate(
      analyzeResult: analyzeResult,
      translations: translations,
      existingXcstringsPath: File(absoluteXcstringsPath).existsSync()
          ? absoluteXcstringsPath
          : null,
    );

    // Ensure output directory exists
    final xcstringsDir = Directory(path.dirname(absoluteXcstringsPath));
    if (!xcstringsDir.existsSync()) {
      xcstringsDir.createSync(recursive: true);
    }

    File(absoluteXcstringsPath).writeAsStringSync(xcstringsJson);
    stdout.writeln('Generated String Catalog: $absoluteXcstringsPath');
    if (translationsPath != null) {
      stdout.writeln('  Translations loaded from: $translationsPath');
    }
  }

  stdout.writeln('');
  stdout.writeln('Add the generated files to your Xcode project.');
}
