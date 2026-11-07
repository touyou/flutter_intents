import 'dart:io';

import 'package:app_intents_codegen/app_intents_codegen.dart';
import 'package:app_intents_codegen/src/cli/analyze_sources.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

/// Prints the declared intents, entities and enums as JSON, with a JSON Schema
/// for each intent's params.
///
/// Usage:
///   dart run app_intents_codegen:describe [-i lib] [-o test/app_intents.json]
///
/// Without `--output` the manifest goes to stdout, so an agent can read what
/// the app can do without launching it. With `--output` it is written to a
/// file that `AppIntentsHarness(manifest: ...)` loads in `flutter test`.
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
      help: 'Write the manifest to this file instead of stdout',
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
    stderr.writeln(parser.usage);
    exit(1);
  }
  if (results['help'] as bool) {
    stdout.writeln(
      'Print declared intents, entities and enums as JSON (with a JSON Schema '
      'for each intent\'s params).',
    );
    stdout.writeln();
    stdout.writeln('Usage: dart run app_intents_codegen:describe [options]');
    stdout.writeln();
    stdout.writeln(parser.usage);
    exit(0);
  }

  final analyzed = await analyzeSourceFilesOrExit(
    results['input'] as String,
    // stdout carries the JSON, so progress output must not land there.
    log: stderr,
  );
  final json = ManifestGenerator().generate(
    intents: analyzed.intents,
    entities: analyzed.entities,
    enums: analyzed.enums,
  );

  final output = results['output'] as String?;
  if (output == null) {
    stdout.write(json);
    return;
  }
  final file = File(
    path.isAbsolute(output)
        ? output
        : path.join(Directory.current.path, output),
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(json);
  stderr.writeln('Manifest written to: ${file.path}');
}
