/// A validator for the JSON Schema subset `app_intents_codegen:describe`
/// emits: `type` (a name or a list), `enum`, `properties`, `required`,
/// `additionalProperties: false`, `items`, `anyOf` and `format: date-time`.
///
/// Anything else in a schema (`title`, `x-entity`, …) is ignored, so a schema
/// with keywords this validator does not know never fails a value.
List<String> validateJsonSchema(
  Object? value,
  Map<String, Object?> schema, {
  String path = r'$',
}) {
  final errors = <String>[];
  _validate(value, schema, path, errors);
  return errors;
}

void _validate(
  Object? value,
  Map<String, Object?> schema,
  String path,
  List<String> errors,
) {
  if (schema['anyOf'] case final List<Object?> options) {
    final matches = options.whereType<Map>().any(
      (option) => validateJsonSchema(
        value,
        option.cast<String, Object?>(),
        path: path,
      ).isEmpty,
    );
    if (!matches) {
      errors.add(
        '$path: ${_describe(value)} matches none of the allowed shapes',
      );
    }
  }

  final type = schema['type'];
  if (type != null) {
    final types = type is List ? type.cast<String>() : [type as String];
    if (!types.any((t) => _isType(value, t))) {
      errors.add(
        '$path: expected ${types.join(' or ')}, got ${_describe(value)}',
      );
      return;
    }
  }

  if (schema['enum'] case final List<Object?> allowed
      when !allowed.contains(value)) {
    errors.add('$path: ${_describe(value)} is not one of $allowed');
  }

  if (schema['format'] == 'date-time' &&
      value is String &&
      DateTime.tryParse(value) == null) {
    errors.add('$path: "$value" is not an ISO-8601 date-time');
  }

  if (value is Map) {
    final properties =
        (schema['properties'] as Map?)?.cast<String, Object?>() ?? const {};
    for (final key
        in (schema['required'] as List?)?.cast<String>() ?? const []) {
      if (!value.containsKey(key)) errors.add('$path: missing required "$key"');
    }
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final propertySchema = properties[key];
      if (propertySchema is Map) {
        _validate(
          entry.value,
          propertySchema.cast<String, Object?>(),
          '$path.$key',
          errors,
        );
      } else if (schema['additionalProperties'] == false) {
        errors.add('$path: unexpected key "$key"');
      }
    }
  }

  final items = schema['items'];
  if (value is List && items is Map) {
    for (var i = 0; i < value.length; i++) {
      _validate(value[i], items.cast<String, Object?>(), '$path[$i]', errors);
    }
  }
}

bool _isType(Object? value, String type) => switch (type) {
  'string' => value is String,
  'integer' => value is int,
  'number' => value is num,
  'boolean' => value is bool,
  'object' => value is Map,
  'array' => value is List,
  'null' => value == null,
  _ => true,
};

String _describe(Object? value) => switch (value) {
  null => 'null',
  String() => 'string "$value"',
  _ => '${value.runtimeType} $value',
};
