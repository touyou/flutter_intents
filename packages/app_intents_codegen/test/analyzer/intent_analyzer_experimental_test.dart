import 'package:app_intents_codegen/src/analyzer/intent_analyzer.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('IntentAnalyzer (#131 requestValue)', () {
    late IntentAnalyzer analyzer;

    setUp(() {
      analyzer = IntentAnalyzer();
    });

    test('parses requestValue on an optional primitive parameter', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @IntentSpec(identifier: 'com.example.note', title: 'Note')
        class NoteIntent extends IntentSpecBase {
          @IntentParam(title: 'Note', isOptional: true, requestValue: true)
          final String? note = null;
        }
      ''');

      final result = analyzer.analyze(findClass(library, 'NoteIntent'))!;
      expect(result.parameters.single.requestValue, isTrue);
    });

    test('rejects requestValue on a non-optional parameter', () async {
      // The system already prompts for a missing required parameter before
      // perform() runs, so the request would never fire.
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @IntentSpec(identifier: 'com.example.note', title: 'Note')
        class NoteIntent extends IntentSpecBase {
          @IntentParam(title: 'Note', requestValue: true)
          final String note = '';
        }
      ''');

      expect(
        () => analyzer.analyze(findClass(library, 'NoteIntent')),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('requires an optional parameter'),
          ),
        ),
      );
    });

    for (final mode in const [
      "urlScheme: 'app', urlAction: 'note',",
      'supportedModes: IntentMode.foreground,',
    ]) {
      test(
        'rejects requestValue on a deferred-handler route ($mode)',
        () async {
          // Both routes return from perform() before the Dart handler runs, so
          // there is no running intent left to prompt.
          final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(identifier: 'com.example.note', title: 'Note', $mode)
          class NoteIntent extends IntentSpecBase {
            @IntentParam(title: 'Note', isOptional: true, requestValue: true)
            final String? note = null;
          }
        ''');

          expect(
            () => analyzer.analyze(findClass(library, 'NoteIntent')),
            throwsA(
              isA<InvalidGenerationSourceError>().having(
                (e) => e.message,
                'message',
                contains('needs the FlutterBridge execution mode'),
              ),
            ),
          );
        },
      );
    }

    test('rejects requestValue on an entity parameter', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @IntentSpec(identifier: 'com.example.pick', title: 'Pick')
        class PickIntent extends IntentSpecBase {
          @IntentParam(
            title: 'Task',
            isOptional: true,
            entityType: 'TaskEntity',
            requestValue: true,
          )
          final String? task = null;
        }
      ''');

      expect(
        () => analyzer.analyze(findClass(library, 'PickIntent')),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('only supports primitive parameters'),
          ),
        ),
      );
    });
  });

  group('IntentAnalyzer (WWDC26 experimental fields)', () {
    late IntentAnalyzer analyzer;

    setUp(() {
      analyzer = IntentAnalyzer();
    });

    test(
      'defaults longRunning/cancellable to false and targets to null',
      () async {
        final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @IntentSpec(
          identifier: 'com.example.greet',
          title: 'Greet User',
        )
        class GreetIntent extends IntentSpecBase {}
      ''');

        final result = analyzer.analyze(findClass(library, 'GreetIntent'));

        expect(result!.longRunning, isFalse);
        expect(result.cancellable, isFalse);
        expect(result.executionTargets, isNull);
      },
    );

    test('parses longRunning and cancellable flags', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @IntentSpec(
          identifier: 'com.example.upload',
          title: 'Upload',
          longRunning: true,
          cancellable: true,
        )
        class UploadIntent extends IntentSpecBase {}
      ''');

      final result = analyzer.analyze(findClass(library, 'UploadIntent'));

      expect(result!.longRunning, isTrue);
      expect(result.cancellable, isTrue);
    });

    test('parses executionTargets list in declared order', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @IntentSpec(
          identifier: 'com.example.upload',
          title: 'Upload',
          longRunning: true,
          executionTargets: [
            IntentExecutionTarget.main,
            IntentExecutionTarget.widgetKitExtension,
          ],
        )
        class UploadIntent extends IntentSpecBase {}
      ''');

      final result = analyzer.analyze(findClass(library, 'UploadIntent'));

      expect(
        result!.executionTargets,
        equals(const [
          IntentExecutionTargetType.main,
          IntentExecutionTargetType.widgetKitExtension,
        ]),
      );
    });

    test('rejects longRunning combined with urlScheme', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @IntentSpec(
          identifier: 'com.example.upload',
          title: 'Upload',
          longRunning: true,
          urlScheme: 'taskapp',
        )
        class UploadIntent extends IntentSpecBase {}
      ''');

      expect(
        () => analyzer.analyze(findClass(library, 'UploadIntent')),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    });

    test('parses intent schema field', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @IntentSpec(
          identifier: 'com.example.setRead',
          title: 'Set Read',
          schema: 'messages.setMessageReadStatus',
        )
        class SetReadIntent extends IntentSpecBase {}
      ''');

      final result = analyzer.analyze(findClass(library, 'SetReadIntent'));
      expect(result!.schema, equals('messages.setMessageReadStatus'));
    });

    test('rejects cancellable combined with foreground mode', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @IntentSpec(
          identifier: 'com.example.upload',
          title: 'Upload',
          cancellable: true,
          supportedModes: IntentMode.foreground,
        )
        class UploadIntent extends IntentSpecBase {}
      ''');

      expect(
        () => analyzer.analyze(findClass(library, 'UploadIntent')),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    });
  });
}
