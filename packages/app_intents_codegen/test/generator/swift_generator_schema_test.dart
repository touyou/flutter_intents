import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

SwiftGenerator _schemaGenerator() => const SwiftGenerator(
  experimental: ExperimentalFeatures(
    masterEnabled: true,
    enabled: {ExperimentalFeature.appSchema},
  ),
);

EntityInfo _entity({String? schema, bool indexed = false}) => EntityInfo(
  className: 'MessageEntity',
  identifier: 'com.example.message',
  title: 'Message',
  pluralTitle: 'Messages',
  schema: schema,
  indexed: indexed,
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
  group('SwiftGenerator (WWDC26 App Schema #49)', () {
    group('entity schema', () {
      test('emits @AppEntity(schema:) dual-branch when enabled', () {
        final result = _schemaGenerator().generateAll(
          entities: [_entity(schema: 'messages.message')],
        );

        expect(result, contains('#if APP_INTENTS_WWDC26'));
        expect(result, contains('@available(iOS 27.0, *)'));
        expect(result, contains('@AppEntity(schema: .messages.message)'));
        expect(result, contains('#else'));
        expect(result, contains('#endif'));

        // The query struct also moves to iOS 27 inside the experimental branch.
        final ifIndex = result.indexOf('#if APP_INTENTS_WWDC26');
        final elseIndex = result.indexOf('#else');
        final ifBranch = result.substring(ifIndex, elseIndex);
        expect(ifBranch, contains('struct MessageEntityQuery: EntityQuery'));
        expect(ifBranch, contains('@available(iOS 27.0, *)'));

        // The #else branch is the stable form: no macro, iOS 17.
        final endifIndex = result.indexOf('#endif');
        final elseBranch = result.substring(elseIndex, endifIndex);
        expect(elseBranch, contains('@available(iOS 17.0, *)'));
        expect(elseBranch, isNot(contains('@AppEntity(schema:')));
      });

      test('default generator emits no schema macro', () {
        final result = const SwiftGenerator().generateAll(
          entities: [_entity(schema: 'messages.message')],
        );
        expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
        expect(result, isNot(contains('@AppEntity(schema:')));
        expect(result, contains('struct MessageEntity: AppEntity {'));
      });

      test('schema + indexed moves the IndexedEntity extension to iOS 27', () {
        final result = _schemaGenerator().generateAll(
          entities: [_entity(schema: 'messages.message', indexed: true)],
        );
        final ifIndex = result.indexOf('#if APP_INTENTS_WWDC26');
        final elseIndex = result.indexOf('#else');
        final ifBranch = result.substring(ifIndex, elseIndex);
        expect(ifBranch, contains('extension MessageEntity: IndexedEntity'));
        // No iOS 26 gate inside the experimental branch — everything is iOS 27.
        expect(ifBranch, isNot(contains('@available(iOS 26.0, *)')));
      });
    });

    group('intent schema', () {
      test('emits @AppIntent(schema:) dual-branch when enabled', () {
        final result = _schemaGenerator().generateAll(
          intents: [
            const IntentInfo(
              className: 'SetReadIntent',
              identifier: 'com.example.setRead',
              title: 'Set Read',
              implementation: IntentImplementationType.dart,
              schema: 'messages.setMessageReadStatus',
              parameters: [],
            ),
          ],
        );

        expect(result, contains('#if APP_INTENTS_WWDC26'));
        expect(
          result,
          contains('@AppIntent(schema: .messages.setMessageReadStatus)'),
        );
        expect(result, contains('@available(iOS 27.0, *)'));
        expect(result, contains('#else'));
        // Stable fallback has no macro.
        final elseBranch = result.substring(result.indexOf('#else'));
        expect(elseBranch, isNot(contains('@AppIntent(schema:')));
      });
    });
  });
}
