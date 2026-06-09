import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:test/test.dart';

SwiftGenerator _allExperimental() => const SwiftGenerator(
  experimental: ExperimentalFeatures(masterEnabled: true),
);

SwiftGenerator _valueQueryOnly() => const SwiftGenerator(
  experimental: ExperimentalFeatures(
    masterEnabled: true,
    enabled: {ExperimentalFeature.valueQuery},
  ),
);

EntityInfo _entity({bool valueQuery = false}) => EntityInfo(
  className: 'ProductEntity',
  identifier: 'com.example.product',
  title: 'Product',
  pluralTitle: 'Products',
  valueQuery: valueQuery,
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
  group('SwiftGenerator (#51 IntentValueQuery)', () {
    test('emits IntentValueQuery struct in #if block when enabled', () {
      final result = _allExperimental().generateAll(
        entities: [_entity(valueQuery: true)],
      );

      expect(result, contains('#if APP_INTENTS_WWDC26'));
      expect(result, contains('@available(iOS 27.0, *)'));
      expect(
        result,
        contains('struct ProductEntityValueQuery: IntentValueQuery {'),
      );
      expect(result, contains('func values(for input: String) async throws'));
      expect(result, contains('FlutterBridge.shared.queryValues('));
      expect(result, contains('queryIdentifier: "com.example.product"'));
      expect(result, contains('input: ["query": input]'));
      expect(result, contains('#endif'));
    });

    test('value query struct is additive (no #else fallback)', () {
      final result = _valueQueryOnly().generateAll(
        entities: [_entity(valueQuery: true)],
      );

      // The struct is purely additive: gated by #if with no #else.
      final structStart = result.indexOf('IntentValueQuery');
      expect(structStart, greaterThan(-1));
      // The normal EntityQuery is still generated outside the #if.
      expect(result, contains('struct ProductEntityQuery: EntityQuery {'));
    });

    test('does not emit when entity has valueQuery=false', () {
      final result = _allExperimental().generateAll(
        entities: [_entity(valueQuery: false)],
      );
      expect(result, isNot(contains('IntentValueQuery')));
    });

    test('does not emit when value-query feature is disabled', () {
      // Master on but only a different feature selected.
      final gen = const SwiftGenerator(
        experimental: ExperimentalFeatures(
          masterEnabled: true,
          enabled: {ExperimentalFeature.ownership},
        ),
      );
      final result = gen.generateAll(entities: [_entity(valueQuery: true)]);
      expect(result, isNot(contains('IntentValueQuery')));
    });

    test('stable generator emits no value query at all', () {
      final result = const SwiftGenerator().generateAll(
        entities: [_entity(valueQuery: true)],
      );
      expect(result, isNot(contains('IntentValueQuery')));
      expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
    });
  });
}
