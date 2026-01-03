import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

void main() {
  group('SwiftGenerator', () {
    late SwiftGenerator generator;

    setUp(() {
      generator = SwiftGenerator();
    });

    group('generateIntent', () {
      test('generates basic AppIntent struct with title', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('import AppIntents'));
        expect(result, contains('@available(iOS 16.0, *)'));
        expect(result, contains('struct GreetIntent: AppIntent'));
        expect(
            result, contains('static var title: LocalizedStringResource = "Greet User"'));
      });

      test('generates intent with description', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          description: 'Greets the user with a friendly message',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('static var description: IntentDescription'));
        expect(
            result, contains('IntentDescription("Greets the user with a friendly message")'));
      });

      test('generates intent with String parameter', () {
        final intentInfo = IntentInfo(
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
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@Parameter(title: "Task Title")'));
        expect(result, contains('var title: String'));
      });

      test('generates intent with optional parameter', () {
        final intentInfo = IntentInfo(
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
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@Parameter(title: "Due Date")'));
        expect(result, contains('var dueDate: Date?'));
      });

      test('generates intent with parameter description', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Task Title',
              description: 'The title of the task to create',
              isOptional: false,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(
            result,
            contains(
                '@Parameter(title: "Task Title", description: "The title of the task to create")'));
      });

      test('generates perform method with FlutterBridge invocation', () {
        final intentInfo = IntentInfo(
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
              fieldName: 'dueDate',
              dartType: 'DateTime?',
              title: 'Due Date',
              isOptional: true,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@MainActor'));
        expect(result, contains('func perform() async throws -> some IntentResult'));
        expect(result, contains('FlutterBridge.shared.invoke'));
        expect(result, contains('intent: "CreateTaskIntent"'));
        expect(result, contains('"title": title'));
        expect(result, contains('"dueDate": dueDate'));
        expect(result, contains('return .result()'));
      });

      test('generates intent with multiple type mappings', () {
        final intentInfo = IntentInfo(
          className: 'TestIntent',
          identifier: 'com.example.test',
          title: 'Test Intent',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'stringParam',
              dartType: 'String',
              title: 'String Param',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'intParam',
              dartType: 'int',
              title: 'Int Param',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'boolParam',
              dartType: 'bool',
              title: 'Bool Param',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'dateParam',
              dartType: 'DateTime',
              title: 'Date Param',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'doubleParam',
              dartType: 'double',
              title: 'Double Param',
              isOptional: false,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('var stringParam: String'));
        expect(result, contains('var intParam: Int'));
        expect(result, contains('var boolParam: Bool'));
        expect(result, contains('var dateParam: Date'));
        expect(result, contains('var doubleParam: Double'));
      });
    });

    group('generateEntity', () {
      test('generates basic AppEntity struct', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('import AppIntents'));
        expect(result, contains('@available(iOS 16.0, *)'));
        expect(result, contains('struct TaskEntity: AppEntity'));
      });

      test('generates typeDisplayRepresentation', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('static var typeDisplayRepresentation: TypeDisplayRepresentation'));
        expect(result, contains('TypeDisplayRepresentation(name: "Task")'));
      });

      test('generates id property', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('var id: String'));
      });

      test('generates displayRepresentation with title', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
            EntityPropertyInfo(
              fieldName: 'name',
              dartType: 'String',
              role: EntityPropertyRole.title,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('var displayRepresentation: DisplayRepresentation'));
        expect(result, contains('DisplayRepresentation(title: "\\(name)")'));
      });

      test('generates displayRepresentation with title and subtitle', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
            EntityPropertyInfo(
              fieldName: 'name',
              dartType: 'String',
              role: EntityPropertyRole.title,
            ),
            EntityPropertyInfo(
              fieldName: 'description',
              dartType: 'String?',
              role: EntityPropertyRole.subtitle,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(
            result,
            contains(
                'DisplayRepresentation(title: "\\(name)", subtitle: "\\(description ?? "")")'));
      });

      test('generates entity properties', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
            EntityPropertyInfo(
              fieldName: 'name',
              dartType: 'String',
              role: EntityPropertyRole.title,
            ),
            EntityPropertyInfo(
              fieldName: 'isCompleted',
              dartType: 'bool',
              role: EntityPropertyRole.none,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('var id: String'));
        expect(result, contains('var name: String'));
        expect(result, contains('var isCompleted: Bool'));
      });

      test('generates default query struct', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('static var defaultQuery = TaskEntityQuery()'));
        expect(result, contains('struct TaskEntityQuery: EntityQuery'));
      });
    });

    group('generateAppShortcutsProvider', () {
      test('generates AppShortcutsProvider with single shortcut', () {
        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: ['Create a task', 'Add new task'],
            shortTitle: 'Create Task',
            systemImageName: 'plus.circle',
          ),
        ];

        final result = generator.generateAppShortcutsProvider(shortcuts);

        expect(result, contains('import AppIntents'));
        expect(result, contains('@available(iOS 16.0, *)'));
        expect(result, contains('struct AppShortcuts: AppShortcutsProvider'));
        expect(result, contains('static var appShortcuts: [AppShortcut]'));
        expect(result, contains('AppShortcut('));
        expect(result, contains('intent: CreateTaskIntent()'));
        expect(result, contains('"Create a task"'));
        expect(result, contains('"Add new task"'));
        expect(result, contains('shortTitle: "Create Task"'));
        expect(result, contains('systemImageName: "plus.circle"'));
      });

      test('generates AppShortcutsProvider with multiple shortcuts', () {
        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: ['Create a task'],
            shortTitle: 'Create Task',
            systemImageName: 'plus.circle',
          ),
          AppShortcutInfo(
            intentClassName: 'ListTasksIntent',
            phrases: ['List my tasks'],
            shortTitle: 'List Tasks',
            systemImageName: 'list.bullet',
          ),
        ];

        final result = generator.generateAppShortcutsProvider(shortcuts);

        expect(result, contains('intent: CreateTaskIntent()'));
        expect(result, contains('intent: ListTasksIntent()'));
      });
    });

    group('generateAll', () {
      test('generates combined Swift file with intents and entities', () {
        final intents = [
          IntentInfo(
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
          EntityInfo(
            className: 'TaskEntity',
            identifier: 'com.example.task',
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

        final result = generator.generateAll(
          intents: intents,
          entities: entities,
        );

        // Should contain single import at top
        expect(result.indexOf('import AppIntents'), isNonNegative);
        // Should contain both intent and entity
        expect(result, contains('struct CreateTaskIntent: AppIntent'));
        expect(result, contains('struct TaskEntity: AppEntity'));
      });

      test('generates combined Swift file with shortcuts', () {
        final intents = [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: ['Create a task'],
            shortTitle: 'Create Task',
            systemImageName: 'plus.circle',
          ),
        ];

        final result = generator.generateAll(
          intents: intents,
          entities: [],
          shortcuts: shortcuts,
        );

        expect(result, contains('struct CreateTaskIntent: AppIntent'));
        expect(result, contains('struct AppShortcuts: AppShortcutsProvider'));
      });
    });

    group('dartTypeToSwiftType', () {
      test('maps String to String', () {
        expect(generator.dartTypeToSwiftType('String'), equals('String'));
      });

      test('maps int to Int', () {
        expect(generator.dartTypeToSwiftType('int'), equals('Int'));
      });

      test('maps double to Double', () {
        expect(generator.dartTypeToSwiftType('double'), equals('Double'));
      });

      test('maps bool to Bool', () {
        expect(generator.dartTypeToSwiftType('bool'), equals('Bool'));
      });

      test('maps DateTime to Date', () {
        expect(generator.dartTypeToSwiftType('DateTime'), equals('Date'));
      });

      test('maps nullable types correctly', () {
        expect(generator.dartTypeToSwiftType('String?'), equals('String?'));
        expect(generator.dartTypeToSwiftType('int?'), equals('Int?'));
        expect(generator.dartTypeToSwiftType('DateTime?'), equals('Date?'));
      });

      test('returns original type for unknown types', () {
        expect(generator.dartTypeToSwiftType('CustomType'), equals('CustomType'));
      });
    });
  });
}
