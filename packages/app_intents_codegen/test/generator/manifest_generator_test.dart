import 'dart:convert';

import 'package:app_intents_codegen/app_intents_codegen.dart';
import 'package:app_intents_codegen/src/models/union_info.dart';
import 'package:test/test.dart';

IntentParamInfo _param(
  String name,
  String dartType, {
  bool isOptional = false,
  String? entityType,
  String? enumType,
  String? fileType,
  String? entityCollectionType,
  UnionInfo? unionInfo,
  bool useValueState = false,
}) => IntentParamInfo(
  fieldName: name,
  dartType: dartType,
  title: name,
  isOptional: isOptional,
  entityType: entityType,
  enumType: enumType,
  fileType: fileType,
  entityCollectionType: entityCollectionType,
  unionInfo: unionInfo,
  useValueState: useValueState,
);

void main() {
  const entity = EntityInfo(
    className: 'TaskEntitySpec',
    identifier: 'com.example.Task',
    title: 'Task',
    pluralTitle: 'Tasks',
    properties: [
      EntityPropertyInfo(
        fieldName: 'taskId',
        dartType: 'String',
        role: EntityPropertyRole.id,
      ),
      EntityPropertyInfo(
        fieldName: 'name',
        dartType: 'String',
        role: EntityPropertyRole.title,
      ),
      EntityPropertyInfo(
        fieldName: 'note',
        dartType: 'String?',
        role: EntityPropertyRole.subtitle,
      ),
    ],
  );
  const priority = EnumInfo(
    className: 'PrioritySpec',
    identifier: 'com.example.Priority',
    title: 'Priority',
    cases: [
      EnumCaseInfo(name: 'low', displayTitle: 'Low'),
      EnumCaseInfo(name: 'high', displayTitle: 'High'),
    ],
  );

  Map<String, Object?> properties(List<IntentParamInfo> params) {
    final manifest = ManifestGenerator().build(
      intents: [
        IntentInfo(
          className: 'DoSpec',
          identifier: 'com.example.do',
          title: 'Do',
          implementation: IntentImplementationType.dart,
          parameters: params,
        ),
      ],
      entities: [entity],
      enums: [priority],
    );
    final intent = (manifest['intents'] as List).single as Map;
    return (intent['parameters'] as Map)['properties'] as Map<String, Object?>;
  }

  test('describes the wire shape the Dart handler reads', () {
    final props = properties([
      _param('title', 'String'),
      _param('count', 'int'),
      _param('ratio', 'double'),
      _param('done', 'bool'),
      _param('due', 'DateTime'),
      _param('length', 'Duration'),
      _param('task', 'String', entityType: 'TaskEntitySpec'),
      _param('level', 'String', enumType: 'PrioritySpec'),
      _param('tasks', 'List<String>', entityCollectionType: 'TaskEntitySpec'),
    ]);

    expect(props['title'], containsPair('type', 'string'));
    expect(props['count'], containsPair('type', 'integer'));
    expect(props['ratio'], containsPair('type', 'number'));
    expect(props['done'], containsPair('type', 'boolean'));
    expect(props['due'], containsPair('format', 'date-time'));
    expect(props['length'], containsPair('type', 'integer'));
    expect(props['task'], containsPair('x-entity', 'com.example.Task'));
    expect(props['level'], containsPair('enum', ['low', 'high']));
    expect(props['tasks'], containsPair('type', 'array'));
  });

  test('optional params allow null and are not required', () {
    final manifest = ManifestGenerator().build(
      intents: [
        IntentInfo(
          className: 'DoSpec',
          identifier: 'com.example.do',
          title: 'Do',
          implementation: IntentImplementationType.dart,
          parameters: [
            _param('title', 'String'),
            _param('note', 'String?'),
            _param('extra', 'int', isOptional: true),
          ],
        ),
      ],
    );
    final schema =
        ((manifest['intents'] as List).single as Map)['parameters'] as Map;
    expect(schema['required'], ['title']);
    expect(schema['additionalProperties'], isFalse);
    final note = (schema['properties'] as Map)['note'] as Map;
    expect(note['title'], 'note');
    expect(note['anyOf'], [
      {'type': 'string'},
      {'type': 'null'},
    ]);
  });

  test('a value-state param gets its sibling state key', () {
    final props = properties([_param('note', 'String?', useValueState: true)]);
    expect(props['noteState'], {
      'type': 'string',
      'enum': ['unset', 'cleared', 'set'],
    });
  });

  test('union params are a tagged map', () {
    const union = UnionInfo(
      className: 'Content',
      identifier: 'com.example.Content',
      cases: [
        UnionCaseInfo(dartClassName: 'PhotoCase', entityType: 'PhotoSpec'),
        UnionCaseInfo(dartClassName: 'AlbumCase', entityType: 'AlbumSpec'),
      ],
    );
    final props = properties([_param('content', 'Content', unionInfo: union)]);
    final content = props['content'] as Map;
    expect((content['properties'] as Map)['_type'], {
      'type': 'string',
      'enum': ['PhotoCase', 'AlbumCase'],
    });
    expect(content['required'], ['_type', 'id']);
  });

  test('lists declarations by identifier, not by source order', () {
    IntentInfo intent(String id) => IntentInfo(
      className: id,
      identifier: id,
      title: id,
      implementation: IntentImplementationType.dart,
      parameters: const [],
    );
    final manifest = ManifestGenerator().build(
      intents: [intent('b'), intent('a')],
    );
    expect(
      [for (final i in manifest['intents'] as List) i['identifier']],
      ['a', 'b'],
    );
  });

  test('a file param allows a null mimeType and filename', () {
    final file =
        properties([_param('f', 'IntentFile', fileType: 'image')])['f'] as Map;
    expect((file['properties'] as Map)['mimeType'], {
      'type': ['string', 'null'],
    });
  });

  test('an unknown type gets no constraint', () {
    final props = properties([_param('blob', 'Uint8List')]);
    expect(props['blob'], isNot(contains('type')));
  });

  test('entities require their id and title keys', () {
    final manifest = ManifestGenerator().build(
      intents: const [],
      entities: [entity],
    );
    final schema =
        ((manifest['entities'] as List).single as Map)['schema'] as Map;
    expect(schema['required'], ['taskId', 'name']);
    expect((schema['properties'] as Map)['note'], {
      'type': ['string', 'null'],
      'x-role': 'subtitle',
    });
  });

  test('records the implementation and never lets id or title be null', () {
    final manifest = ManifestGenerator().build(
      intents: const [
        IntentInfo(
          className: 'NativeSpec',
          identifier: 'com.example.native',
          title: 'Native',
          implementation: IntentImplementationType.swift,
          parameters: [],
        ),
      ],
      entities: const [
        EntityInfo(
          className: 'NoteSpec',
          identifier: 'com.example.Note',
          title: 'Note',
          pluralTitle: 'Notes',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String?',
              role: EntityPropertyRole.id,
            ),
            EntityPropertyInfo(
              fieldName: 'name',
              dartType: 'String?',
              role: EntityPropertyRole.title,
            ),
          ],
        ),
      ],
    );
    expect(
      ((manifest['intents'] as List).single as Map)['implementation'],
      'swift',
    );
    final props =
        (((manifest['entities'] as List).single as Map)['schema']
                as Map)['properties']
            as Map;
    expect(props['id'], containsPair('type', 'string'));
    expect(props['name'], containsPair('type', 'string'));
  });

  test('generate emits JSON that round-trips', () {
    final json = ManifestGenerator().generate(
      intents: const [],
      enums: [priority],
    );
    final decoded = jsonDecode(json) as Map;
    expect(decoded['formatVersion'], ManifestGenerator.formatVersion);
    expect(
      (decoded['enums'] as List).single,
      containsPair('cases', ['low', 'high']),
    );
  });
}
