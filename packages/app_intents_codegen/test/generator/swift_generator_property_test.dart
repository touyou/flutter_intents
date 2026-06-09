import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:source_gen/source_gen.dart';
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
      expect(result, contains(r'@Property(indexingKey: \.contentDescription)'));
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

    test('init param order follows role order, not Dart field order, so it '
        'matches the construction call site', () {
      // The exposed `body` property is declared BEFORE the `icon` image role
      // field. The generated init must still list role fields first
      // (id, title, icon) then `body`, matching the call site — emitting in
      // field order would produce `init(..., body:, icon:)` while the call
      // passes `(..., icon:, body:)`, which does not compile in Swift.
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
            EntityPropertyInfo(
              fieldName: 'body',
              dartType: 'String',
              role: EntityPropertyRole.none,
              exposeAsProperty: true,
              indexingKey: 'contentDescription',
            ),
            EntityPropertyInfo(
              fieldName: 'icon',
              dartType: 'String',
              role: EntityPropertyRole.image,
            ),
          ],
        ),
      );

      expect(
        result,
        contains(
          'init(id: String, title: String, icon: String, body: String = "")',
        ),
      );
      // The image role `icon` is read from the dict as `String?` and coalesced
      // to the non-optional field type at the call site.
      expect(
        result,
        contains('NoteEntity(id: id, title: title, icon: icon ?? "", body: '),
      );
      // The broken field-order signature must NOT appear.
      expect(
        result,
        isNot(contains('init(id: String, title: String, body: String')),
      );
    });

    test('non-String exposed property uses a type-correct default '
        '(DateTime -> Date())', () {
      final result = const SwiftGenerator().generateEntity(
        _entityWith(
          const EntityPropertyInfo(
            fieldName: 'createdAt',
            dartType: 'DateTime',
            role: EntityPropertyRole.none,
            exposeAsProperty: true,
            propertyTitle: 'Created',
          ),
        ),
      );

      expect(result, contains('createdAt: Date = Date()'));
      // The bogus empty-string default for a non-String type must be gone.
      expect(result, isNot(contains('createdAt: Date = ""')));
    });

    test('exposing an unsupported property type is rejected', () {
      expect(
        () => const SwiftGenerator().generateEntity(
          _entityWith(
            const EntityPropertyInfo(
              fieldName: 'payload',
              dartType: 'CustomType',
              role: EntityPropertyRole.none,
              exposeAsProperty: true,
              propertyTitle: 'Payload',
            ),
          ),
        ),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
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
