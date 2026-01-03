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
        expect(result, isNot(contains("import 'package:app_intents/app_intents.dart'")));
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
        expect(
          result,
          contains("AppIntents().registerIntentHandler"),
        );
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

      test('generates parameter extraction from params map', () {
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
        expect(result, contains("params['title']"));
        expect(result, contains("params['priority']"));
        expect(result, contains('as String'));
        expect(result, contains('as int'));
      });

      test('generates nullable parameter extraction for optional params', () {
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
        expect(result, contains("params['dueDate']"));
        // DateTime is parsed from String since platform channels serialize it as ISO8601
        expect(result, contains('as String?'));
        expect(result, contains('DateTime.parse'));
      });

      test('generates handler function call with named parameters', () {
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
        expect(result, contains('createTaskIntentHandler'));
        expect(result, contains('title: title'));
      });

      test('generates result serialization', () {
        final intents = [
          const IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
            outputType: 'TaskResult',
          ),
        ];

        final result = generator.generate(intents, []);

        expect(result, isNotNull);
        // Handler should call toMap() on result when output type exists
        expect(result, contains('result'));
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

      test('generates registerSuggestedEntitiesHandler when defaultQuery exists', () {
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
      });

      test('does not generate registerSuggestedEntitiesHandler when no defaultQuery', () {
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
        expect(result, isNot(contains('registerSuggestedEntitiesHandler')));
      });

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
        expect(result, isNot(contains("import 'package:app_intents/app_intents.dart'")));
        expect(result, contains('void initializeAppIntents()'));
        expect(result, contains('void _registerIntentHandlers()'));
        expect(result, contains('void _registerEntityHandlers()'));
        // Check intent handler
        expect(result, contains('createTaskIntentHandler'));
        // Check entity handlers
        expect(result, contains('taskEntityQuery'));
        expect(result, contains('taskEntitySuggestedEntities'));
      });
    });

    group('DateTime handling', () {
      test('generates DateTime parsing for DateTime parameters', () {
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
        expect(result, contains('DateTime.parse'));
      });

      test('generates nullable DateTime parsing for optional DateTime parameters', () {
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
        // Should handle nullable DateTime with null check
        expect(result, contains("params['dueDate']"));
      });
    });
  });
}
