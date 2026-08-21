import 'dart:io';

import 'package:app_intents_codegen/app_intents_codegen.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'package:app_intents_codegen/src/cli/analyze_sources.dart';

/// CLI tool for generating Swift code for a WidgetKit Widget Extension target
/// from `@WidgetConfigurationSpec` annotations (#98).
///
/// The output is deliberately separate from `generate_swift`: a Widget
/// Extension cannot start a Flutter engine, so its App Intents read the App
/// Group entity cache instead of calling into Dart. The generated file must be
/// added **only** to the Widget Extension target — compiling the same App
/// Intent type into both the app and the extension duplicates it in
/// `Metadata.appIntents` and breaks intent resolution at runtime.
///
/// Usage:
///   dart run app_intents_codegen:generate_widget_swift [options]
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
      help:
          'Output directory for the Widget Extension Swift file '
          '(e.g. ios/MyWidget/GeneratedIntents)',
    )
    ..addOption(
      'file',
      abbr: 'f',
      help: 'Output filename',
      defaultsTo: 'GeneratedWidgetIntents.swift',
    )
    ..addOption(
      'app-group',
      help:
          'App Group identifier the host app passed to '
          'AppIntentsPlugin.configure(appGroupIdentifier:). Required.',
    )
    ..addOption(
      'storage-identifier',
      help:
          "The host app's bundle identifier (or the explicit storageIdentifier "
          'passed to AppIntentsPlugin.configure). Required — an extension '
          'cannot derive it, because its own bundle identifier differs.',
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

  final outputDir = results['output'] as String?;
  final appGroup = results['app-group'] as String?;
  final storageIdentifier = results['storage-identifier'] as String?;

  final missing = <String>[
    if (outputDir == null || outputDir.isEmpty) '--output',
    if (appGroup == null || appGroup.isEmpty) '--app-group',
    if (storageIdentifier == null || storageIdentifier.isEmpty)
      '--storage-identifier',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('Error: missing required option(s): ${missing.join(', ')}');
    stderr.writeln();
    _printUsage(parser);
    exit(1);
  }

  await generateWidgetSwift(
    inputDir: results['input'] as String,
    outputDir: outputDir!,
    outputFile: results['file'] as String,
    appGroupIdentifier: appGroup!,
    storageIdentifier: storageIdentifier!,
  );
}

void _printUsage(ArgParser parser) {
  stdout.writeln(
    'Generate Widget Extension Swift code from @WidgetConfigurationSpec '
    'annotations.',
  );
  stdout.writeln();
  stdout.writeln(
    'Usage: dart run app_intents_codegen:generate_widget_swift [options]',
  );
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(parser.usage);
  stdout.writeln();
  stdout.writeln('Example:');
  stdout.writeln(
    '  dart run app_intents_codegen:generate_widget_swift \\\n'
    '    -o ios/MyWidget/GeneratedIntents \\\n'
    '    --app-group group.com.example.app \\\n'
    '    --storage-identifier com.example.app',
  );
}

/// Generates Widget Extension Swift code from annotated Dart files.
Future<void> generateWidgetSwift({
  required String inputDir,
  required String outputDir,
  required String outputFile,
  required String appGroupIdentifier,
  required String storageIdentifier,
}) async {
  final analyzeResult = await analyzeSourceFiles(inputDir);

  if (analyzeResult.widgetConfigurations.isEmpty) {
    stdout.writeln('No @WidgetConfigurationSpec annotations found.');
    exit(0);
  }

  final generator = WidgetSwiftGenerator(
    appGroupIdentifier: appGroupIdentifier,
    storageIdentifier: storageIdentifier,
  );
  final swiftCode = generator.generateAll(
    configurations: analyzeResult.widgetConfigurations,
    entities: analyzeResult.entities,
  );

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

  final output = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// Generated by app_intents_codegen')
    ..writeln(
      '// Run `dart run app_intents_codegen:generate_widget_swift` to '
      'regenerate',
    )
    ..writeln('//')
    ..writeln(
      '// Add this file to the Widget Extension target ONLY. Including the '
      'same',
    )
    ..writeln(
      '// App Intent type in both the app target and an extension target '
      'duplicates',
    )
    ..writeln('// it in Metadata.appIntents and breaks intent resolution.')
    ..writeln()
    ..write(swiftCode);

  File(outputPath).writeAsStringSync(output.toString());

  stdout.writeln('');
  stdout.writeln('Generated Widget Extension Swift code: $outputPath');
  stdout.writeln('');
  stdout.writeln('Next steps:');
  stdout.writeln('  1. Add the file to the Widget Extension target (only).');
  stdout.writeln(
    '  2. Add the AppIntentsBridge package to the Widget Extension target.',
  );
  stdout.writeln(
    '  3. Give the extension the App Groups entitlement for '
    '$appGroupIdentifier.',
  );
}
