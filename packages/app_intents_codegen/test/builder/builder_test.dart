import 'package:app_intents_codegen/src/builder.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

void main() {
  group('AppIntentsBuilder', () {
    test('appIntentsBuilder returns a Builder instance', () {
      final builder = appIntentsBuilder(BuilderOptions.empty);
      expect(builder, isA<Builder>());
    });

    test('builder has correct build extensions', () {
      final builder = appIntentsBuilder(BuilderOptions.empty);
      expect(builder.buildExtensions, containsPair('.dart', ['.intent.dart']));
    });
  });

  group('AppIntentsGenerator', () {
    test('generates output for class with @IntentSpec annotation', () async {
      await testBuilder(
        appIntentsBuilder(BuilderOptions.empty),
        {
          'app_intents_annotations|lib/app_intents_annotations.dart': '''
            export 'src/annotations/intent_spec.dart';
            export 'src/annotations/intent_param.dart';
            export 'src/annotations/entity_spec.dart';
            export 'src/annotations/entity_params.dart';
            export 'src/bases/intent_spec_base.dart';
            export 'src/bases/entity_spec_base.dart';
          ''',
          'app_intents_annotations|lib/src/annotations/intent_spec.dart': '''
            class IntentSpec {
              final String identifier;
              final String title;
              final String? description;
              final IntentImplementation implementation;

              const IntentSpec({
                required this.identifier,
                required this.title,
                this.description,
                this.implementation = IntentImplementation.dart,
              });
            }

            enum IntentImplementation {
              dart,
              swift,
            }
          ''',
          'app_intents_annotations|lib/src/annotations/intent_param.dart': '''
            class IntentParam {
              final String title;
              final String? description;
              final bool isOptional;

              const IntentParam({
                required this.title,
                this.description,
                this.isOptional = false,
              });
            }
          ''',
          'app_intents_annotations|lib/src/annotations/entity_spec.dart': '''
            class EntitySpec {
              final String identifier;
              final String title;
              final String pluralTitle;
              final String? description;

              const EntitySpec({
                required this.identifier,
                required this.title,
                required this.pluralTitle,
                this.description,
              });
            }
          ''',
          'app_intents_annotations|lib/src/annotations/entity_params.dart': '''
            class EntityId { const EntityId(); }
            class EntityTitle { const EntityTitle(); }
            class EntitySubtitle { const EntitySubtitle(); }
            class EntityImage { const EntityImage(); }
            class EntityDefaultQuery { const EntityDefaultQuery(); }
          ''',
          'app_intents_annotations|lib/src/bases/intent_spec_base.dart': '''
            abstract class IntentSpecBase<I, O> {
              const IntentSpecBase();
            }
          ''',
          'app_intents_annotations|lib/src/bases/entity_spec_base.dart': '''
            abstract class EntitySpecBase<M> {
              const EntitySpecBase();
            }
          ''',
          'a|lib/greet_intent.dart': '''
            import 'package:app_intents_annotations/app_intents_annotations.dart';

            @IntentSpec(
              identifier: 'com.example.greet',
              title: 'Greet User',
              description: 'Greets the user with a friendly message',
            )
            class GreetIntent extends IntentSpecBase<String, void> {
              @IntentParam(title: 'User Name')
              final String name;

              GreetIntent({required this.name});
            }
          ''',
        },
        generateFor: {'a|lib/greet_intent.dart'},
        outputs: {
          'a|lib/greet_intent.intent.dart': decodedMatches(
            allOf([
              contains('// GENERATED CODE - DO NOT MODIFY BY HAND'),
              contains('greetIntentHandler'),
              contains('com.example.greet'),
              contains('registerIntentHandler'),
            ]),
          ),
        },
      );
    });

    test('generates output for class with @EntitySpec annotation', () async {
      await testBuilder(
        appIntentsBuilder(BuilderOptions.empty),
        {
          'app_intents_annotations|lib/app_intents_annotations.dart': '''
            export 'src/annotations/intent_spec.dart';
            export 'src/annotations/intent_param.dart';
            export 'src/annotations/entity_spec.dart';
            export 'src/annotations/entity_params.dart';
            export 'src/bases/intent_spec_base.dart';
            export 'src/bases/entity_spec_base.dart';
          ''',
          'app_intents_annotations|lib/src/annotations/intent_spec.dart': '''
            class IntentSpec {
              final String identifier;
              final String title;
              final String? description;
              final IntentImplementation implementation;

              const IntentSpec({
                required this.identifier,
                required this.title,
                this.description,
                this.implementation = IntentImplementation.dart,
              });
            }

            enum IntentImplementation { dart, swift }
          ''',
          'app_intents_annotations|lib/src/annotations/intent_param.dart': '''
            class IntentParam {
              final String title;
              final String? description;
              final bool isOptional;

              const IntentParam({
                required this.title,
                this.description,
                this.isOptional = false,
              });
            }
          ''',
          'app_intents_annotations|lib/src/annotations/entity_spec.dart': '''
            class EntitySpec {
              final String identifier;
              final String title;
              final String pluralTitle;
              final String? description;

              const EntitySpec({
                required this.identifier,
                required this.title,
                required this.pluralTitle,
                this.description,
              });
            }
          ''',
          'app_intents_annotations|lib/src/annotations/entity_params.dart': '''
            class EntityId { const EntityId(); }
            class EntityTitle { const EntityTitle(); }
            class EntitySubtitle { const EntitySubtitle(); }
            class EntityImage { const EntityImage(); }
            class EntityDefaultQuery { const EntityDefaultQuery(); }
          ''',
          'app_intents_annotations|lib/src/bases/intent_spec_base.dart': '''
            abstract class IntentSpecBase<I, O> { const IntentSpecBase(); }
          ''',
          'app_intents_annotations|lib/src/bases/entity_spec_base.dart': '''
            abstract class EntitySpecBase<M> { const EntitySpecBase(); }
          ''',
          'a|lib/task_entity.dart': '''
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

              TaskEntity({required this.id, required this.name});
            }

            class Task {
              final String id;
              final String name;
              Task({required this.id, required this.name});
            }
          ''',
        },
        generateFor: {'a|lib/task_entity.dart'},
        outputs: {
          'a|lib/task_entity.intent.dart': decodedMatches(
            allOf([
              contains('// GENERATED CODE - DO NOT MODIFY BY HAND'),
              contains('taskEntityQuery'),
              contains('com.example.task'),
              contains('registerEntityQueryHandler'),
            ]),
          ),
        },
      );
    });

    test('does not generate output for class without annotations', () async {
      await testBuilder(
        appIntentsBuilder(BuilderOptions.empty),
        {
          'app_intents_annotations|lib/app_intents_annotations.dart': '''
            export 'src/annotations/intent_spec.dart';
            export 'src/annotations/intent_param.dart';
            export 'src/annotations/entity_spec.dart';
            export 'src/annotations/entity_params.dart';
            export 'src/bases/intent_spec_base.dart';
            export 'src/bases/entity_spec_base.dart';
          ''',
          'app_intents_annotations|lib/src/annotations/intent_spec.dart': '''
            class IntentSpec {
              final String identifier;
              final String title;
              final String? description;
              final IntentImplementation implementation;
              const IntentSpec({
                required this.identifier,
                required this.title,
                this.description,
                this.implementation = IntentImplementation.dart,
              });
            }
            enum IntentImplementation { dart, swift }
          ''',
          'app_intents_annotations|lib/src/annotations/intent_param.dart': '''
            class IntentParam {
              final String title;
              final String? description;
              final bool isOptional;
              const IntentParam({
                required this.title,
                this.description,
                this.isOptional = false,
              });
            }
          ''',
          'app_intents_annotations|lib/src/annotations/entity_spec.dart': '''
            class EntitySpec {
              final String identifier;
              final String title;
              final String pluralTitle;
              final String? description;
              const EntitySpec({
                required this.identifier,
                required this.title,
                required this.pluralTitle,
                this.description,
              });
            }
          ''',
          'app_intents_annotations|lib/src/annotations/entity_params.dart': '''
            class EntityId { const EntityId(); }
            class EntityTitle { const EntityTitle(); }
            class EntitySubtitle { const EntitySubtitle(); }
            class EntityImage { const EntityImage(); }
            class EntityDefaultQuery { const EntityDefaultQuery(); }
          ''',
          'app_intents_annotations|lib/src/bases/intent_spec_base.dart': '''
            abstract class IntentSpecBase<I, O> { const IntentSpecBase(); }
          ''',
          'app_intents_annotations|lib/src/bases/entity_spec_base.dart': '''
            abstract class EntitySpecBase<M> { const EntitySpecBase(); }
          ''',
          'a|lib/plain_class.dart': '''
            class PlainClass {
              final String value;
              PlainClass({required this.value});
            }
          ''',
        },
        generateFor: {'a|lib/plain_class.dart'},
        outputs: {},
      );
    });
  });
}
