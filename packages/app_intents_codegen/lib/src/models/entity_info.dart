/// Represents analyzed information about an entity specification.
class EntityInfo {
  /// The class name of the entity specification.
  final String className;

  /// The unique identifier for the entity.
  final String identifier;

  /// The human-readable title for the entity.
  final String title;

  /// The human-readable plural title for the entity.
  final String pluralTitle;

  /// An optional description of the entity.
  final String? description;

  /// The model type parameter of the entity.
  final String? modelType;

  /// The properties of the entity.
  final List<EntityPropertyInfo> properties;

  /// Optional asset image name for entity display representation.
  final String? displayImageName;

  /// Whether to generate IndexedEntity conformance for Spotlight.
  final bool indexed;

  /// Whether to generate EnumerableEntityQuery conformance.
  final bool enumerable;

  /// Optional App Group UserDefaults key for the persisted entity list.
  ///
  /// When non-null, the generated EntityQuery reads cached entities from this
  /// key before waiting on the Flutter executor (cold-start fallback). When
  /// null but [enumerable] or [indexed] is true, a default key
  /// `app_intents.entities.<identifier>` is used.
  final String? persistedCacheKey;

  const EntityInfo({
    required this.className,
    required this.identifier,
    required this.title,
    required this.pluralTitle,
    this.description,
    this.modelType,
    required this.properties,
    this.displayImageName,
    this.indexed = false,
    this.enumerable = false,
    this.persistedCacheKey,
  });

  /// Returns the effective cache key to use for App Group fallback, or null
  /// when no fallback should be generated.
  ///
  /// - Returns [persistedCacheKey] verbatim when explicitly set.
  /// - Returns `app_intents.entities.<identifier>` when [enumerable] or
  ///   [indexed] is true (auto-fallback for long-lived entities).
  /// - Returns null otherwise.
  String? get effectiveCacheKey {
    if (persistedCacheKey != null) return persistedCacheKey;
    if (enumerable || indexed) return 'app_intents.entities.$identifier';
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EntityInfo) return false;
    return className == other.className &&
        identifier == other.identifier &&
        title == other.title &&
        pluralTitle == other.pluralTitle &&
        description == other.description &&
        modelType == other.modelType &&
        displayImageName == other.displayImageName &&
        indexed == other.indexed &&
        enumerable == other.enumerable &&
        persistedCacheKey == other.persistedCacheKey &&
        _listEquals(properties, other.properties);
  }

  @override
  int get hashCode => Object.hash(
    className,
    identifier,
    title,
    pluralTitle,
    description,
    modelType,
    displayImageName,
    indexed,
    enumerable,
    persistedCacheKey,
    Object.hashAll(properties),
  );

  @override
  String toString() =>
      'EntityInfo(className: $className, identifier: $identifier, title: $title, '
      'pluralTitle: $pluralTitle, description: $description, modelType: $modelType, '
      'displayImageName: $displayImageName, indexed: $indexed, enumerable: $enumerable, '
      'persistedCacheKey: $persistedCacheKey, properties: $properties)';
}

/// Represents analyzed information about an entity property.
class EntityPropertyInfo {
  /// The field name of the property.
  final String fieldName;

  /// The Dart type of the property.
  final String dartType;

  /// The role of this property in the entity.
  final EntityPropertyRole role;

  const EntityPropertyInfo({
    required this.fieldName,
    required this.dartType,
    required this.role,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EntityPropertyInfo) return false;
    return fieldName == other.fieldName &&
        dartType == other.dartType &&
        role == other.role;
  }

  @override
  int get hashCode => Object.hash(fieldName, dartType, role);

  @override
  String toString() =>
      'EntityPropertyInfo(fieldName: $fieldName, dartType: $dartType, role: $role)';
}

/// The role of an entity property.
enum EntityPropertyRole {
  /// The unique identifier property.
  id,

  /// The display title property.
  title,

  /// The display subtitle property.
  subtitle,

  /// The image property.
  image,

  /// The default query property.
  defaultQuery,

  /// A regular property with no special role.
  none,
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
