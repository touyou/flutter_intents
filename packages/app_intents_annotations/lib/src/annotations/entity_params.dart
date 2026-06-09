/// Annotations for marking entity parameters in intent specifications.
class EntityId {
  const EntityId();
}

/// Annotations for marking entity parameters in intent specifications.
class EntityTitle {
  const EntityTitle();
}

/// Annotations for marking entity parameters in intent specifications.
class EntitySubtitle {
  const EntitySubtitle();
}

/// Annotations for marking entity parameters in intent specifications.
class EntityImage {
  const EntityImage();
}

/// Annotations for marking entity parameters in intent specifications.
class EntityDefaultQuery {
  const EntityDefaultQuery();
}

/// Marks an entity field to be exposed to the system as a Swift `@Property`.
///
/// Use this for semantic properties beyond the id/title/subtitle/image roles —
/// for example a message body or note that Spotlight and Apple Intelligence
/// should be able to search.
///
/// - [title]: optional human-readable title (`@Property(title: "Body")`).
/// - [indexingKey]: a `CSSearchableItemAttributeSet` key path name (without the
///   leading `\.`), e.g. `'contentDescription'`. When set, generates
///   `@Property(indexingKey: \.contentDescription)` for semantic indexing
///   (iOS 18.4+). The generated entity gets an explicit initializer because the
///   `@Property` wrapper has no `init(wrappedValue:)`.
class EntityProperty {
  /// An optional human-readable title for the property.
  final String? title;

  /// A `CSSearchableItemAttributeSet` key path name for semantic indexing.
  final String? indexingKey;

  const EntityProperty({this.title, this.indexingKey});
}
