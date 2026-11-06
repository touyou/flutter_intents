import 'dart:convert';

import '../models/entity_info.dart';
import '../models/enum_info.dart';
import '../models/intent_info.dart';

/// Builds the intent manifest: every declared intent, entity and enum, with a
/// JSON Schema for the params map each Dart handler receives.
///
/// The schema describes the **wire** shape (what `…Params.fromMap` reads), not
/// the Dart field types: a `DateTime` arrives as an ISO-8601 string, a
/// `Duration` as microseconds, an entity parameter as the entity's id. It is
/// derived from the same [IntentInfo] the Swift and Kotlin generators read, so
/// a parameter cannot exist on one side and be missing from the manifest.
///
/// `package:app_intents/testing.dart` reads this to report declared intents
/// without a handler and to validate params before calling one.
class ManifestGenerator {
  /// Bumped when a consumer would misread the old shape.
  static const int formatVersion = 1;

  /// The JSON Schema dialect of every `parameters` / `schema` object.
  static const String schemaDialect =
      'https://json-schema.org/draft/2020-12/schema';

  /// The manifest as a JSON-encodable map.
  Map<String, Object?> build({
    required List<IntentInfo> intents,
    List<EntityInfo> entities = const [],
    List<EnumInfo> enums = const [],
  }) {
    final entitiesByClass = {for (final e in entities) e.className: e};
    final enumsByClass = {for (final e in enums) e.className: e};
    return {
      'formatVersion': formatVersion,
      // Sorted: source order follows the directory listing, which differs
      // between filesystems, and CI diffs this output.
      'intents': [
        for (final intent in _sorted(intents, (i) => i.identifier))
          _intent(intent, entitiesByClass, enumsByClass),
      ],
      'entities': [
        for (final entity in _sorted(entities, (e) => e.identifier))
          _entity(entity),
      ],
      'enums': [for (final e in _sorted(enums, (e) => e.identifier)) _enum(e)],
    };
  }

  /// [build] as pretty-printed JSON with a trailing newline.
  String generate({
    required List<IntentInfo> intents,
    List<EntityInfo> entities = const [],
    List<EnumInfo> enums = const [],
  }) =>
      '${const JsonEncoder.withIndent('  ').convert(build(intents: intents, entities: entities, enums: enums))}\n';

  static List<T> _sorted<T>(List<T> items, String Function(T) key) =>
      [...items]..sort((a, b) => key(a).compareTo(key(b)));

  Map<String, Object?> _intent(
    IntentInfo intent,
    Map<String, EntityInfo> entities,
    Map<String, EnumInfo> enums,
  ) {
    final properties = <String, Object?>{};
    final required = <String>[];
    for (final param in intent.parameters) {
      final nullable = param.isOptional || param.dartType.endsWith('?');
      final schema = _paramSchema(param, entities, enums);
      properties[param.fieldName] = nullable ? _orNull(schema) : schema;
      if (!nullable) required.add(param.fieldName);
      // The generated Swift adds a sibling state key next to the value.
      if (param.useValueState) {
        properties['${param.fieldName}State'] = {
          'type': 'string',
          'enum': ['unset', 'cleared', 'set'],
        };
      }
    }
    return {
      'identifier': intent.identifier,
      'className': intent.className,
      'title': intent.title,
      'description': ?intent.description,
      'longRunning': intent.longRunning,
      'cancellable': intent.cancellable,
      'parameters': {
        r'$schema': schemaDialect,
        'type': 'object',
        'properties': properties,
        'required': required,
        'additionalProperties': false,
      },
    };
  }

  Map<String, Object?> _paramSchema(
    IntentParamInfo param,
    Map<String, EntityInfo> entities,
    Map<String, EnumInfo> enums,
  ) {
    final base = param.dartType.replaceAll('?', '');
    final annotations = <String, Object?>{
      'title': param.title,
      'description': ?param.description,
    };

    if (param.unionInfo case final union?) {
      return {
        ...annotations,
        'type': 'object',
        'properties': {
          '_type': {
            'type': 'string',
            'enum': [for (final c in union.cases) c.dartClassName],
          },
          'id': {'type': 'string'},
        },
        'required': ['_type', 'id'],
        'additionalProperties': false,
      };
    }
    if (param.entityCollectionType case final type?) {
      return {
        ...annotations,
        'type': 'array',
        'items': {'type': 'string'},
        'x-entity': entities[type]?.identifier ?? type,
      };
    }
    if (param.entityType case final type?) {
      return {
        ...annotations,
        'type': 'string',
        'x-entity': entities[type]?.identifier ?? type,
      };
    }
    if (param.enumType case final type?) {
      final info = enums[type];
      return {
        ...annotations,
        'type': 'string',
        if (info != null) 'enum': [for (final c in info.cases) c.name],
      };
    }
    if (param.fileType != null) {
      return {
        ...annotations,
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          // Both platforms send null when they cannot tell.
          'mimeType': {
            'type': ['string', 'null'],
          },
          'filename': {
            'type': ['string', 'null'],
          },
        },
        'required': ['path'],
      };
    }
    return switch (base) {
      'String' => {...annotations, 'type': 'string'},
      'int' => {...annotations, 'type': 'integer'},
      'double' || 'num' => {...annotations, 'type': 'number'},
      'bool' => {...annotations, 'type': 'boolean'},
      'DateTime' => {...annotations, 'type': 'string', 'format': 'date-time'},
      'Duration' => {
        ...annotations,
        'type': 'integer',
        'x-unit': 'microseconds',
      },
      'PersonName' => {
        ...annotations,
        'type': 'object',
        'properties': {
          for (final key in const [
            'givenName',
            'familyName',
            'middleName',
            'namePrefix',
            'nameSuffix',
            'nickname',
          ])
            key: {'type': 'string'},
        },
        'additionalProperties': false,
      },
      // An unknown type gets no constraint rather than a guessed one: a wrong
      // constraint would fail a call the native side makes successfully.
      _ => {...annotations, 'x-dartType': param.dartType},
    };
  }

  /// [schema] or null, with the annotations kept on the outer schema where a
  /// reader looks for them.
  Map<String, Object?> _orNull(Map<String, Object?> schema) {
    final inner = Map.of(schema);
    final title = inner.remove('title');
    final description = inner.remove('description');
    return {
      'title': ?title,
      'description': ?description,
      'anyOf': [
        inner,
        {'type': 'null'},
      ],
    };
  }

  Map<String, Object?> _entity(EntityInfo entity) {
    final properties = <String, Object?>{};
    final required = <String>[];
    for (final p in entity.properties) {
      final type = switch (p.dartType.replaceAll('?', '')) {
        'String' => 'string',
        'int' => 'integer',
        'double' || 'num' => 'number',
        'bool' => 'boolean',
        _ => null,
      };
      final nullable = p.dartType.endsWith('?');
      // The generated Swift reads every role field with `as? String` and
      // drops the row when id or title is not one.
      final wireType = switch (p.role) {
        EntityPropertyRole.id ||
        EntityPropertyRole.title ||
        EntityPropertyRole.subtitle ||
        EntityPropertyRole.image => 'string',
        _ => type,
      };
      properties[p.fieldName] = {
        if (wireType != null) 'type': nullable ? [wireType, 'null'] : wireType,
        if (p.role != EntityPropertyRole.none) 'x-role': p.role.name,
      };
      // A map missing either is dropped by the generated Swift query.
      if (p.role == EntityPropertyRole.id ||
          p.role == EntityPropertyRole.title) {
        required.add(p.fieldName);
      }
    }
    return {
      'identifier': entity.identifier,
      'className': entity.className,
      'title': entity.title,
      'schema': {
        r'$schema': schemaDialect,
        'type': 'object',
        'properties': properties,
        'required': required,
      },
    };
  }

  Map<String, Object?> _enum(EnumInfo info) => {
    'identifier': info.identifier,
    'className': info.className,
    'title': info.title,
    'cases': [for (final c in info.cases) c.name],
  };
}
