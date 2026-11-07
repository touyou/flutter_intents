import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/enum_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

const _all = SwiftGenerator(
  experimental: ExperimentalFeatures(masterEnabled: true),
);
const _sdk273 = 'canImport(AppIntents, _version: 301.2)';
const _videoGate =
    '#if APP_INTENTS_WWDC26 && $_sdk273 && !os(macOS) && !os(watchOS)';

EntityInfo _entity(String? schema, {bool valueQuery = false}) => EntityInfo(
  className: 'MovieEntity',
  identifier: 'com.example.Movie',
  title: 'Movie',
  pluralTitle: 'Movies',
  schema: schema,
  valueQuery: valueQuery,
  ownership: EntityOwnershipType.shared,
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

IntentInfo _intent({
  String? schema,
  bool tool = false,
  List<IntentParamInfo> parameters = const [],
}) => IntentInfo(
  className: 'PlayIntent',
  identifier: 'com.example.play',
  title: 'Play',
  implementation: IntentImplementationType.dart,
  schema: schema,
  tool: tool,
  parameters: parameters,
);

void main() {
  group('video schema (27.3 SDK)', () {
    test('an entity branch also requires the 27.3 SDK', () {
      final swift = _all.generateAll(entities: [_entity('video.movie')]);
      expect(swift, contains('#if APP_INTENTS_WWDC26 && $_sdk273'));
      expect(
        swift,
        contains('@available(iOS 27.3, *)\n@AppEntity(schema: .video.movie)'),
      );
      // The additive ownership extension names the entity, so it follows it.
      expect(
        swift,
        contains(
          '@available(iOS 27.3, *)\nextension MovieEntity: OwnershipProvidingEntity',
        ),
      );
    });

    test('an entity in an older domain keeps the 27.0 gate', () {
      final swift = _all.generateAll(entities: [_entity('messages.message')]);
      expect(swift, isNot(contains(_sdk273)));
      expect(
        swift,
        contains(
          '@available(iOS 27.0, *)\n@AppEntity(schema: .messages.message)',
        ),
      );
    });

    test('an intent with a video schema', () {
      final swift = _all.generateAll(
        intents: [_intent(schema: 'video.playContent')],
      );
      expect(swift, contains('#if APP_INTENTS_WWDC26 && $_sdk273'));
      expect(
        swift,
        contains(
          '@available(iOS 27.3, *)\n@AppIntent(schema: .video.playContent)',
        ),
      );
      expect(swift, contains('#else\n@available(iOS 17.0, *)'));
    });

    test('an intent taking a video entity follows the entity', () {
      final swift = _all.generateAll(
        intents: [
          _intent(
            parameters: const [
              IntentParamInfo(
                fieldName: 'movie',
                dartType: 'String',
                title: 'Movie',
                isOptional: false,
                entityType: 'MovieEntity',
              ),
            ],
          ),
        ],
        entities: [_entity('video.movie')],
      );
      expect(
        swift,
        contains('$_videoGate\n@available(iOS 27.3, *)\nstruct PlayIntent'),
      );
    });

    test('an enum with a video schema', () {
      final swift = _all.generateAll(
        enums: const [
          EnumInfo(
            className: 'ContentType',
            identifier: 'com.example.ContentType',
            title: 'Content Type',
            schema: 'video.videoContentType',
            cases: [EnumCaseInfo(name: 'movie', displayTitle: 'Movie')],
          ),
        ],
      );
      expect(swift, contains('#if APP_INTENTS_WWDC26 && $_sdk273'));
      expect(swift, contains('@AppEnum(schema: .video.videoContentType)'));
    });

    test('every additive block of a dual-id video entity follows it', () {
      const entity = EntityInfo(
        className: 'MovieEntity',
        identifier: 'com.example.Movie',
        title: 'Movie',
        pluralTitle: 'Movies',
        schema: 'video.movie',
        syncable: true,
        relevantEntities: true,
        indexed: true,
        exportAs: EntityExportKind.person,
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
            fieldName: 'serverId',
            dartType: 'String',
            role: EntityPropertyRole.none,
            isStableId: true,
          ),
        ],
      );
      final swift = _all.generateAll(entities: [entity]);
      // Each of these names the dual-id entity shape, which exists only
      // where the entity's own 27.3 branch compiled.
      expect(RegExp('#if APP_INTENTS_WWDC26\n').hasMatch(swift), isFalse);
      expect(swift, contains('IndexedEntityQuery'));
      expect(swift, contains('Transferable'));
      expect(swift, contains('RelevantEntitiesDonator'));
    });

    test('an intent taking a video enum follows the enum', () {
      const contentType = EnumInfo(
        className: 'ContentType',
        identifier: 'com.example.ContentType',
        title: 'Content Type',
        schema: 'video.videoContentType',
        cases: [EnumCaseInfo(name: 'movie', displayTitle: 'Movie')],
      );
      final swift = _all.generateAll(
        intents: [
          _intent(
            parameters: const [
              IntentParamInfo(
                fieldName: 'kind',
                dartType: 'String',
                title: 'Kind',
                isOptional: false,
                enumType: 'ContentType',
              ),
            ],
          ),
        ],
        enums: [contentType],
      );
      expect(
        swift,
        contains('$_videoGate\n@available(iOS 27.3, *)\nstruct PlayIntent'),
      );
    });

    test('a donator for a video intent is available from 27.3', () {
      final swift = _all.generateAll(
        intents: [
          IntentInfo(
            className: 'PlayIntent',
            identifier: 'com.example.play',
            title: 'Play',
            implementation: IntentImplementationType.dart,
            schema: 'video.playContent',
            donatable: true,
            parameters: const [],
          ),
        ],
      );
      expect(
        swift,
        contains(
          '$_videoGate\n@available(iOS 27.3, *)\n'
          '/// Registers the intent donator for PlayIntent.',
        ),
      );
    });

    test('generateIntent follows a video entity it is given', () {
      final swift = _all.generateIntent(
        _intent(
          parameters: const [
            IntentParamInfo(
              fieldName: 'movie',
              dartType: 'String',
              title: 'Movie',
              isOptional: false,
              entityType: 'MovieEntity',
            ),
          ],
        ),
        entities: [_entity('video.movie')],
      );
      expect(swift, contains(_videoGate));
    });

    test('without app-schema nothing is gated on 27.3', () {
      const gen = SwiftGenerator(
        experimental: ExperimentalFeatures(
          masterEnabled: true,
          enabled: {ExperimentalFeature.longRunning},
        ),
      );
      final swift = gen.generateAll(entities: [_entity('video.movie')]);
      expect(swift, isNot(contains(_sdk273)));
      expect(swift, isNot(contains('.video.movie')));
    });
  });

  group('tool intents', () {
    test('adds a gated ToolIntent extension and leaves the struct alone', () {
      final swift = _all.generateAll(intents: [_intent(tool: true)]);
      expect(
        swift,
        contains(
          '#if APP_INTENTS_WWDC26 && $_sdk273 && !os(watchOS) && !os(tvOS)\n'
          '@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)\n'
          'extension PlayIntent: ToolIntent {}\n'
          '#endif',
        ),
      );
      expect(
        swift,
        contains('@available(iOS 17.0, *)\nstruct PlayIntent: AppIntent {'),
      );
    });

    test('generateIntent emits it too', () {
      expect(_all.generateIntent(_intent(tool: true)), contains('ToolIntent'));
    });

    test('is off without the tool feature', () {
      expect(
        const SwiftGenerator().generateAll(intents: [_intent(tool: true)]),
        isNot(contains('ToolIntent')),
      );
    });
  });
}
