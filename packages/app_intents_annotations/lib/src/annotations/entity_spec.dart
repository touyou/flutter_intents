/// Annotation to specify an entity with its metadata.
class EntitySpec {
  /// A unique identifier for the entity.
  final String identifier;

  /// A human-readable title for the entity.
  final String title;

  /// A human-readable plural title for the entity.
  final String pluralTitle;

  /// An optional description of the entity.
  final String? description;

  /// Optional asset image name for entity display representation.
  ///
  /// Generates `DisplayRepresentation` with
  /// `.init(named: displayImageName, isTemplate: true)` image.
  final String? displayImageName;

  /// Whether to generate `IndexedEntity` conformance for Spotlight search.
  ///
  /// Generates `@available(iOS 26.0, *)` extension with `CSSearchableItemAttributeSet`.
  final bool indexed;

  /// Whether to generate `EnumerableEntityQuery` conformance.
  ///
  /// Generates an extension with `allEntities()` that delegates to `suggestedEntities()`.
  final bool enumerable;

  const EntitySpec({
    required this.identifier,
    required this.title,
    required this.pluralTitle,
    this.description,
    this.displayImageName,
    this.indexed = false,
    this.enumerable = false,
  });
}
