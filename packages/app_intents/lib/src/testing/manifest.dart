import 'dart:convert';

/// What `dart run app_intents_codegen:describe` declared: every intent, entity
/// and enum, with a JSON Schema for each intent's params.
class AppIntentsManifest {
  /// Creates a manifest from already-decoded parts.
  const AppIntentsManifest({
    required this.intents,
    this.entities = const [],
    this.enums = const [],
  });

  /// Parses the JSON the `describe` command writes.
  factory AppIntentsManifest.parse(String json) =>
      AppIntentsManifest.fromJson(jsonDecode(json) as Map<String, Object?>);

  /// Reads a decoded manifest.
  ///
  /// Throws [FormatException] for a `formatVersion` this package does not
  /// know: reading a newer shape as the old one would validate against the
  /// wrong schema.
  factory AppIntentsManifest.fromJson(Map<String, Object?> json) {
    final version = json['formatVersion'];
    if (version != supportedFormatVersion) {
      throw FormatException(
        'Unsupported app_intents manifest formatVersion $version '
        '(expected $supportedFormatVersion). Regenerate it with '
        '`dart run app_intents_codegen:describe` from a matching '
        'app_intents_codegen version.',
      );
    }
    List<Map<String, Object?>> list(String key) => [
      for (final item in (json[key] as List?) ?? const [])
        (item as Map).cast<String, Object?>(),
    ];
    return AppIntentsManifest(
      intents: [for (final i in list('intents')) DeclaredIntent._(i)],
      entities: [for (final e in list('entities')) DeclaredEntity._(e)],
      enums: [for (final e in list('enums')) DeclaredEnum._(e)],
    );
  }

  /// The `formatVersion` this package reads.
  static const int supportedFormatVersion = 1;

  /// Declared intents, in source order.
  final List<DeclaredIntent> intents;

  /// Declared entities, in source order.
  final List<DeclaredEntity> entities;

  /// Declared enums, in source order.
  final List<DeclaredEnum> enums;

  /// The declared intent with [identifier], or null.
  DeclaredIntent? intent(String identifier) {
    for (final i in intents) {
      if (i.identifier == identifier) return i;
    }
    return null;
  }

  /// The declared entity with [identifier], or null.
  DeclaredEntity? entity(String identifier) {
    for (final e in entities) {
      if (e.identifier == identifier) return e;
    }
    return null;
  }
}

/// One `@IntentSpec` from the manifest.
class DeclaredIntent {
  DeclaredIntent._(this.json);

  /// The raw manifest entry.
  final Map<String, Object?> json;

  /// `@IntentSpec.identifier`, the key the handler is registered under.
  String get identifier => json['identifier'] as String;

  /// The spec class name.
  String get className => json['className'] as String;

  /// The intent's title.
  String get title => json['title'] as String;

  /// The intent's description, if any.
  String? get description => json['description'] as String?;

  /// JSON Schema of the params map the handler receives.
  Map<String, Object?> get parameters =>
      (json['parameters'] as Map).cast<String, Object?>();

  @override
  String toString() => 'DeclaredIntent($identifier)';
}

/// One `@EntitySpec` from the manifest.
class DeclaredEntity {
  DeclaredEntity._(this.json);

  /// The raw manifest entry.
  final Map<String, Object?> json;

  /// `@EntitySpec.identifier`, the key the query handlers are registered under.
  String get identifier => json['identifier'] as String;

  /// The spec class name.
  String get className => json['className'] as String;

  /// JSON Schema of one entity map a query handler returns.
  Map<String, Object?> get schema =>
      (json['schema'] as Map).cast<String, Object?>();

  @override
  String toString() => 'DeclaredEntity($identifier)';
}

/// One `@EnumSpec` from the manifest.
class DeclaredEnum {
  DeclaredEnum._(this.json);

  /// The raw manifest entry.
  final Map<String, Object?> json;

  /// `@EnumSpec.identifier`.
  String get identifier => json['identifier'] as String;

  /// The case names, which are also the wire values.
  List<String> get cases => (json['cases'] as List).cast<String>();
}
