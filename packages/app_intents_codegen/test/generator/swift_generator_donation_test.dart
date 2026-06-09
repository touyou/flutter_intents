import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:test/test.dart';

SwiftGenerator _allExperimental() => const SwiftGenerator(
  experimental: ExperimentalFeatures(masterEnabled: true),
);

SwiftGenerator _donationOnly() => const SwiftGenerator(
  experimental: ExperimentalFeatures(
    masterEnabled: true,
    enabled: {ExperimentalFeature.donation},
  ),
);

EntityInfo _entity({bool syncable = false, bool relevantEntities = false}) =>
    EntityInfo(
      className: 'SongEntity',
      identifier: 'com.example.song',
      title: 'Song',
      pluralTitle: 'Songs',
      syncable: syncable,
      relevantEntities: relevantEntities,
      properties: const [
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

void main() {
  group('SwiftGenerator (#55 SyncableEntity)', () {
    test('emits SyncableEntity conformance in #if block when enabled', () {
      final result = _donationOnly().generateAll(
        entities: [_entity(syncable: true)],
      );
      expect(result, contains('#if APP_INTENTS_WWDC26'));
      expect(result, contains('@available(iOS 27.0, *)'));
      expect(result, contains('extension SongEntity: SyncableEntity {}'));
    });

    test('does not emit SyncableEntity when syncable=false', () {
      final result = _allExperimental().generateAll(entities: [_entity()]);
      expect(result, isNot(contains('SyncableEntity')));
    });

    test('stable generator emits no SyncableEntity', () {
      final result = const SwiftGenerator().generateAll(
        entities: [_entity(syncable: true)],
      );
      expect(result, isNot(contains('SyncableEntity')));
    });
  });

  group('SwiftGenerator (#55 RelevantEntities donator)', () {
    test('emits donator registration in #if block when enabled', () {
      final result = _donationOnly().generateAll(
        entities: [_entity(relevantEntities: true)],
      );
      expect(result, contains('#if APP_INTENTS_WWDC26'));
      expect(
        result,
        contains('func registerSongEntityRelevantEntitiesDonator()'),
      );
      expect(
        result,
        contains('FlutterBridge.shared.registerRelevantEntitiesDonator('),
      );
      expect(result, contains('entityIdentifier: "com.example.song"'));
      expect(result, contains('RelevantEntities.shared.updateEntities('));
      expect(result, contains('SongEntity._relevantContext(context)'));
      expect(
        result,
        contains('case "audio.nowPlaying": return .audio(.nowPlaying)'),
      );
    });

    test('does not emit donator when relevantEntities=false', () {
      final result = _allExperimental().generateAll(entities: [_entity()]);
      expect(result, isNot(contains('RelevantEntitiesDonator')));
      expect(result, isNot(contains('RelevantEntities.shared')));
    });

    test('does not emit when donation feature disabled', () {
      final gen = const SwiftGenerator(
        experimental: ExperimentalFeatures(
          masterEnabled: true,
          enabled: {ExperimentalFeature.valueQuery},
        ),
      );
      final result = gen.generateAll(
        entities: [_entity(relevantEntities: true)],
      );
      expect(result, isNot(contains('RelevantEntitiesDonator')));
    });

    test('stable generator emits no donator', () {
      final result = const SwiftGenerator().generateAll(
        entities: [_entity(relevantEntities: true)],
      );
      expect(result, isNot(contains('RelevantEntities')));
      expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
    });
  });
}
