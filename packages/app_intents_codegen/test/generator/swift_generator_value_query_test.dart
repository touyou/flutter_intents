import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:test/test.dart';

SwiftGenerator _allExperimental() => const SwiftGenerator(
  experimental: ExperimentalFeatures(masterEnabled: true),
);

EntityInfo _entity({bool valueQuery = false, String? schema}) => EntityInfo(
  className: 'ProductEntity',
  identifier: 'com.example.product',
  title: 'Product',
  pluralTitle: 'Products',
  valueQuery: valueQuery,
  schema: schema,
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
    test(
      'emits the query on the stable generator, gated only by @available',
      () {
        // #51 graduated out of the experimental opt-in: `IntentValueQuery` is
        // declared at iOS 26.0 in the released SDK, so no #if is needed.
        final result = const SwiftGenerator().generateAll(
          entities: [_entity(valueQuery: true)],
        );

        expect(result, contains('@available(iOS 26.0, *)'));
        expect(
          result,
          contains('struct ProductEntityValueQuery: IntentValueQuery {'),
        );
        expect(result, contains('func values(for input: String) async throws'));
        expect(result, contains('FlutterBridge.shared.queryValues('));
        expect(result, contains('queryIdentifier: "com.example.product"'));
        expect(result, contains('input: ["query": input]'));
        expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
      },
    );

    test('the normal EntityQuery is still generated alongside it', () {
      final result = const SwiftGenerator().generateAll(
        entities: [_entity(valueQuery: true)],
      );
      expect(result, contains('struct ProductEntityQuery: EntityQuery {'));
    });

    test('does not emit when entity has valueQuery=false', () {
      final result = const SwiftGenerator().generateAll(
        entities: [_entity(valueQuery: false)],
      );
      expect(result, isNot(contains('IntentValueQuery')));
    });

    test('experimental generator emits the same ungated query', () {
      final result = _allExperimental().generateAll(
        entities: [_entity(valueQuery: true)],
      );
      expect(
        result,
        contains('struct ProductEntityValueQuery: IntentValueQuery {'),
      );
      expect(result, contains('@available(iOS 26.0, *)'));
    });

    test('follows an App Schema entity into both branches', () {
      // With app-schema on, the entity type itself only exists at iOS 27 inside
      // the #if branch, so a plain iOS 26.0 query would reference a type newer
      // than itself. The query has to dual-branch with the entity.
      final result = _allExperimental().generateAll(
        entities: [_entity(valueQuery: true, schema: 'reminders.reminder')],
      );

      const declaration = 'struct ProductEntityValueQuery: IntentValueQuery {';
      final declarations = declaration.allMatches(result).toList();
      expect(declarations.length, 2);

      // Each declaration is preceded by its branch's availability line.
      String availabilityBefore(Match m) =>
          result.substring(0, m.start).trimRight().split('\n').last.trim();
      expect(availabilityBefore(declarations[0]), '@available(iOS 27.0, *)');
      expect(availabilityBefore(declarations[1]), '@available(iOS 26.0, *)');

      // ...and the pair lives inside a #if/#else/#endif.
      final block = result.substring(
        result.lastIndexOf('#if APP_INTENTS_WWDC26', declarations[0].start),
        result.indexOf('#endif', declarations[1].end) + '#endif'.length,
      );
      expect(block, contains('#else'));
    });
  });
}
