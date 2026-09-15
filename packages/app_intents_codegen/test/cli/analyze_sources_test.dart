import 'dart:convert';
import 'dart:io';

import 'package:app_intents_codegen/src/cli/analyze_sources.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// A spec every analyzer accepts, so a passing run proves the fixture project
/// actually resolves `package:app_intents_annotations`.
const _validIntent = '''
import 'package:app_intents_annotations/app_intents_annotations.dart';

@IntentSpec(identifier: 'com.example.valid', title: 'Valid')
class ValidIntentSpec extends IntentSpecBase {}
''';

/// Compiles fine, but `IntentAnalyzer` rejects it: a supporting template needs
/// the `resultDialogTemplate` it belongs to.
const _invalidIntent = '''
import 'package:app_intents_annotations/app_intents_annotations.dart';

@IntentSpec(
  identifier: 'com.example.invalid',
  title: 'Invalid',
  resultDialogSupportingTemplate: 'Shown on screen',
)
class InvalidIntentSpec extends IntentSpecBase {}
''';

/// Writes a throwaway package whose package config points at the in-repo
/// annotations package, and returns its `lib` directory.
Directory _createFixture(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('analyze_sources_test_');
  addTearDown(() => root.deleteSync(recursive: true));

  final annotationsRoot = path.normalize(
    path.absolute('..', 'app_intents_annotations'),
  );
  File(
    path.join(root.path, 'pubspec.yaml'),
  ).writeAsStringSync('name: fixture\nenvironment:\n  sdk: ^3.10.0\n');
  File(path.join(root.path, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'app_intents_annotations',
            'rootUri': Uri.directory(annotationsRoot).toString(),
            'packageUri': 'lib/',
            'languageVersion': '3.10',
          },
          {
            'name': 'fixture',
            'rootUri': '../',
            'packageUri': 'lib/',
            'languageVersion': '3.10',
          },
        ],
      }),
    );

  final lib = Directory(path.join(root.path, 'lib'))..createSync();
  files.forEach((name, source) {
    File(path.join(lib.path, name)).writeAsStringSync(source);
  });
  return lib;
}

void main() {
  group('analyzeSourceFiles', () {
    test('collects a valid spec', () async {
      final lib = _createFixture({'valid.dart': _validIntent});

      final result = await analyzeSourceFiles(lib.path);

      expect(result.intents.map((i) => i.identifier), ['com.example.valid']);
    });

    test('throws on an invalid annotation instead of skipping it', () async {
      final lib = _createFixture({
        'valid.dart': _validIntent,
        'invalid.dart': _invalidIntent,
      });

      await expectLater(
        analyzeSourceFiles(lib.path),
        throwsA(
          isA<InvalidAnnotationsException>()
              .having((e) => e.annotations, 'annotations', hasLength(1))
              .having(
                (e) => e.annotations.single.filePath,
                'filePath',
                endsWith('invalid.dart'),
              )
              .having(
                (e) => e.toString(),
                'message',
                contains('requires "resultDialogTemplate"'),
              ),
        ),
      );
    });

    test('reports every invalid file, not just the first', () async {
      final lib = _createFixture({
        'invalid_a.dart': _invalidIntent,
        'invalid_b.dart': _invalidIntent.replaceAll('invalid', 'invalidB'),
      });

      await expectLater(
        analyzeSourceFiles(lib.path),
        throwsA(
          isA<InvalidAnnotationsException>().having(
            (e) => e.annotations.map((a) => path.basename(a.filePath)).toSet(),
            'files',
            {'invalid_a.dart', 'invalid_b.dart'},
          ),
        ),
      );
    });
  });

  group('CLI exit status', () {
    final clis = <String, List<String>>{
      'generate_swift': [],
      'generate_widget_swift': [
        '--app-group',
        'group.com.example',
        '--storage-identifier',
        'com.example',
      ],
      'generate_kotlin': ['-p', 'com.example.generated'],
    };

    for (final MapEntry(key: cli, value: extraArgs) in clis.entries) {
      test(
        '$cli exits non-zero and names the file on an invalid annotation',
        () async {
          final lib = _createFixture({'invalid.dart': _invalidIntent});
          final out = Directory(path.join(lib.parent.path, 'out'));

          final result = await Process.run(Platform.resolvedExecutable, [
            'run',
            path.join('bin', '$cli.dart'),
            '-i',
            lib.path,
            '-o',
            out.path,
            ...extraArgs,
          ]);

          expect(result.exitCode, 1, reason: '${result.stderr}');
          expect(result.stderr, contains('invalid.dart'));
          expect(result.stderr, contains('requires "resultDialogTemplate"'));
          expect(out.existsSync(), isFalse);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
  });
}
