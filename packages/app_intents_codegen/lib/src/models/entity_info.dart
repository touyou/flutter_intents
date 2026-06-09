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

  /// Experimental (WWDC26): the App Schema this entity conforms to, as a dotted
  /// `domain.schema` path (e.g. `messages.message`). When set and the
  /// `app-schema` experimental feature is enabled, the generated Swift adds the
  /// `@AppEntity(schema:)` macro (dual-branch).
  final String? schema;

  /// Experimental (WWDC26 #55): the entity's ownership state. When set and the
  /// `ownership` feature is enabled, adds an `OwnershipProvidingEntity`
  /// conformance.
  final EntityOwnershipType? ownership;

  /// Experimental (WWDC26 #51): whether to generate an `IntentValueQuery`
  /// conforming type for this entity. When true and the `value-query` feature
  /// is enabled, the Swift output adds a `<Entity>ValueQuery` struct
  /// (`#if`-gated) delegating to a Dart value-query handler.
  final bool valueQuery;

  /// Experimental (WWDC26 #54): the system structured type this entity is
  /// exported as. When set and the `value-representation` feature is enabled,
  /// the Swift output adds a `Transferable` conformance with
  /// `ValueRepresentation(exporting:)` (`#if`-gated).
  final EntityExportKind? exportAs;

  /// Experimental (WWDC26 #55): whether the entity's id is stable across
  /// devices. When true and the `donation` feature is enabled, the Swift output
  /// adds a `SyncableEntity` conformance (`#if`-gated, additive). Only the
  /// already-stable-id case; the dual-id `SyncableEntityIdentifier` case is not
  /// handled here.
  final bool syncable;

  /// Experimental (WWDC26 #55): whether to generate a `RelevantEntities`
  /// donator registration for this entity. When true and the `donation`
  /// feature is enabled, the Swift output adds a
  /// `register<Entity>RelevantEntitiesDonator()` function (`#if`-gated).
  final bool relevantEntities;

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
    this.schema,
    this.ownership,
    this.valueQuery = false,
    this.exportAs,
    this.syncable = false,
    this.relevantEntities = false,
  });

  /// Whether any property is exposed as a Swift `@Property`. Such entities need
  /// an explicit initializer (the `@Property` wrapper has no `init(wrappedValue:)`).
  bool get hasExposedProperties => properties.any((p) => p.exposeAsProperty);

  /// Whether any exposed property uses semantic `indexingKey` (iOS 18.4+).
  bool get hasIndexingKeys =>
      properties.any((p) => p.exposeAsProperty && p.indexingKey != null);

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
        schema == other.schema &&
        ownership == other.ownership &&
        valueQuery == other.valueQuery &&
        exportAs == other.exportAs &&
        syncable == other.syncable &&
        relevantEntities == other.relevantEntities &&
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
    schema,
    ownership,
    valueQuery,
    exportAs,
    syncable,
    relevantEntities,
    Object.hashAll(properties),
  );

  @override
  String toString() =>
      'EntityInfo(className: $className, identifier: $identifier, title: $title, '
      'pluralTitle: $pluralTitle, description: $description, modelType: $modelType, '
      'displayImageName: $displayImageName, indexed: $indexed, enumerable: $enumerable, '
      'persistedCacheKey: $persistedCacheKey, schema: $schema, ownership: $ownership, '
      'valueQuery: $valueQuery, exportAs: $exportAs, syncable: $syncable, '
      'relevantEntities: $relevantEntities, properties: $properties)';
}

/// Represents analyzed information about an entity property.
class EntityPropertyInfo {
  /// The field name of the property.
  final String fieldName;

  /// The Dart type of the property.
  final String dartType;

  /// The role of this property in the entity.
  final EntityPropertyRole role;

  /// Experimental (WWDC26 / #50): whether to emit this field as a Swift
  /// `@Property(...)` exposed to the system (Spotlight / Apple Intelligence).
  final bool exposeAsProperty;

  /// The `@Property(title:)` value, when [exposeAsProperty] is true.
  final String? propertyTitle;

  /// The `CSSearchableItemAttributeSet` key path name (without leading `\.`) for
  /// `@Property(indexingKey:)` semantic indexing (iOS 18.4+).
  final String? indexingKey;

  const EntityPropertyInfo({
    required this.fieldName,
    required this.dartType,
    required this.role,
    this.exposeAsProperty = false,
    this.propertyTitle,
    this.indexingKey,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EntityPropertyInfo) return false;
    return fieldName == other.fieldName &&
        dartType == other.dartType &&
        role == other.role &&
        exposeAsProperty == other.exposeAsProperty &&
        propertyTitle == other.propertyTitle &&
        indexingKey == other.indexingKey;
  }

  @override
  int get hashCode => Object.hash(
    fieldName,
    dartType,
    role,
    exposeAsProperty,
    propertyTitle,
    indexingKey,
  );

  @override
  String toString() =>
      'EntityPropertyInfo(fieldName: $fieldName, dartType: $dartType, role: $role, '
      'exposeAsProperty: $exposeAsProperty, propertyTitle: $propertyTitle, '
      'indexingKey: $indexingKey)';
}

/// Experimental (WWDC26 #55): the ownership state of an entity, mapped to a
/// member of the Swift `EntityOwnership` option set.
enum EntityOwnershipType { unknown, shared, public }

/// Experimental (WWDC26 #54): the system structured type an entity is exported
/// as via `ValueRepresentation`. Mirrors `EntityExportType` in annotations.
enum EntityExportKind { person }

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
