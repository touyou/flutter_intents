// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:app_intents_codegen/src/analyzer/entity_analyzer.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('EntityAnalyzer', () {
    late EntityAnalyzer analyzer;

    setUp(() {
      analyzer = EntityAnalyzer();
    });

    group('analyze', () {
      test('extracts basic entity information from @EntitySpec annotation',
          () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @EntitySpec(
            identifier: 'com.example.task',
            title: 'Task',
            pluralTitle: 'Tasks',
          )
          class TaskEntity extends EntitySpecBase<Task> {}

          class Task {
            final String id;
            final String name;
            Task({required this.id, required this.name});
          }
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'TaskEntity');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.className, equals('TaskEntity'));
        expect(result.identifier, equals('com.example.task'));
        expect(result.title, equals('Task'));
        expect(result.pluralTitle, equals('Tasks'));
        expect(result.description, isNull);
      });

      test('extracts description when provided', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @EntitySpec(
            identifier: 'com.example.task',
            title: 'Task',
            pluralTitle: 'Tasks',
            description: 'A task entity for managing todos',
          )
          class TaskEntity extends EntitySpecBase<Task> {}

          class Task {
            final String id;
            Task({required this.id});
          }
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'TaskEntity');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.description, equals('A task entity for managing todos'));
      });

      test('extracts model type from EntitySpecBase', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @EntitySpec(
            identifier: 'com.example.task',
            title: 'Task',
            pluralTitle: 'Tasks',
          )
          class TaskEntity extends EntitySpecBase<TaskModel> {}

          class TaskModel {
            final String id;
            TaskModel({required this.id});
          }
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'TaskEntity');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.modelType, equals('TaskModel'));
      });

      test('extracts properties with entity annotations', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @EntitySpec(
            identifier: 'com.example.task',
            title: 'Task',
            pluralTitle: 'Tasks',
          )
          class TaskEntity extends EntitySpecBase<Task> {
            @EntityId()
            final String id;

            @EntityTitle()
            final String name;

            @EntitySubtitle()
            final String? subtitle;

            @EntityImage()
            final String? imageUrl;

            @EntityDefaultQuery()
            static Future<List<Task>> defaultQuery() async => [];

            TaskEntity({required this.id, required this.name, this.subtitle, this.imageUrl});
          }

          class Task {
            final String id;
            Task({required this.id});
          }
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'TaskEntity');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.properties, hasLength(4));

        final idProp =
            result.properties.firstWhere((p) => p.fieldName == 'id');
        expect(idProp.role, equals(EntityPropertyRole.id));
        expect(idProp.dartType, equals('String'));

        final nameProp =
            result.properties.firstWhere((p) => p.fieldName == 'name');
        expect(nameProp.role, equals(EntityPropertyRole.title));
        expect(nameProp.dartType, equals('String'));

        final subtitleProp =
            result.properties.firstWhere((p) => p.fieldName == 'subtitle');
        expect(subtitleProp.role, equals(EntityPropertyRole.subtitle));
        expect(subtitleProp.dartType, equals('String?'));

        final imageProp =
            result.properties.firstWhere((p) => p.fieldName == 'imageUrl');
        expect(imageProp.role, equals(EntityPropertyRole.image));
        expect(imageProp.dartType, equals('String?'));
      });

      test('returns null for class without @EntitySpec annotation', () async {
        final library = await resolveSource('''
          class PlainClass {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'PlainClass');

        final result = analyzer.analyze(classElement);

        expect(result, isNull);
      });
    });

    group('hasEntitySpecAnnotation', () {
      test('returns true for class with @EntitySpec annotation', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @EntitySpec(
            identifier: 'com.example.test',
            title: 'Test',
            pluralTitle: 'Tests',
          )
          class TestEntity extends EntitySpecBase<Test> {}

          class Test {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'TestEntity');

        expect(analyzer.hasEntitySpecAnnotation(classElement), isTrue);
      });

      test('returns false for class without @EntitySpec annotation', () async {
        final library = await resolveSource('''
          class PlainClass {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'PlainClass');

        expect(analyzer.hasEntitySpecAnnotation(classElement), isFalse);
      });
    });
  });
}
