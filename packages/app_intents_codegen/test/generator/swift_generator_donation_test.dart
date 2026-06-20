import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
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

  group('SwiftGenerator (#55 intent donator)', () {
    IntentInfo donatableIntent({
      String className = 'CreateTaskIntentSpec',
      String identifier = 'com.example.taskapp.createTask',
      List<IntentParamInfo> parameters = const [
        IntentParamInfo(
          fieldName: 'title',
          dartType: 'String',
          title: 'Title',
          isOptional: false,
        ),
        IntentParamInfo(
          fieldName: 'note',
          dartType: 'String?',
          title: 'Note',
          isOptional: true,
        ),
        IntentParamInfo(
          fieldName: 'dueDate',
          dartType: 'DateTime?',
          title: 'Due',
          isOptional: true,
        ),
      ],
      bool donatable = true,
    }) => IntentInfo(
      className: className,
      identifier: identifier,
      title: 'Create Task',
      implementation: IntentImplementationType.dart,
      parameters: parameters,
      donatable: donatable,
    );

    test('emits donator registration in #if block when enabled', () {
      final result = _donationOnly().generateAll(intents: [donatableIntent()]);
      expect(result, contains('#if APP_INTENTS_WWDC26'));
      expect(result, contains('@available(iOS 17.0, *)'));
      expect(result, contains('func registerCreateTaskIntentSpecDonator()'));
      expect(result, contains('FlutterBridge.shared.registerIntentDonator('));
      expect(
        result,
        contains('intentIdentifier: "com.example.taskapp.createTask"'),
      );
      expect(result, contains('var intent = CreateTaskIntentSpec()'));
      expect(result, contains('if let v = params["title"] as? String {'));
      expect(result, contains('intent.title = v'));
      expect(result, contains('if let v = params["note"] as? String {'));
      // DateTime fields decode via ISO8601DateFormatter.
      expect(result, contains('if let s = params["dueDate"] as? String,'));
      expect(result, contains('let d = ISO8601DateFormatter().date(from: s)'));
      expect(result, contains('_ = await intent.donate()'));
    });

    test('does not emit donator when donatable=false', () {
      final result = _allExperimental().generateAll(
        intents: [donatableIntent(donatable: false)],
      );
      expect(result, isNot(contains('registerIntentDonator')));
      expect(result, isNot(contains('Donator()')));
    });

    test('does not emit when donation feature disabled', () {
      final gen = const SwiftGenerator(
        experimental: ExperimentalFeatures(
          masterEnabled: true,
          enabled: {ExperimentalFeature.valueQuery},
        ),
      );
      final result = gen.generateAll(intents: [donatableIntent()]);
      expect(result, isNot(contains('registerIntentDonator')));
    });

    test('stable generator emits no donator', () {
      final result = const SwiftGenerator().generateAll(
        intents: [donatableIntent()],
      );
      expect(result, isNot(contains('registerIntentDonator')));
      expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
    });

    test('handles int/double/bool primitive params with the right cast', () {
      final intent = donatableIntent(
        parameters: const [
          IntentParamInfo(
            fieldName: 'count',
            dartType: 'int',
            title: 'Count',
            isOptional: false,
          ),
          IntentParamInfo(
            fieldName: 'rate',
            dartType: 'double',
            title: 'Rate',
            isOptional: false,
          ),
          IntentParamInfo(
            fieldName: 'flag',
            dartType: 'bool',
            title: 'Flag',
            isOptional: false,
          ),
        ],
      );
      final result = _donationOnly().generateAll(intents: [intent]);
      expect(result, contains('if let v = params["count"] as? Int {'));
      expect(result, contains('if let v = params["rate"] as? Double {'));
      expect(result, contains('if let v = params["flag"] as? Bool {'));
    });
  });
}
