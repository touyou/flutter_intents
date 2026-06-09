import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/enum_info.dart';
import 'package:test/test.dart';

SwiftGenerator _allExperimental() =>
    const SwiftGenerator(experimental: ExperimentalFeatures(masterEnabled: true));

EntityInfo _entity({
  String? schema,
  EntityOwnershipType? ownership,
}) => EntityInfo(
  className: 'ThingEntity',
  identifier: 'com.example.thing',
  title: 'Thing',
  pluralTitle: 'Things',
  schema: schema,
  ownership: ownership,
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
  group('SwiftGenerator (#49 enum schema)', () {
    EnumInfo enumInfo({String? schema}) => EnumInfo(
      className: 'MessageType',
      identifier: 'com.example.MessageType',
      title: 'Message Type',
      schema: schema,
      cases: const [
        EnumCaseInfo(name: 'text', displayTitle: 'Text'),
        EnumCaseInfo(name: 'image', displayTitle: 'Image'),
      ],
    );

    test('emits @AppEnum(schema:) dual-branch when enabled', () {
      final result = _allExperimental().generateAll(
        enums: [enumInfo(schema: 'messages.messageType')],
      );
      expect(result, contains('#if APP_INTENTS_WWDC26'));
      expect(result, contains('@AppEnum(schema: .messages.messageType)'));
      expect(result, contains('@available(iOS 27.0, *)'));
      expect(result, contains('#else'));
      final elseBranch = result.substring(result.indexOf('#else'));
      expect(elseBranch, isNot(contains('@AppEnum(schema:')));
    });

    test('default generator emits no schema macro', () {
      final result = const SwiftGenerator().generateAll(
        enums: [enumInfo(schema: 'messages.messageType')],
      );
      expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
      expect(result, isNot(contains('@AppEnum(schema:')));
      expect(result, contains('enum MessageType: String, AppEnum {'));
    });
  });

  group('SwiftGenerator (#55 ownership)', () {
    test('emits OwnershipProvidingEntity extension in #if block', () {
      final result = _allExperimental().generateAll(
        entities: [_entity(ownership: EntityOwnershipType.shared)],
      );
      expect(result, contains('#if APP_INTENTS_WWDC26'));
      expect(
        result,
        contains('extension ThingEntity: OwnershipProvidingEntity {'),
      );
      expect(result, contains('var ownership: EntityOwnership { .shared }'));
      expect(result, contains('@available(iOS 27.0, *)'));
    });

    test('maps each ownership state', () {
      final pub = _allExperimental().generateAll(
        entities: [_entity(ownership: EntityOwnershipType.public)],
      );
      expect(pub, contains('var ownership: EntityOwnership { .public }'));

      final unknown = _allExperimental().generateAll(
        entities: [_entity(ownership: EntityOwnershipType.unknown)],
      );
      expect(unknown, contains('var ownership: EntityOwnership { .unknown }'));
    });

    test('default generator emits no ownership extension', () {
      final result = const SwiftGenerator().generateAll(
        entities: [_entity(ownership: EntityOwnershipType.shared)],
      );
      expect(result, isNot(contains('OwnershipProvidingEntity')));
    });
  });
}
