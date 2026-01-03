// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';

/// Resolves a Dart source string and returns the library element.
Future<LibraryElement> resolveSource(String source) async {
  final library = await resolveSources(
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
        class EntityId {
          const EntityId();
        }

        class EntityTitle {
          const EntityTitle();
        }

        class EntitySubtitle {
          const EntitySubtitle();
        }

        class EntityImage {
          const EntityImage();
        }

        class EntityDefaultQuery {
          const EntityDefaultQuery();
        }
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
      'test_lib|lib/test.dart': source,
    },
    (resolver) async {
      return await resolver.libraryFor(
        AssetId('test_lib', 'lib/test.dart'),
      );
    },
  );
  return library;
}
