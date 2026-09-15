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

EntityInfo _entity({EntityExportKind? exportAs, bool importable = false}) =>
    EntityInfo(
      className: 'ContactEntity',
      identifier: 'com.example.contact',
      title: 'Contact',
      pluralTitle: 'Contacts',
      exportAs: exportAs,
      importable: importable,
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
        expect(
          result,
          contains(
            'ValueRepresentation(exporting: { (entity: ContactEntity) -> '
            'IntentPerson in',
          ),
        );
        expect(result, contains('IntentPerson('));
        // The id property is normalized to `id` (required by `Identifiable`);
        // the title keeps its actual Dart field name.
        expect(result, contains('identifier: .applicationDefined(entity.id)'));
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
          enabled: {ExperimentalFeature.ownership},
        ),
      );
      final result = gen.generateAll(
        entities: [_entity(exportAs: EntityExportKind.person)],
      );
      expect(result, isNot(contains('ValueRepresentation')));
    });

    test('place export builds a PlaceDescriptor from coordinate + address', () {
      final result = _allExperimental().generateAll(
        entities: [
          EntityInfo(
            className: 'StoreEntity',
            identifier: 'com.example.store',
            title: 'Store',
            pluralTitle: 'Stores',
            exportAs: EntityExportKind.place,
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
              EntityPropertyInfo(
                fieldName: 'lat',
                dartType: 'double?',
                role: EntityPropertyRole.none,
                exportRole: EntityExportRoleKind.latitude,
              ),
              EntityPropertyInfo(
                fieldName: 'lng',
                dartType: 'double?',
                role: EntityPropertyRole.none,
                exportRole: EntityExportRoleKind.longitude,
              ),
              EntityPropertyInfo(
                fieldName: 'street',
                dartType: 'String',
                role: EntityPropertyRole.none,
                exportRole: EntityExportRoleKind.address,
              ),
            ],
          ),
        ],
      );

      // PlaceDescriptor is GeoToolbox's, not the deprecated AppIntents one.
      expect(result, contains('import GeoToolbox'));
      expect(result, contains('import CoreLocation'));
      expect(
        result,
        contains(
          'ValueRepresentation(exporting: { (entity: StoreEntity) -> '
          'PlaceDescriptor in',
        ),
      );
      expect(result, contains('let latitudeValue: Double? = entity.lat'));
      expect(
        result,
        contains(
          '.coordinate(CLLocationCoordinate2D(latitude: latitude, '
          'longitude: longitude))',
        ),
      );
      expect(result, contains('representations.append(.address(address))'));
      expect(result, contains('commonName: entity.name'));
      // Nothing to export is a throw, not an empty place.
      expect(result, contains('code: "EXPORT_UNAVAILABLE"'));
      // The export fields are stored on the entity and read back from the
      // entity dictionary, or the export would always find them nil.
      expect(result, contains('var lat: Double?'));
      expect(result, contains('let lat = dict["lat"] as? Double'));
    });

    test('a currency amount is deliberately not in the catalog', () {
      // `ValueRepresentation(exporting:)` exists only for IntentPerson and for
      // `_SystemIntentValue` types; IntentCurrencyAmount is merely
      // `_IntentValue`, so an export would not compile (measured against the
      // iOS 27.0 SDK). The enum therefore has no case for it.
      expect(EntityExportKind.values, hasLength(2));
      expect(
        EntityExportKind.values.map((k) => k.name),
        containsAll(<String>['person', 'place']),
      );
    });

    test('importable adds an importing: closure over the value query (#129)', () {
      final result = _allExperimental().generateAll(
        entities: [
          _entity(exportAs: EntityExportKind.person, importable: true),
        ],
      );

      expect(result, contains('ValueRepresentation('));
      expect(
        result,
        contains('importing: { (value: IntentPerson) -> ContactEntity in'),
      );
      // Import reuses the #51 value-query bridge under an `#import` identifier;
      // the Dart side registers under the same suffix.
      expect(result, contains('queryIdentifier: "com.example.contact#import"'));
      // A resilient framework enum needs @unknown default or Swift 6 rejects
      // the switch.
      expect(result, contains('@unknown default:'));
      // No match is a throw — the system then declines the drop rather than
      // receiving an invented entity.
      expect(result, contains('code: "IMPORT_FAILED"'));
    });

    test('export alone emits no importing: closure', () {
      final result = _allExperimental().generateAll(
        entities: [_entity(exportAs: EntityExportKind.person)],
      );
      expect(result, isNot(contains('importing:')));
      expect(result, isNot(contains('#import')));
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
