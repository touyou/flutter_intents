import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:test/test.dart';

SwiftGenerator _allExperimental() => const SwiftGenerator(
  experimental: ExperimentalFeatures(masterEnabled: true),
);

SwiftGenerator _valueRepresentationOnly() => const SwiftGenerator(
  experimental: ExperimentalFeatures(
    masterEnabled: true,
    enabled: {ExperimentalFeature.valueRepresentation},
  ),
);

EntityInfo _entity({EntityExportKind? exportAs}) => EntityInfo(
  className: 'ContactEntity',
  identifier: 'com.example.contact',
  title: 'Contact',
  pluralTitle: 'Contacts',
  exportAs: exportAs,
  properties: const [
    EntityPropertyInfo(
      fieldName: 'uid',
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

void main() {
  group('SwiftGenerator (#54 ValueRepresentation export)', () {
    test(
      'emits Transferable + ValueRepresentation in #if block when enabled',
      () {
        final result = _allExperimental().generateAll(
          entities: [_entity(exportAs: EntityExportKind.person)],
        );

        expect(result, contains('#if APP_INTENTS_WWDC26'));
        expect(result, contains('import CoreTransferable'));
        expect(result, contains('@available(iOS 27.0, *)'));
        expect(result, contains('extension ContactEntity: Transferable {'));
        expect(
          result,
          contains(
            'static var transferRepresentation: some TransferRepresentation',
          ),
        );
        expect(result, contains('ValueRepresentation(exporting: { entity in'));
        expect(result, contains('IntentPerson('));
        // Uses the entity's actual id/title field names, not literal id/title.
        expect(result, contains('identifier: .applicationDefined(entity.uid)'));
        expect(result, contains('name: .displayName(entity.name)'));
        // handle has no default in the SDK initializer, so it is passed explicitly.
        expect(result, contains('handle: nil'));
        expect(result, contains('#endif'));
      },
    );

    test('export is additive — does not affect the EntityQuery', () {
      final result = _valueRepresentationOnly().generateAll(
        entities: [_entity(exportAs: EntityExportKind.person)],
      );
      expect(result, contains('struct ContactEntityQuery: EntityQuery {'));
      expect(result, contains('extension ContactEntity: Transferable {'));
    });

    test('does not emit when exportAs is null', () {
      final result = _allExperimental().generateAll(entities: [_entity()]);
      expect(result, isNot(contains('Transferable')));
      expect(result, isNot(contains('ValueRepresentation')));
    });

    test('does not emit when value-representation feature is disabled', () {
      final gen = const SwiftGenerator(
        experimental: ExperimentalFeatures(
          masterEnabled: true,
          enabled: {ExperimentalFeature.valueQuery},
        ),
      );
      final result = gen.generateAll(
        entities: [_entity(exportAs: EntityExportKind.person)],
      );
      expect(result, isNot(contains('ValueRepresentation')));
    });

    test('stable generator emits no export at all', () {
      final result = const SwiftGenerator().generateAll(
        entities: [_entity(exportAs: EntityExportKind.person)],
      );
      expect(result, isNot(contains('ValueRepresentation')));
      expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
    });
  });
}
