import 'package:app_intents_codegen/src/generator/kotlin_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/enum_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

void main() {
  group('KotlinGenerator', () {
    late KotlinGenerator generator;

    setUp(() {
      generator = KotlinGenerator();
    });

    group('dartTypeToKotlinType', () {
      test('maps String to String', () {
        expect(generator.dartTypeToKotlinType('String'), equals('String'));
      });

      test('maps int to Int', () {
        expect(generator.dartTypeToKotlinType('int'), equals('Int'));
      });

      test('maps double to Double', () {
        expect(generator.dartTypeToKotlinType('double'), equals('Double'));
      });

      test('maps bool to Boolean', () {
        expect(generator.dartTypeToKotlinType('bool'), equals('Boolean'));
      });

      test('maps DateTime to String (ISO8601)', () {
        expect(generator.dartTypeToKotlinType('DateTime'), equals('String'));
      });

      test('maps nullable types correctly', () {
        expect(generator.dartTypeToKotlinType('String?'), equals('String?'));
        expect(generator.dartTypeToKotlinType('int?'), equals('Int?'));
        expect(generator.dartTypeToKotlinType('DateTime?'), equals('String?'));
        expect(generator.dartTypeToKotlinType('bool?'), equals('Boolean?'));
      });

      test('returns original type for unknown types', () {
        expect(
            generator.dartTypeToKotlinType('CustomType'), equals('CustomType'));
      });
    });

    group('generateIntent', () {
      test('generates basic @AppFunction method', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('import androidx.appfunctions.service.AppFunction'));
        expect(
            result, contains('import androidx.appfunctions.AppFunctionContext'));
        expect(result, contains('@AppFunction(isDescribedByKdoc = true)'));
        expect(result, contains('suspend fun greet('));
        expect(result, contains('appFunctionContext: AppFunctionContext'));
        expect(result, contains('): String {'));
      });

      test('generates KDoc with title when no description', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('/**'));
        expect(result, contains(' * Greet User'));
        expect(result, contains(' */'));
      });

      test('generates KDoc with description when provided', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          description: 'Greets the user with a friendly message',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains(' * Greets the user with a friendly message'));
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

        expect(result, contains('title: String'));
        expect(result, contains('params["title"] = title'));
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

        expect(result, contains('dueDate: String? = null'));
        expect(result,
            contains('if (dueDate != null) params["dueDate"] = dueDate'));
      });

      test('generates intent with parameter description in KDoc', () {
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

        expect(result,
            contains('@param title The title of the task to create'));
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
              fieldName: 'doubleParam',
              dartType: 'double',
              title: 'Double Param',
              isOptional: false,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('stringParam: String'));
        expect(result, contains('intParam: Int'));
        expect(result, contains('boolParam: Boolean'));
        expect(result, contains('doubleParam: Double'));
      });

      test('derives function name from identifier', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.taskapp.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('suspend fun createTask('));
      });

      test('delegates to bridge with correct identifier', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.taskapp.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains(
            'bridge.executeIntent("com.example.taskapp.createTask", params)'));
      });

      test('ignores iOS-specific urlScheme field', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [],
          urlScheme: 'taskapp',
          urlAction: 'create',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, isNot(contains('taskapp')));
        expect(result, isNot(contains('urlScheme')));
        expect(result, isNot(contains('URLComponents')));
      });

      test('ignores iOS-specific resultDialogTemplate field', () {
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
          resultDialogTemplate: 'Created task "{title}"',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, isNot(contains('ProvidesDialog')));
        expect(result, isNot(contains('dialog')));
      });

      test('ignores iOS-specific parameterSummary field', () {
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
          parameterSummary: 'Create {title}',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, isNot(contains('parameterSummary')));
        expect(result, isNot(contains('Summary(')));
      });

      test('marks optional parameters in KDoc', () {
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
              fieldName: 'note',
              dartType: 'String?',
              title: 'Note',
              isOptional: true,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@param title Task Title'));
        expect(result, contains('@param note Note (optional)'));
      });
    });

    group('generateEntity', () {
      test('generates basic @AppFunctionSerializable data class', () {
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
              fieldName: 'title',
              dartType: 'String',
              role: EntityPropertyRole.title,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains(
            'import androidx.appfunctions.AppFunctionSerializable'));
        expect(result, contains(
            '@AppFunctionSerializable(isDescribedByKdoc = true)'));
        expect(result, contains('data class TaskEntity('));
        expect(result, contains('val id: String'));
        expect(result, contains('val title: String'));
      });

      test('generates KDoc with description', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          description: 'A task in your task list',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains(' * A task in your task list'));
      });

      test('generates KDoc with title when no description', () {
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

        expect(result, contains(' * Task'));
      });

      test('generates nullable property with default null', () {
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
              fieldName: 'subtitle',
              dartType: 'String?',
              role: EntityPropertyRole.subtitle,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('val subtitle: String? = null'));
      });

      test('only includes id, title, subtitle roles as data class fields', () {
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
              fieldName: 'title',
              dartType: 'String',
              role: EntityPropertyRole.title,
            ),
            EntityPropertyInfo(
              fieldName: 'iconName',
              dartType: 'String?',
              role: EntityPropertyRole.image,
            ),
            EntityPropertyInfo(
              fieldName: 'defaultQuery',
              dartType: 'String',
              role: EntityPropertyRole.defaultQuery,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('val id: String'));
        expect(result, contains('val title: String'));
        // Image and defaultQuery should be skipped
        expect(result, isNot(contains('iconName')));
        expect(result, isNot(contains('defaultQuery')));
      });

      test('generates KDoc @param for each data class field', () {
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
              fieldName: 'title',
              dartType: 'String',
              role: EntityPropertyRole.title,
            ),
            EntityPropertyInfo(
              fieldName: 'subtitle',
              dartType: 'String?',
              role: EntityPropertyRole.subtitle,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('@param id The unique identifier.'));
        expect(result, contains('@param title The display title.'));
        expect(result,
            contains('@param subtitle The subtitle or description.'));
      });
    });

    group('generateEnum', () {
      test('generates basic Kotlin enum class', () {
        final enumInfo = EnumInfo(
          className: 'TaskPriority',
          identifier: 'com.example.taskPriority',
          title: 'Priority',
          cases: [
            EnumCaseInfo(name: 'high', displayTitle: 'High'),
            EnumCaseInfo(name: 'medium', displayTitle: 'Medium'),
            EnumCaseInfo(name: 'low', displayTitle: 'Low'),
          ],
        );

        final result = generator.generateEnum(enumInfo);

        expect(result, contains('/**'));
        expect(result, contains(' * Priority'));
        expect(result, contains(' */'));
        expect(result,
            contains('enum class TaskPriority(val value: String) {'));
        expect(result, contains('/** High */'));
        expect(result, contains('HIGH("high"),'));
        expect(result, contains('/** Medium */'));
        expect(result, contains('MEDIUM("medium"),'));
        expect(result, contains('/** Low */'));
        expect(result, contains('LOW("low");'));
      });

      test('generates companion object with fromValue', () {
        final enumInfo = EnumInfo(
          className: 'TaskPriority',
          identifier: 'com.example.taskPriority',
          title: 'Priority',
          cases: [
            EnumCaseInfo(name: 'high', displayTitle: 'High'),
          ],
        );

        final result = generator.generateEnum(enumInfo);

        expect(result, contains('companion object {'));
        expect(result, contains(
            'fun fromValue(value: String): TaskPriority?'));
        expect(result, contains('entries.find { it.value == value }'));
      });

      test('converts camelCase to UPPER_SNAKE_CASE', () {
        final enumInfo = EnumInfo(
          className: 'TaskStatus',
          identifier: 'com.example.taskStatus',
          title: 'Status',
          cases: [
            EnumCaseInfo(name: 'inProgress', displayTitle: 'In Progress'),
            EnumCaseInfo(name: 'notStarted', displayTitle: 'Not Started'),
          ],
        );

        final result = generator.generateEnum(enumInfo);

        expect(result, contains('IN_PROGRESS("inProgress"),'));
        expect(result, contains('NOT_STARTED("notStarted");'));
      });
    });

    group('generateBridge', () {
      test('generates AppFunctionsBridge singleton class', () {
        final result = generator.generateBridge();

        expect(result, contains('class AppFunctionsBridge private constructor'));
        expect(result, contains('private val channel: MethodChannel'));
        expect(result, contains('companion object {'));
        expect(result, contains('fun initialize(channel: MethodChannel)'));
        expect(result, contains('fun getInstance(): AppFunctionsBridge'));
        expect(result, contains('suspend fun executeIntent('));
        expect(result, contains('identifier: String'));
        expect(result, contains('params: Map<String, Any?>'));
        expect(result, contains('withContext(Dispatchers.Main)'));
        expect(result, contains('suspendCancellableCoroutine'));
        expect(result, contains('channel.invokeMethod'));
        expect(result, contains('override fun success(result: Any?)'));
        expect(result, contains('override fun error('));
        expect(result, contains('override fun notImplemented()'));
      });
    });

    group('generateAll', () {
      test('generates complete Kotlin file with package declaration', () {
        final result = generator.generateAll(
          packageName: 'com.example.app.generated',
          intents: [
            IntentInfo(
              className: 'CreateTaskIntent',
              identifier: 'com.example.createTask',
              title: 'Create Task',
              implementation: IntentImplementationType.dart,
              parameters: [],
            ),
          ],
        );

        expect(result, contains('package com.example.app.generated'));
      });

      test('includes correct imports for intents', () {
        final result = generator.generateAll(
          packageName: 'com.example.app',
          intents: [
            IntentInfo(
              className: 'GreetIntent',
              identifier: 'com.example.greet',
              title: 'Greet',
              implementation: IntentImplementationType.dart,
              parameters: [],
            ),
          ],
        );

        expect(result, contains('import androidx.appfunctions.service.AppFunction'));
        expect(result,
            contains('import androidx.appfunctions.AppFunctionContext'));
        expect(result,
            contains('import io.flutter.plugin.common.MethodChannel'));
        expect(result, contains('import kotlinx.coroutines.Dispatchers'));
      });

      test('includes AppFunctionSerializable import for entities', () {
        final result = generator.generateAll(
          packageName: 'com.example.app',
          entities: [
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
          ],
        );

        expect(result, contains(
            'import androidx.appfunctions.AppFunctionSerializable'));
      });

      test('generates enums before intents', () {
        final result = generator.generateAll(
          packageName: 'com.example.app',
          enums: [
            EnumInfo(
              className: 'TaskPriority',
              identifier: 'com.example.taskPriority',
              title: 'Priority',
              cases: [
                EnumCaseInfo(name: 'high', displayTitle: 'High'),
              ],
            ),
          ],
          intents: [
            IntentInfo(
              className: 'CreateTaskIntent',
              identifier: 'com.example.createTask',
              title: 'Create Task',
              implementation: IntentImplementationType.dart,
              parameters: [],
            ),
          ],
        );

        final enumIndex = result.indexOf('enum class TaskPriority');
        final intentIndex =
            result.indexOf('class GeneratedAppFunctions');
        expect(enumIndex, lessThan(intentIndex));
      });

      test('generates entities before bridge', () {
        final result = generator.generateAll(
          packageName: 'com.example.app',
          entities: [
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
          ],
          intents: [
            IntentInfo(
              className: 'GreetIntent',
              identifier: 'com.example.greet',
              title: 'Greet',
              implementation: IntentImplementationType.dart,
              parameters: [],
            ),
          ],
        );

        final entityIndex = result.indexOf('data class TaskEntity');
        final bridgeIndex = result.indexOf('class AppFunctionsBridge');
        expect(entityIndex, lessThan(bridgeIndex));
      });

      test('generates GeneratedAppFunctions class wrapping all intents', () {
        final result = generator.generateAll(
          packageName: 'com.example.app',
          intents: [
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
            IntentInfo(
              className: 'CompleteTaskIntent',
              identifier: 'com.example.completeTask',
              title: 'Complete Task',
              implementation: IntentImplementationType.dart,
              parameters: [],
            ),
          ],
        );

        expect(result, contains('class GeneratedAppFunctions {'));
        expect(result, contains('get() = AppFunctionsBridge.getInstance()'));
        expect(result, contains('suspend fun createTask('));
        expect(result, contains('suspend fun completeTask('));
      });

      test('generates combined output with all types', () {
        final result = generator.generateAll(
          packageName: 'com.example.app',
          enums: [
            EnumInfo(
              className: 'TaskPriority',
              identifier: 'com.example.taskPriority',
              title: 'Priority',
              cases: [
                EnumCaseInfo(name: 'high', displayTitle: 'High'),
                EnumCaseInfo(name: 'low', displayTitle: 'Low'),
              ],
            ),
          ],
          entities: [
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
                EntityPropertyInfo(
                  fieldName: 'title',
                  dartType: 'String',
                  role: EntityPropertyRole.title,
                ),
              ],
            ),
          ],
          intents: [
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
          ],
        );

        expect(result, contains('package com.example.app'));
        expect(result, contains('enum class TaskPriority'));
        expect(result, contains('data class TaskEntity'));
        expect(result, contains('class AppFunctionsBridge'));
        expect(result, contains('class GeneratedAppFunctions'));
      });

      test('does not generate AppFunctions class when no intents', () {
        final result = generator.generateAll(
          packageName: 'com.example.app',
          entities: [
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
          ],
        );

        expect(result, isNot(contains('class GeneratedAppFunctions')));
      });
    });
  });
}
