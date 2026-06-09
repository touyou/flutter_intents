// ignore_for_file: deprecated_member_use, unnecessary_non_null_assertion
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';

/// Finds a [ClassElement] by name in a library.
ClassElement findClass(LibraryElement library, String name) {
  for (final cls in library.classes) {
    if (cls.name == name) return cls;
  }
  throw StateError('Class "$name" not found in library');
}

/// Finds an [EnumElement] by name in a library.
EnumElement findEnum(LibraryElement library, String name) {
  for (final e in library.enums) {
    if (e.name == name) return e;
  }
  throw StateError('Enum "$name" not found in library');
}

/// Resolves a Dart source string and returns the library element.
Future<LibraryElement> resolveSource(String source) async {
  final library = await resolveSources(
    {
      'app_intents_annotations|lib/app_intents_annotations.dart': '''
        export 'src/annotations/intent_spec.dart';
        export 'src/annotations/intent_param.dart';
        export 'src/annotations/entity_spec.dart';
        export 'src/annotations/entity_params.dart';
        export 'src/annotations/app_shortcut.dart';
        export 'src/annotations/enum_spec.dart';
        export 'src/bases/intent_spec_base.dart';
        export 'src/bases/entity_spec_base.dart';
      ''',
      'app_intents_annotations|lib/src/annotations/intent_spec.dart': '''
        class IntentSpec {
          final String identifier;
          final String title;
          final String? description;
          final IntentImplementation implementation;
          final String? urlScheme;
          final String? urlAction;
          final String? resultDialogTemplate;
          final String? parameterSummary;
          final IntentMode? supportedModes;
          final bool longRunning;
          final bool cancellable;
          final List<IntentExecutionTarget>? executionTargets;
          final String? schema;

          const IntentSpec({
            required this.identifier,
            required this.title,
            this.description,
            this.implementation = IntentImplementation.dart,
            this.urlScheme,
            this.urlAction,
            this.resultDialogTemplate,
            this.parameterSummary,
            this.supportedModes,
            this.longRunning = false,
            this.cancellable = false,
            this.executionTargets,
            this.schema,
          });
        }

        enum IntentImplementation {
          dart,
          swift,
        }

        enum IntentMode {
          background,
          foreground,
        }

        enum IntentExecutionTarget {
          main,
          appIntentsExtension,
          widgetKitExtension,
        }
      ''',
      'app_intents_annotations|lib/src/annotations/intent_param.dart': '''
        class IntentParam {
          final String title;
          final String? description;
          final bool isOptional;
          final String? entityType;
          final String? enumType;

          const IntentParam({
            required this.title,
            this.description,
            this.isOptional = false,
            this.entityType,
            this.enumType,
          });
        }
      ''',
      'app_intents_annotations|lib/src/annotations/entity_spec.dart': '''
        class EntitySpec {
          final String identifier;
          final String title;
          final String pluralTitle;
          final String? description;
          final String? displayImageName;
          final bool indexed;
          final bool enumerable;
          final String? persistedCacheKey;
          final String? schema;

          const EntitySpec({
            required this.identifier,
            required this.title,
            required this.pluralTitle,
            this.description,
            this.displayImageName,
            this.indexed = false,
            this.enumerable = false,
            this.persistedCacheKey,
            this.schema,
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

        class EntityProperty {
          final String? title;
          final String? indexingKey;
          const EntityProperty({this.title, this.indexingKey});
        }
      ''',
      'app_intents_annotations|lib/src/bases/intent_spec_base.dart': '''
        abstract class IntentSpecBase {
          const IntentSpecBase();
        }
      ''',
      'app_intents_annotations|lib/src/bases/entity_spec_base.dart': '''
        abstract class EntitySpecBase<M> {
          const EntitySpecBase();
        }
      ''',
      'app_intents_annotations|lib/src/annotations/enum_spec.dart': '''
        class EnumSpec {
          final String identifier;
          final String title;

          const EnumSpec({
            required this.identifier,
            required this.title,
          });
        }

        class EnumCaseDisplay {
          final String title;
          final String? imageName;

          const EnumCaseDisplay({
            required this.title,
            this.imageName,
          });
        }
      ''',
      'app_intents_annotations|lib/src/annotations/app_shortcut.dart': '''
        class AppShortcut {
          final String intentIdentifier;
          final List<String> phrases;
          final String shortTitle;
          final String? systemImageName;

          const AppShortcut({
            required this.intentIdentifier,
            required this.phrases,
            required this.shortTitle,
            this.systemImageName,
          });
        }

        class AppShortcutsProvider {
          const AppShortcutsProvider();
        }
      ''',
      'test_lib|lib/test.dart': source,
    },
    (resolver) async {
      return await resolver.libraryFor(AssetId('test_lib', 'lib/test.dart'));
    },
  );
  return library;
}
