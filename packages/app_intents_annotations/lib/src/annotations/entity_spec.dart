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

  const EntitySpec({
    required this.identifier,
    required this.title,
    required this.pluralTitle,
    this.description,
  });
}
