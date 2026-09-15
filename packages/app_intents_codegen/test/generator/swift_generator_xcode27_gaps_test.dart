import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:app_intents_codegen/src/models/union_info.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

SwiftGenerator _experimental() => const SwiftGenerator(
  experimental: ExperimentalFeatures(masterEnabled: true),
);

EntityInfo _entity({
  String className = 'DeviceEntity',
  String identifier = 'com.example.device',
  bool syncable = false,
  bool stableId = false,
  bool indexed = false,
  bool relevantEntities = false,
}) => EntityInfo(
  className: className,
  identifier: identifier,
  title: 'Device',
  pluralTitle: 'Devices',
  syncable: syncable,
  indexed: indexed,
  relevantEntities: relevantEntities,
  properties: [
    const EntityPropertyInfo(
      fieldName: 'localId',
      dartType: 'String',
      role: EntityPropertyRole.id,
    ),
    const EntityPropertyInfo(
      fieldName: 'name',
      dartType: 'String',
      role: EntityPropertyRole.title,
    ),
    if (stableId)
      const EntityPropertyInfo(
        fieldName: 'serverId',
        dartType: 'String',
        role: EntityPropertyRole.none,
        isStableId: true,
      ),
  ],
);

void main() {
  group('SwiftGenerator (#132 dual SyncableEntityIdentifier)', () {
    test('dual-branches the entity and pairs the two identifiers', () {
      final result = _experimental().generateAll(
        entities: [_entity(syncable: true, stableId: true)],
      );

      final wwdc26 = result.substring(
        result.indexOf('#if APP_INTENTS_WWDC26'),
        result.indexOf('#else'),
      );
      expect(
        wwdc26,
        contains('var id: SyncableEntityIdentifier<String, String>'),
      );
      expect(
        wwdc26,
        contains('SyncableEntityIdentifier(local: id, stable: serverId ?? id)'),
      );
      // The query's parameter type follows Entity.ID, and the bridge only
      // speaks strings — both halves are sent so the Dart handler can match on
      // whichever it keys its data by.
      expect(
        wwdc26,
        contains(
          'func entities(for identifiers: [SyncableEntityIdentifier<String, String>])',
        ),
      );
      expect(wwdc26, contains('[pair.local, pair.stable].compactMap'));

      // SyncableEntityIdentifier is iOS 27 only, so the fallback keeps a scalar
      // id and the stable id as an ordinary property.
      final stable = result.substring(result.indexOf('#else'));
      expect(stable, contains('var id: String'));
      expect(stable, contains('var serverId: String'));
      expect(stable, isNot(contains('SyncableEntityIdentifier')));
    });

    test('syncable without a stable id stays a scalar identifier', () {
      final result = _experimental().generateAll(
        entities: [_entity(syncable: true)],
      );
      expect(result, isNot(contains('SyncableEntityIdentifier')));
      expect(result, contains('extension DeviceEntity: SyncableEntity {}'));
    });

    test('a dual-id entity cannot be an intent parameter', () {
      expect(
        () => _experimental().generateAll(
          intents: [
            IntentInfo(
              className: 'RenameDeviceIntent',
              identifier: 'com.example.renameDevice',
              title: 'Rename Device',
              implementation: IntentImplementationType.dart,
              parameters: const [
                IntentParamInfo(
                  fieldName: 'device',
                  dartType: 'String',
                  title: 'Device',
                  isOptional: false,
                  entityType: 'DeviceEntity',
                ),
              ],
            ),
          ],
          entities: [_entity(syncable: true, stableId: true)],
        ),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('no single string form'),
          ),
        ),
      );
    });
  });

  group('SwiftGenerator (#133 Xcode 27 gaps)', () {
    test('the RelevantEntities donator handles remove and removeAll', () {
      final result = _experimental().generateAll(
        entities: [_entity(relevantEntities: true)],
      );

      expect(result, contains('{ operation, dicts, context in'));
      expect(result, contains('case "remove":'));
      expect(
        result,
        contains('try await RelevantEntities.shared.removeEntities(entities)'),
      );
      expect(result, contains('case "removeAll":'));
      expect(
        result,
        contains('try await RelevantEntities.shared.removeAllEntities()'),
      );
      // A context scopes the removal; without one it spans every context,
      // which an empty update could never express.
      expect(result, contains('removeAllEntities(for: entityContext)'));
      expect(result, contains('updateEntities(entities, for: entityContext)'));
    });

    test('an indexed entity gains IndexedEntityQuery re-indexing', () {
      final result = _experimental().generateAll(
        entities: [_entity(indexed: true)],
      );

      expect(
        result,
        contains('extension DeviceEntityQuery: IndexedEntityQuery {'),
      );
      // Re-indexing re-reads through the existing query path (which is what
      // reaches Dart) and hands the result to Spotlight — no new bridge call.
      expect(
        result,
        contains('let refreshed = try await entities(for: identifiers)'),
      );
      expect(
        result,
        contains('CSSearchableIndex.default().indexAppEntities(refreshed)'),
      );
      expect(result, contains('let refreshed = try await suggestedEntities()'));
    });

    test('re-indexing is opt-in per feature flag', () {
      final gen = const SwiftGenerator(
        experimental: ExperimentalFeatures(
          masterEnabled: true,
          enabled: {ExperimentalFeature.donation},
        ),
      );
      final result = gen.generateAll(entities: [_entity(indexed: true)]);
      expect(result, isNot(contains('IndexedEntityQuery')));
    });

    test('a union value query switches on the _type discriminant', () {
      final result = _experimental().generateAll(
        entities: [
          _entity(
            className: 'ProductEntity',
            identifier: 'com.example.product',
          ),
          _entity(
            className: 'MessageEntity',
            identifier: 'com.example.message',
          ),
        ],
        unions: const [
          UnionInfo(
            className: 'SearchResult',
            identifier: 'com.example.SearchResult',
            valueQuery: true,
            cases: [
              UnionCaseInfo(
                dartClassName: 'ProductResult',
                entityType: 'ProductEntity',
              ),
              UnionCaseInfo(
                dartClassName: 'MessageResult',
                entityType: 'MessageEntity',
              ),
            ],
          ),
        ],
      );

      // The union enum itself is emitted even though no intent parameter
      // references it — a query-only union is reached through nothing else.
      expect(result, contains('enum SearchResult {'));
      expect(
        result,
        contains('struct SearchResultValueQuery: IntentValueQuery {'),
      );
      expect(
        result,
        contains(
          'func values(for input: String) async throws -> [SearchResult]',
        ),
      );
      expect(result, contains('queryIdentifier: "com.example.SearchResult"'));
      expect(result, contains('switch dict["_type"] as? String {'));
      expect(result, contains('case "ProductResult":'));
      expect(
        result,
        contains('return ProductEntity._fromUnionDictionary(dict)'),
      );
      expect(result, contains('.map(SearchResult.productResult)'));
    });

    test('two value-query unions sharing an entity emit one decoder', () {
      UnionInfo union(String name) => UnionInfo(
        className: name,
        identifier: 'com.example.$name',
        valueQuery: true,
        cases: const [
          UnionCaseInfo(
            dartClassName: 'ProductHit',
            entityType: 'ProductEntity',
          ),
        ],
      );
      final result = _experimental().generateAll(
        entities: [
          _entity(
            className: 'ProductEntity',
            identifier: 'com.example.product',
          ),
        ],
        unions: [union('SearchResult'), union('VisualResult')],
      );

      // Swift rejects a second `_fromUnionDictionary` on the same type.
      expect(
        '_fromUnionDictionary(_ dict'.allMatches(result).length,
        equals(1),
      );
      expect(result, contains('struct SearchResultValueQuery'));
      expect(result, contains('struct VisualResultValueQuery'));
    });

    test('a union parameter naming a dual-id entity is rejected', () {
      expect(
        () => _experimental().generateAll(
          intents: [
            IntentInfo(
              className: 'OpenThingIntent',
              identifier: 'com.example.openThing',
              title: 'Open Thing',
              implementation: IntentImplementationType.dart,
              parameters: const [
                IntentParamInfo(
                  fieldName: 'thing',
                  dartType: 'Thing',
                  title: 'Thing',
                  isOptional: false,
                  unionInfo: UnionInfo(
                    className: 'Thing',
                    identifier: 'com.example.Thing',
                    cases: [
                      UnionCaseInfo(
                        dartClassName: 'DeviceThing',
                        entityType: 'DeviceEntity',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          entities: [_entity(syncable: true, stableId: true)],
        ),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('no single string form'),
          ),
        ),
      );
    });

    test('a union case naming an unknown entity is a generation error', () {
      expect(
        () => _experimental().generateAll(
          entities: [_entity(className: 'ProductEntity')],
          unions: const [
            UnionInfo(
              className: 'SearchResult',
              identifier: 'com.example.SearchResult',
              valueQuery: true,
              cases: [
                UnionCaseInfo(
                  dartClassName: 'GhostResult',
                  entityType: 'GhostEntity',
                ),
              ],
            ),
          ],
        ),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('no @EntitySpec in this generation run'),
          ),
        ),
      );
    });
  });
}
