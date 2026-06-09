import 'package:app_intents_codegen/src/generator/dart_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

void main() {
  group('DartGenerator', () {
    late DartGenerator generator;

    setUp(() {
      generator = const DartGenerator();
    });

    group('generate', () {
      test('returns null when no intents or entities provided', () {
        final result = generator.generate([], []);

        expect(result, isNull);
      });

      test('generates header comment for non-empty output', () {
        final intents = [
          const IntentInfo(
            className: 'TestIntent',
            identifier: 'com.example.test',
            title: 'Test Intent',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains('// GENERATED CODE - DO NOT MODIFY BY HAND'));
      });

      test('does not generate import (part files inherit imports)', () {
        final intents = [
          const IntentInfo(
            className: 'TestIntent',
            identifier: 'com.example.test',
            title: 'Test Intent',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        // Part files inherit imports from the parent library
        expect(
          result,
          isNot(contains("import 'package:app_intents/app_intents.dart'")),
        );
      });

      test('generates initializeAppIntents function', () {
        final intents = [
          const IntentInfo(
            className: 'TestIntent',
            identifier: 'com.example.test',
            title: 'Test Intent',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains('void initializeAppIntents()'));
        expect(result, contains('_registerIntentHandlers()'));
      });
    });

    group('intent handler generation', () {
      test('generates registerIntentHandler call for dart implementation', () {
        final intents = [
          const IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains('_registerIntentHandlers'));
        expect(result, contains("AppIntents().registerIntentHandler"));
        expect(result, contains("'com.example.createTask'"));
      });

      test('skips swift implementation intents', () {
        final intents = [
          const IntentInfo(
            className: 'SwiftIntent',
            identifier: 'com.example.swift',
            title: 'Swift Intent',
            implementation: IntentImplementationType.swift,
            parameters: [],
          ),
        ];

        final result = generator.generate(intents, []);

        // Should be null because only swift intents are provided
        expect(result, isNull);
      });

      test('generates Params class with fromMap for parameters', () {
        final intents = [
          const IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'title',
                dartType: 'String',
                title: 'Task Title',
                isOptional: false,
              ),
              IntentParamInfo(
                fieldName: 'priority',
                dartType: 'int',
                title: 'Priority',
                isOptional: false,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        // Params class
        expect(result, contains('class CreateTaskIntentParams'));
        expect(result, contains('final String title'));
        expect(result, contains('final int priority'));
        expect(result, contains('required this.title'));
        expect(result, contains('required this.priority'));
        // fromMap
        expect(result, contains('fromMap(Map<String, dynamic> map)'));
        expect(result, contains("map['title'] as String"));
        expect(result, contains("map['priority'] as int"));
        // fromQueryParameters
        expect(result, contains('fromQueryParameters'));
        expect(result, contains('Map<String, String> params'));
        expect(result, contains("params['title']!"));
        expect(result, contains("int.parse(params['priority']!)"));
      });

      test('generates Params class with nullable parameters', () {
        final intents = [
          const IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'dueDate',
                dartType: 'DateTime?',
                title: 'Due Date',
                isOptional: true,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains('class CreateTaskIntentParams'));
        expect(result, contains('final DateTime? dueDate'));
        // fromMap - nullable DateTime
        expect(result, contains("map['dueDate'] != null"));
        expect(result, contains("DateTime.parse(map['dueDate'] as String)"));
        // fromQueryParameters - nullable DateTime
        expect(result, contains("params['dueDate'] != null"));
        expect(result, contains("DateTime.tryParse(params['dueDate']!)"));
      });

      test('generates Params class with Duration parameters (#53)', () {
        final intents = [
          const IntentInfo(
            className: 'StartTimerIntent',
            identifier: 'com.example.startTimer',
            title: 'Start Timer',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'timer',
                dartType: 'Duration',
                title: 'Timer',
                isOptional: false,
              ),
              IntentParamInfo(
                fieldName: 'snooze',
                dartType: 'Duration?',
                title: 'Snooze',
                isOptional: true,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, contains('final Duration timer'));
        expect(result, contains('final Duration? snooze'));
        // Swift serializes Duration as an Int of microseconds.
        expect(result, contains("Duration(microseconds: map['timer'] as int)"));
        expect(result, contains("map['snooze'] != null"));
        expect(
          result,
          contains("Duration(microseconds: map['snooze'] as int)"),
        );
        // fromQueryParameters
        expect(
          result,
          contains("Duration(microseconds: int.parse(params['timer']!))"),
        );
        expect(result, contains("params['snooze'] != null"));
      });

      test('generates Params class with PersonName parameters (#53)', () {
        final intents = [
          const IntentInfo(
            className: 'SetAuthorIntent',
            identifier: 'com.example.setAuthor',
            title: 'Set Author',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'author',
                dartType: 'PersonName',
                title: 'Author',
                isOptional: false,
              ),
              IntentParamInfo(
                fieldName: 'editor',
                dartType: 'PersonName?',
                title: 'Editor',
                isOptional: true,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, contains('final PersonName author'));
        expect(result, contains('final PersonName? editor'));
        // fromMap: PersonName arrives as a component Map (assert on substrings
        // that survive dart format's line wrapping).
        expect(result, contains('PersonName.fromMap('));
        expect(result, contains("map['author'] as Map"));
        expect(result, contains("map['editor'] != null"));
        expect(result, contains("map['editor'] as Map"));
        // fromQueryParameters: URL carries only the given name.
        expect(
          result,
          contains("PersonName(givenName: params['author']!)"),
        );
        expect(
          result,
          contains("PersonName(givenName: params['editor'])"),
        );
      });

      test('generates handler using Params class with named parameters', () {
        final intents = [
          const IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'title',
                dartType: 'String',
                title: 'Task Title',
                isOptional: false,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains('CreateTaskIntentParams.fromMap(params)'));
        expect(result, contains('createTaskIntentHandler'));
        expect(result, contains('title: p.title'));
      });

      test('always returns empty map from handler', () {
        final intents = [
          const IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains('return <String, dynamic>{}'));
        expect(result, isNot(contains('toJson')));
      });

      test('does not generate Params class for parameterless intents', () {
        final intents = [
          const IntentInfo(
            className: 'OpenAppIntent',
            identifier: 'com.example.openApp',
            title: 'Open App',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, isNot(contains('class OpenAppIntentParams')));
        expect(result, contains('openAppIntentHandler'));
      });

      test('generates multiple intent handlers', () {
        final intents = [
          const IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
          const IntentInfo(
            className: 'DeleteTaskIntent',
            identifier: 'com.example.deleteTask',
            title: 'Delete Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains("'com.example.createTask'"));
        expect(result, contains("'com.example.deleteTask'"));
        expect(result, contains('createTaskIntentHandler'));
        expect(result, contains('deleteTaskIntentHandler'));
      });
    });

    group('entity handler generation', () {
      test('generates registerEntityQueryHandler call', () {
        final entities = [
          const EntityInfo(
            className: 'TaskEntity',
            identifier: 'com.example.TaskEntity',
            title: 'Task',
            pluralTitle: 'Tasks',
            properties: [
              EntityPropertyInfo(
                fieldName: 'id',
                dartType: 'String',
                role: EntityPropertyRole.id,
              ),
            ],
          ),
        ];

        final result = generator.generate([], entities);

        expect(result, isNotNull);
        expect(result, contains('_registerEntityHandlers'));
        expect(result, contains('registerEntityQueryHandler'));
        expect(result, contains("'com.example.TaskEntity'"));
      });

      test('generates entity query handler with toJson call', () {
        final entities = [
          const EntityInfo(
            className: 'TaskEntity',
            identifier: 'com.example.TaskEntity',
            title: 'Task',
            pluralTitle: 'Tasks',
            properties: [],
          ),
        ];

        final result = generator.generate([], entities);

        expect(result, isNotNull);
        expect(result, contains('taskEntityQuery'));
        expect(result, contains('toJson'));
      });

      test(
        'generates registerSuggestedEntitiesHandler when defaultQuery exists',
        () {
          final entities = [
            const EntityInfo(
              className: 'TaskEntity',
              identifier: 'com.example.TaskEntity',
              title: 'Task',
              pluralTitle: 'Tasks',
              properties: [
                EntityPropertyInfo(
                  fieldName: 'defaultQuery',
                  dartType: 'List<Task>',
                  role: EntityPropertyRole.defaultQuery,
                ),
              ],
            ),
          ];

          final result = generator.generate([], entities);

          expect(result, isNotNull);
          expect(result, contains('registerSuggestedEntitiesHandler'));
          expect(result, contains('taskEntitySuggestedEntities'));
        },
      );

      test(
        'always generates registerSuggestedEntitiesHandler for entities',
        () {
          final entities = [
            const EntityInfo(
              className: 'TaskEntity',
              identifier: 'com.example.TaskEntity',
              title: 'Task',
              pluralTitle: 'Tasks',
              properties: [
                EntityPropertyInfo(
                  fieldName: 'id',
                  dartType: 'String',
                  role: EntityPropertyRole.id,
                ),
              ],
            ),
          ];

          final result = generator.generate([], entities);

          expect(result, isNotNull);
          expect(result, contains('registerSuggestedEntitiesHandler'));
          expect(result, contains('taskEntitySuggestedEntities'));
        },
      );

      test('generates multiple entity handlers', () {
        final entities = [
          const EntityInfo(
            className: 'TaskEntity',
            identifier: 'com.example.TaskEntity',
            title: 'Task',
            pluralTitle: 'Tasks',
            properties: [],
          ),
          const EntityInfo(
            className: 'ProjectEntity',
            identifier: 'com.example.ProjectEntity',
            title: 'Project',
            pluralTitle: 'Projects',
            properties: [],
          ),
        ];

        final result = generator.generate([], entities);

        expect(result, isNotNull);
        expect(result, contains("'com.example.TaskEntity'"));
        expect(result, contains("'com.example.ProjectEntity'"));
        expect(result, contains('taskEntityQuery'));
        expect(result, contains('projectEntityQuery'));
      });
    });

    group('handler function name generation', () {
      test('generates camelCase handler name from PascalCase class name', () {
        final intents = [
          const IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains('createTaskIntentHandler'));
      });

      test('generates camelCase query handler name from entity class name', () {
        final entities = [
          const EntityInfo(
            className: 'TaskEntity',
            identifier: 'com.example.TaskEntity',
            title: 'Task',
            pluralTitle: 'Tasks',
            properties: [],
          ),
        ];

        final result = generator.generate([], entities);

        expect(result, isNotNull);
        expect(result, contains('taskEntityQuery'));
      });
    });

    group('complete output structure', () {
      test('generates complete output with intents and entities', () {
        final intents = [
          const IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'title',
                dartType: 'String',
                title: 'Task Title',
                isOptional: false,
              ),
            ],
          ),
        ];

        final entities = [
          const EntityInfo(
            className: 'TaskEntity',
            identifier: 'com.example.TaskEntity',
            title: 'Task',
            pluralTitle: 'Tasks',
            properties: [
              EntityPropertyInfo(
                fieldName: 'defaultQuery',
                dartType: 'List<Task>',
                role: EntityPropertyRole.defaultQuery,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, entities);

        expect(result, isNotNull);
        // Check structure (no import since it's a part file)
        expect(result, contains('// GENERATED CODE - DO NOT MODIFY BY HAND'));
        expect(
          result,
          isNot(contains("import 'package:app_intents/app_intents.dart'")),
        );
        // Check Params class
        expect(result, contains('class CreateTaskIntentParams'));
        expect(result, contains('fromMap'));
        expect(result, contains('fromQueryParameters'));
        // Check functions
        expect(result, contains('void initializeAppIntents()'));
        expect(result, contains('void _registerIntentHandlers()'));
        expect(result, contains('void _registerEntityHandlers()'));
        // Check intent handler uses Params class
        expect(result, contains('CreateTaskIntentParams.fromMap(params)'));
        expect(result, contains('createTaskIntentHandler'));
        // Check entity handlers
        expect(result, contains('taskEntityQuery'));
        expect(result, contains('taskEntitySuggestedEntities'));
      });
    });

    group('DateTime handling in Params class', () {
      test('generates DateTime parsing in fromMap and fromQueryParameters', () {
        final intents = [
          const IntentInfo(
            className: 'ScheduleTaskIntent',
            identifier: 'com.example.scheduleTask',
            title: 'Schedule Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'scheduledDate',
                dartType: 'DateTime',
                title: 'Scheduled Date',
                isOptional: false,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains('class ScheduleTaskIntentParams'));
        // fromMap
        expect(
          result,
          contains("DateTime.parse(map['scheduledDate'] as String)"),
        );
        // fromQueryParameters
        expect(result, contains("DateTime.parse(params['scheduledDate']!)"));
      });

      test('generates nullable DateTime parsing in Params class', () {
        final intents = [
          const IntentInfo(
            className: 'ScheduleTaskIntent',
            identifier: 'com.example.scheduleTask',
            title: 'Schedule Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'dueDate',
                dartType: 'DateTime?',
                title: 'Due Date',
                isOptional: true,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        // fromMap - nullable
        expect(result, contains("map['dueDate'] != null"));
        expect(result, contains("DateTime.parse(map['dueDate'] as String)"));
        // fromQueryParameters - nullable
        expect(result, contains("params['dueDate'] != null"));
        expect(result, contains("DateTime.tryParse(params['dueDate']!)"));
      });
    });

    group('IntentFile handling in Params class', () {
      test('generates IntentFile.fromMap in Params class', () {
        final intents = [
          const IntentInfo(
            className: 'CreatePostIntent',
            identifier: 'com.example.createPost',
            title: 'Create Post',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'image',
                dartType: 'IntentFile',
                title: 'Image',
                isOptional: false,
                fileType: 'public.image',
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        expect(result, contains('class CreatePostIntentParams'));
        // fromMap should have IntentFile.fromMap
        expect(result, contains('IntentFile.fromMap'));
        expect(result, contains("map['image']"));
        // Required IntentFile: no fromQueryParameters
        expect(result, isNot(contains('fromQueryParameters')));
      });

      test(
        'generates nullable IntentFile in Params class with fromQueryParameters',
        () {
          final intents = [
            const IntentInfo(
              className: 'CreatePostIntent',
              identifier: 'com.example.createPost',
              title: 'Create Post',
              implementation: IntentImplementationType.dart,
              parameters: [
                IntentParamInfo(
                  fieldName: 'text',
                  dartType: 'String',
                  title: 'Text',
                  isOptional: false,
                ),
                IntentParamInfo(
                  fieldName: 'image',
                  dartType: 'IntentFile?',
                  title: 'Image',
                  isOptional: true,
                  fileType: 'public.image',
                ),
              ],
            ),
          ];

          final result = generator.generate(intents, []);

          expect(result, isNotNull);
          // fromMap should have IntentFile.fromMap with null check
          expect(result, contains('IntentFile.fromMap'));
          expect(result, contains("map['image'] != null"));
          // fromQueryParameters should exist (no required IntentFile)
          expect(result, contains('fromQueryParameters'));
          // IntentFile in fromQueryParameters should be null
          expect(result, contains('image: null'));
        },
      );
    });

    group('double and bool handling in Params class', () {
      test('generates double conversion in Params class', () {
        final intents = [
          const IntentInfo(
            className: 'SetRatingIntent',
            identifier: 'com.example.setRating',
            title: 'Set Rating',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'rating',
                dartType: 'double',
                title: 'Rating',
                isOptional: false,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        // fromMap - double via num
        expect(result, contains("(map['rating'] as num).toDouble()"));
        // fromQueryParameters - double.parse
        expect(result, contains("double.parse(params['rating']!)"));
      });

      test('generates bool conversion in Params class', () {
        final intents = [
          const IntentInfo(
            className: 'ToggleTaskIntent',
            identifier: 'com.example.toggleTask',
            title: 'Toggle Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'completed',
                dartType: 'bool',
                title: 'Completed',
                isOptional: false,
              ),
            ],
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        // fromMap - bool
        expect(result, contains("map['completed'] as bool"));
        // fromQueryParameters - bool from string
        expect(result, contains("params['completed'] == 'true'"));
      });
    });
  });
}
