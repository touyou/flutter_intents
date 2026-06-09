import 'package:app_intents_codegen/src/analyzer/intent_analyzer.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('IntentAnalyzer', () {
    late IntentAnalyzer analyzer;

    setUp(() {
      analyzer = IntentAnalyzer();
    });

    group('analyze', () {
      test(
        'extracts basic intent information from @IntentSpec annotation',
        () async {
          final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
          )
          class GreetIntent extends IntentSpecBase {}
        ''');

          final classElement = findClass(library, 'GreetIntent');

          final result = analyzer.analyze(classElement);

          expect(result, isNotNull);
          expect(result!.className, equals('GreetIntent'));
          expect(result.identifier, equals('com.example.greet'));
          expect(result.title, equals('Greet User'));
          expect(result.description, isNull);
          expect(result.implementation, equals(IntentImplementationType.dart));
        },
      );

      test('extracts description when provided', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
            description: 'Greets the user with a friendly message',
          )
          class GreetIntent extends IntentSpecBase {}
        ''');

        final classElement = findClass(library, 'GreetIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(
          result!.description,
          equals('Greets the user with a friendly message'),
        );
      });

      test('extracts swift implementation type', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
            implementation: IntentImplementation.swift,
          )
          class GreetIntent extends IntentSpecBase {}
        ''');

        final classElement = findClass(library, 'GreetIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.implementation, equals(IntentImplementationType.swift));
      });

      test('extracts parameters with @IntentParam annotation', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
          )
          class GreetIntent extends IntentSpecBase {
            @IntentParam(title: 'User Name')
            final String name;

            @IntentParam(
              title: 'Greeting Message',
              description: 'The message to display',
              isOptional: true,
            )
            final String? message;

            GreetIntent({required this.name, this.message});
          }
        ''');

        final classElement = findClass(library, 'GreetIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.parameters, hasLength(2));

        final nameParam = result.parameters.firstWhere(
          (p) => p.fieldName == 'name',
        );
        expect(nameParam.title, equals('User Name'));
        expect(nameParam.dartType, equals('String'));
        expect(nameParam.isOptional, isFalse);
        expect(nameParam.description, isNull);

        final messageParam = result.parameters.firstWhere(
          (p) => p.fieldName == 'message',
        );
        expect(messageParam.title, equals('Greeting Message'));
        expect(messageParam.dartType, equals('String?'));
        expect(messageParam.isOptional, isTrue);
        expect(messageParam.description, equals('The message to display'));
      });

      test('captures Duration parameter types (#53)', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.startTimer',
            title: 'Start Timer',
          )
          class StartTimerIntent extends IntentSpecBase {
            @IntentParam(title: 'Timer')
            final Duration timer;

            @IntentParam(title: 'Snooze', isOptional: true)
            final Duration? snooze;

            StartTimerIntent({required this.timer, this.snooze});
          }
        ''');

        final result = analyzer.analyze(findClass(library, 'StartTimerIntent'));

        expect(result, isNotNull);
        final timer = result!.parameters.firstWhere(
          (p) => p.fieldName == 'timer',
        );
        expect(timer.dartType, equals('Duration'));
        final snooze = result.parameters.firstWhere(
          (p) => p.fieldName == 'snooze',
        );
        expect(snooze.dartType, equals('Duration?'));
      });

      test('captures PersonName parameter types (#53)', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.setAuthor',
            title: 'Set Author',
          )
          class SetAuthorIntent extends IntentSpecBase {
            @IntentParam(title: 'Author')
            final PersonName author;

            @IntentParam(title: 'Editor', isOptional: true)
            final PersonName? editor;

            SetAuthorIntent({required this.author, this.editor});
          }
        ''');

        final result = analyzer.analyze(findClass(library, 'SetAuthorIntent'));

        expect(result, isNotNull);
        final author = result!.parameters.firstWhere(
          (p) => p.fieldName == 'author',
        );
        expect(author.dartType, equals('PersonName'));
        final editor = result.parameters.firstWhere(
          (p) => p.fieldName == 'editor',
        );
        expect(editor.dartType, equals('PersonName?'));
      });

      test('captures entityCollectionType (#53)', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.tagPhotos',
            title: 'Tag Photos',
          )
          class TagPhotosIntent extends IntentSpecBase {
            @IntentParam(title: 'Photos', entityCollectionType: 'PhotoEntity')
            final List<String> photos;

            TagPhotosIntent({required this.photos});
          }
        ''');

        final result = analyzer.analyze(findClass(library, 'TagPhotosIntent'));

        expect(result, isNotNull);
        final photos = result!.parameters.firstWhere(
          (p) => p.fieldName == 'photos',
        );
        expect(photos.entityCollectionType, equals('PhotoEntity'));
        expect(photos.dartType, equals('List<String>'));
      });

      test('resolves a union-typed parameter (#53)', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @UnionValueSpec(identifier: 'com.example.GalleryContent')
          sealed class GalleryContent {
            const GalleryContent();
          }

          @UnionCase(entityType: 'PhotoEntity')
          class PhotoContent extends GalleryContent {
            final String id;
            const PhotoContent(this.id);
          }

          @UnionCase(entityType: 'AlbumEntity')
          class AlbumContent extends GalleryContent {
            final String id;
            const AlbumContent(this.id);
          }

          @IntentSpec(identifier: 'com.example.openGallery', title: 'Open Gallery')
          class OpenGalleryIntent extends IntentSpecBase {
            @IntentParam(title: 'Content')
            final GalleryContent content;

            OpenGalleryIntent({required this.content});
          }
        ''');

        final result = analyzer.analyze(
          findClass(library, 'OpenGalleryIntent'),
        );

        expect(result, isNotNull);
        final content = result!.parameters.firstWhere(
          (p) => p.fieldName == 'content',
        );
        expect(content.unionInfo, isNotNull);
        expect(content.unionInfo!.className, equals('GalleryContent'));
        expect(content.unionInfo!.cases, hasLength(2));
        expect(
          content.unionInfo!.cases.map((c) => c.entityType),
          containsAll(['PhotoEntity', 'AlbumEntity']),
        );
      });

      test('resolves a nullable union-typed parameter (#53)', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @UnionValueSpec(identifier: 'com.example.GalleryContent')
          sealed class GalleryContent {
            const GalleryContent();
          }

          @UnionCase(entityType: 'PhotoEntity')
          class PhotoContent extends GalleryContent {
            final String id;
            const PhotoContent(this.id);
          }

          @IntentSpec(identifier: 'com.example.openGallery', title: 'Open Gallery')
          class OpenGalleryIntent extends IntentSpecBase {
            @IntentParam(title: 'Content', isOptional: true)
            final GalleryContent? content;

            OpenGalleryIntent({this.content});
          }
        ''');

        final result = analyzer.analyze(
          findClass(library, 'OpenGalleryIntent'),
        );
        final content = result!.parameters.firstWhere(
          (p) => p.fieldName == 'content',
        );
        // Must be resolved for the NULLABLE field too — otherwise the generator
        // would emit the #if-only union type in the stable struct.
        expect(content.unionInfo, isNotNull);
        expect(content.unionInfo!.className, equals('GalleryContent'));
      });

      test('extracts urlScheme and urlAction when provided', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.taskapp.createTask',
            title: 'Create Task',
            urlScheme: 'taskapp',
            urlAction: 'create',
          )
          class CreateTaskIntent extends IntentSpecBase {}
        ''');

        final classElement = findClass(library, 'CreateTaskIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.urlScheme, equals('taskapp'));
        expect(result.urlAction, equals('create'));
      });

      test('urlScheme and urlAction are null when not provided', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
          )
          class GreetIntent extends IntentSpecBase {}
        ''');

        final classElement = findClass(library, 'GreetIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.urlScheme, isNull);
        expect(result.urlAction, isNull);
      });

      test('urlScheme set without urlAction', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.taskapp.createTask',
            title: 'Create Task',
            urlScheme: 'taskapp',
          )
          class CreateTaskIntent extends IntentSpecBase {}
        ''');

        final classElement = findClass(library, 'CreateTaskIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.urlScheme, equals('taskapp'));
        expect(result.urlAction, isNull);
      });

      test('extracts entityType from @IntentParam annotation', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.completeTask',
            title: 'Complete Task',
          )
          class CompleteTaskIntent extends IntentSpecBase {
            @IntentParam(
              title: 'Task',
              entityType: 'TaskEntitySpec',
            )
            final String task;

            CompleteTaskIntent({required this.task});
          }
        ''');

        final classElement = findClass(library, 'CompleteTaskIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.parameters, hasLength(1));
        final param = result.parameters.first;
        expect(param.fieldName, equals('task'));
        expect(param.entityType, equals('TaskEntitySpec'));
      });

      test('extracts resultDialogTemplate when provided', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.createTask',
            title: 'Create Task',
            resultDialogTemplate: 'Created task "{title}"',
          )
          class CreateTaskIntent extends IntentSpecBase {
            @IntentParam(title: 'Title')
            final String title;

            CreateTaskIntent({required this.title});
          }
        ''');

        final classElement = findClass(library, 'CreateTaskIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.resultDialogTemplate, equals('Created task "{title}"'));
      });

      test('resultDialogTemplate is null when not provided', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
          )
          class GreetIntent extends IntentSpecBase {}
        ''');

        final classElement = findClass(library, 'GreetIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.resultDialogTemplate, isNull);
      });

      test('extracts parameterSummary when provided', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.createTask',
            title: 'Create Task',
            parameterSummary: 'Create "{title}"',
          )
          class CreateTaskIntent extends IntentSpecBase {
            @IntentParam(title: 'Title')
            final String title;

            CreateTaskIntent({required this.title});
          }
        ''');

        final classElement = findClass(library, 'CreateTaskIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.parameterSummary, equals('Create "{title}"'));
      });

      test('extracts enumType from @IntentParam annotation', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.createTask',
            title: 'Create Task',
          )
          class CreateTaskIntent extends IntentSpecBase {
            @IntentParam(
              title: 'Priority',
              enumType: 'TaskPriority',
            )
            final String priority;

            CreateTaskIntent({required this.priority});
          }
        ''');

        final classElement = findClass(library, 'CreateTaskIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.parameters, hasLength(1));
        final param = result.parameters.first;
        expect(param.fieldName, equals('priority'));
        expect(param.enumType, equals('TaskPriority'));
      });

      test('returns null for class without @IntentSpec annotation', () async {
        final library = await resolveSource('''
          class PlainClass {}
        ''');

        final classElement = findClass(library, 'PlainClass');

        final result = analyzer.analyze(classElement);

        expect(result, isNull);
      });
    });

    group('hasIntentSpecAnnotation', () {
      test('returns true for class with @IntentSpec annotation', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.test',
            title: 'Test Intent',
          )
          class TestIntent extends IntentSpecBase {}
        ''');

        final classElement = findClass(library, 'TestIntent');

        expect(analyzer.hasIntentSpecAnnotation(classElement), isTrue);
      });

      test('returns false for class without @IntentSpec annotation', () async {
        final library = await resolveSource('''
          class PlainClass {}
        ''');

        final classElement = findClass(library, 'PlainClass');

        expect(analyzer.hasIntentSpecAnnotation(classElement), isFalse);
      });
    });
  });
}
