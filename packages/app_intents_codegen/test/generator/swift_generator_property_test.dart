import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:test/test.dart';

EntityInfo _entityWith(EntityPropertyInfo extra) => EntityInfo(
  className: 'NoteEntity',
  identifier: 'com.example.note',
  title: 'Note',
  pluralTitle: 'Notes',
  properties: [
    const EntityPropertyInfo(
      fieldName: 'id',
      dartType: 'String',
      role: EntityPropertyRole.id,
    ),
    const EntityPropertyInfo(
      fieldName: 'title',
      dartType: 'String',
      role: EntityPropertyRole.title,
    ),
    extra,
  ],
);

void main() {
  // @Property semantic indexing is a normal feature (no experimental flag).
  group('SwiftGenerator (@Property semantic indexing #50)', () {
    test('indexingKey emits @Property(indexingKey:) at iOS 18.4', () {
      final result = const SwiftGenerator().generateEntity(
        _entityWith(
          const EntityPropertyInfo(
            fieldName: 'body',
            dartType: 'String',
            role: EntityPropertyRole.none,
            exposeAsProperty: true,
            indexingKey: 'contentDescription',
          ),
        ),
      );

      expect(result, contains('import CoreSpotlight'));
      expect(result, contains('@available(iOS 18.4, *)'));
      expect(
        result,
        contains(r'@Property(indexingKey: \.contentDescription)'),
      );
      expect(result, contains('var body: String'));
      // Not gated by the experimental flag.
      expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
    });

    test('exposed property gets a custom init with a default value', () {
      final result = const SwiftGenerator().generateEntity(
        _entityWith(
          const EntityPropertyInfo(
            fieldName: 'body',
            dartType: 'String',
            role: EntityPropertyRole.none,
            exposeAsProperty: true,
            indexingKey: 'contentDescription',
          ),
        ),
      );

      expect(
        result,
        contains('init(id: String, title: String, body: String = "")'),
      );
      expect(result, contains('self.body = body'));
      // The query constructs the entity and populates the property from the dict.
      expect(result, contains('let body = dict["body"] as? String'));
      expect(
        result,
        contains('NoteEntity(id: id, title: title, body: body ?? "")'),
      );
    });

    test('title-only @Property stays at iOS 17 (no indexingKey)', () {
      final result = const SwiftGenerator().generateEntity(
        _entityWith(
          const EntityPropertyInfo(
            fieldName: 'body',
            dartType: 'String',
            role: EntityPropertyRole.none,
            exposeAsProperty: true,
            propertyTitle: 'Body',
          ),
        ),
      );

      expect(result, contains('@Property(title: "Body")'));
      expect(result, contains('@available(iOS 17.0, *)'));
      expect(result, isNot(contains('import CoreSpotlight')));
    });

    test('entities without exposed properties are unchanged (no init)', () {
      final result = const SwiftGenerator().generateEntity(
        EntityInfo(
          className: 'NoteEntity',
          identifier: 'com.example.note',
          title: 'Note',
          pluralTitle: 'Notes',
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
        ),
      );
      expect(result, isNot(contains('init(')));
      expect(result, isNot(contains('@Property')));
    });
  });
}
