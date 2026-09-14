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

      test('captures useValueState opt-in on optional param (#52)', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(identifier: 'com.example.update', title: 'Update')
          class UpdateIntent extends IntentSpecBase {
            @IntentParam(title: 'Note', isOptional: true, useValueState: true)
            final String? note;

            UpdateIntent({this.note});
          }
        ''');

        final result = analyzer.analyze(findClass(library, 'UpdateIntent'));
        final note = result!.parameters.firstWhere(
          (p) => p.fieldName == 'note',
        );
        expect(note.useValueState, isTrue);
      });

      test('donatable: true accepts a primitive-only intent (#55)', () async {
        final library = await resolveSource('''
            import 'package:app_intents_annotations/app_intents_annotations.dart';

            @IntentSpec(
              identifier: 'com.example.donate',
              title: 'Donate',
              donatable: true,
            )
            class DonateIntent extends IntentSpecBase {
              @IntentParam(title: 'Title')
              final String title;

              @IntentParam(title: 'Note', isOptional: true)
              final String? note;

              @IntentParam(title: 'Due', isOptional: true)
              final DateTime? due;

              DonateIntent({required this.title, this.note, this.due});
            }
          ''');
        final result = analyzer.analyze(findClass(library, 'DonateIntent'));
        expect(result, isNotNull);
        expect(result!.donatable, isTrue);
      });

      test('donatable: true rejects entityType params (#55 MVP)', () async {
        final library = await resolveSource('''
            import 'package:app_intents_annotations/app_intents_annotations.dart';

            @IntentSpec(
              identifier: 'com.example.bad',
              title: 'Bad',
              donatable: true,
            )
            class BadIntent extends IntentSpecBase {
              @IntentParam(title: 'Task', entityType: 'TaskEntity')
              final String taskId;

              BadIntent({required this.taskId});
            }
          ''');
        expect(
          () => analyzer.analyze(findClass(library, 'BadIntent')),
          throwsA(
            isA<Object>().having(
              (e) => e.toString(),
              'message',
              contains('only supports primitive'),
            ),
          ),
        );
      });

      test('donatable: true rejects fileType params (#55 MVP)', () async {
        final library = await resolveSource('''
            import 'package:app_intents_annotations/app_intents_annotations.dart';

            @IntentSpec(
              identifier: 'com.example.bad',
              title: 'Bad',
              donatable: true,
            )
            class BadIntent extends IntentSpecBase {
              @IntentParam(title: 'Photo', fileType: 'public.image')
              final String photoPath;

              BadIntent({required this.photoPath});
            }
          ''');
        expect(
          () => analyzer.analyze(findClass(library, 'BadIntent')),
          throwsA(
            isA<Object>().having(
              (e) => e.toString(),
              'message',
              contains('IntentFile'),
            ),
          ),
        );
      });

      test(
        'donatable: true rejects entityCollectionType params (#55 MVP)',
        () async {
          final library = await resolveSource('''
            import 'package:app_intents_annotations/app_intents_annotations.dart';

            @IntentSpec(
              identifier: 'com.example.bad',
              title: 'Bad',
              donatable: true,
            )
            class BadIntent extends IntentSpecBase {
              @IntentParam(title: 'Photos', entityCollectionType: 'PhotoEntity')
              final List<String> photos;

              BadIntent({required this.photos});
            }
          ''');
          expect(
            () => analyzer.analyze(findClass(library, 'BadIntent')),
            throwsA(
              isA<Object>().having(
                (e) => e.toString(),
                'message',
                contains('entityCollectionType'),
              ),
            ),
          );
        },
      );

      test(
        'donatable: true rejects non-primitive Dart types (#55 MVP)',
        () async {
          final library = await resolveSource('''
            import 'package:app_intents_annotations/app_intents_annotations.dart';

            @IntentSpec(
              identifier: 'com.example.bad',
              title: 'Bad',
              donatable: true,
            )
            class BadIntent extends IntentSpecBase {
              @IntentParam(title: 'Tags')
              final List<String> tags;

              BadIntent({required this.tags});
            }
          ''');
          expect(
            () => analyzer.analyze(findClass(library, 'BadIntent')),
            throwsA(
              isA<Object>().having(
                (e) => e.toString(),
                'message',
                contains('non-primitive type'),
              ),
            ),
          );
        },
      );

      test(
        'useValueState on a non-optional param is a generation error (#52)',
        () async {
          final library = await resolveSource('''
            import 'package:app_intents_annotations/app_intents_annotations.dart';

            @IntentSpec(identifier: 'com.example.bad', title: 'Bad')
            class BadIntent extends IntentSpecBase {
              @IntentParam(title: 'Title', useValueState: true)
              final String title;

              BadIntent({required this.title});
            }
          ''');
          expect(
            () => analyzer.analyze(findClass(library, 'BadIntent')),
            throwsA(
              isA<Object>().having(
                (e) => e.toString(),
                'message',
                contains('requires an optional parameter'),
              ),
            ),
          );
        },
      );

      test('extracts the dual-text dialog fields (ADR 0005)', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.announce',
            title: 'Announce',
            resultDialogTemplate: 'I created the task {title}',
            resultDialogSupportingTemplate: 'Task created',
            resultDialogSystemImageName: 'checkmark.circle',
          )
          class AnnounceIntent extends IntentSpecBase {
            @IntentParam(title: 'Title')
            final String title;

            AnnounceIntent({required this.title});
          }
        ''');
        final info = analyzer.analyze(findClass(library, 'AnnounceIntent'))!;
        expect(info.resultDialogTemplate, 'I created the task {title}');
        expect(info.resultDialogSupportingTemplate, 'Task created');
        expect(info.resultDialogSystemImageName, 'checkmark.circle');
      });

      test(
        'a supporting template without a dialog is a generation error',
        () async {
          // Dropping it silently would look like Siri chose not to show it.
          final library = await resolveSource('''
            import 'package:app_intents_annotations/app_intents_annotations.dart';

            @IntentSpec(
              identifier: 'com.example.bad',
              title: 'Bad',
              resultDialogSupportingTemplate: 'Task created',
            )
            class BadDialogIntent extends IntentSpecBase {
              BadDialogIntent();
            }
          ''');
          expect(
            () => analyzer.analyze(findClass(library, 'BadDialogIntent')),
            throwsA(
              isA<Object>().having(
                (e) => e.toString(),
                'message',
                contains('requires "resultDialogTemplate"'),
              ),
            ),
          );
        },
      );

      test('a dialog symbol without a dialog is a generation error', () async {
        final library = await resolveSource('''
            import 'package:app_intents_annotations/app_intents_annotations.dart';

            @IntentSpec(
              identifier: 'com.example.bad2',
              title: 'Bad',
              resultDialogSystemImageName: 'star',
            )
            class BadSymbolIntent extends IntentSpecBase {
              BadSymbolIntent();
            }
          ''');
        expect(
          () => analyzer.analyze(findClass(library, 'BadSymbolIntent')),
          throwsA(
            isA<Object>().having(
              (e) => e.toString(),
              'message',
              contains('requires "resultDialogTemplate"'),
            ),
          ),
        );
      });

      test('extracts a snippet template (ADR 0007)', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.snippet',
            title: 'Snippet',
            snippet: SnippetTemplate(
              title: '{title}',
              subtitle: 'Saved to {result.listName}',
              systemImageName: 'checkmark.circle.fill',
              rows: [SnippetRow(label: 'Due', value: '{result.dueDate}')],
            ),
          )
          class SnippetIntent extends IntentSpecBase {
            @IntentParam(title: 'Title')
            final String title;

            SnippetIntent({required this.title});
          }
        ''');
        final info = analyzer.analyze(findClass(library, 'SnippetIntent'))!;
        expect(info.snippet, isNotNull);
        expect(info.snippet!.title, '{title}');
        expect(info.snippet!.subtitle, 'Saved to {result.listName}');
        expect(info.snippet!.systemImageName, 'checkmark.circle.fill');
        expect(info.snippet!.rows.single.label, 'Due');
        expect(info.snippet!.rows.single.value, '{result.dueDate}');
      });

      test('rejects {result.…} on a URL scheme intent', () async {
        // perform() opens the app and returns before the handler runs, so the
        // placeholder would render empty on a surface nobody can debug.
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.badsnippet',
            title: 'Bad',
            urlScheme: 'taskapp',
            snippet: SnippetTemplate(title: '{result.name}'),
          )
          class BadUrlSnippetIntent extends IntentSpecBase {
            BadUrlSnippetIntent();
          }
        ''');
        expect(
          () => analyzer.analyze(findClass(library, 'BadUrlSnippetIntent')),
          throwsA(
            isA<Object>().having(
              (e) => e.toString(),
              'message',
              contains('runs through a URL scheme'),
            ),
          ),
        );
      });

      test('rejects {result.…} on a foreground intent', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.badsnippet2',
            title: 'Bad',
            supportedModes: IntentMode.foreground,
            snippet: SnippetTemplate(title: '{result.name}'),
          )
          class BadForegroundSnippetIntent extends IntentSpecBase {
            BadForegroundSnippetIntent();
          }
        ''');
        expect(
          () => analyzer.analyze(
            findClass(library, 'BadForegroundSnippetIntent'),
          ),
          throwsA(
            isA<Object>().having(
              (e) => e.toString(),
              'message',
              contains('IntentMode.foreground'),
            ),
          ),
        );
      });

      test('rejects a placeholder that names no parameter', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.badsnippet3',
            title: 'Bad',
            snippet: SnippetTemplate(title: '{nope}'),
          )
          class BadPlaceholderIntent extends IntentSpecBase {
            @IntentParam(title: 'Title')
            final String title;

            BadPlaceholderIntent({required this.title});
          }
        ''');
        expect(
          () => analyzer.analyze(findClass(library, 'BadPlaceholderIntent')),
          throwsA(
            isA<Object>().having(
              (e) => e.toString(),
              'message',
              contains('is not a parameter of this intent'),
            ),
          ),
        );
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
