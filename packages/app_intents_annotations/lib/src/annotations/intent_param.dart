/// Annotation to describe a parameter of an app intent.
class IntentParam {
  /// A human-readable title for the parameter.
  final String title;

  /// An optional description of the parameter.
  final String? description;

  /// Whether the parameter is optional.
  final bool isOptional;

  /// The entity type for this parameter (e.g., 'TaskEntitySpec').
  ///
  /// When set, the generated Swift parameter uses the specified AppEntity type
  /// instead of a primitive type, enabling entity picker UI in Shortcuts/Siri.
  /// The entity's `.id` property is used for URL scheme parameters.
  final String? entityType;

  /// The enum type for this parameter (e.g., 'Priority').
  ///
  /// When set, the generated Swift parameter uses the specified AppEnum type.
  /// The enum's `.rawValue` is used for URL scheme parameters.
  final String? enumType;

  /// The UTType identifier for file parameters (e.g., 'public.image').
  ///
  /// When set, the generated Swift parameter uses `IntentFile` type with
  /// `supportedTypeIdentifiers` for the `@Parameter` attribute.
  /// The Dart parameter type should be `IntentFile` or `IntentFile?`.
  final String? fileType;

  /// The element entity type for an entity-collection parameter (#53,
  /// e.g. 'PhotoEntity').
  ///
  /// When set, the generated Swift parameter uses the WWDC26
  /// `EntityCollection<Entity>` type (iOS 27, behind the `rich-types`
  /// experimental feature) or a `[Entity]` array fallback. Either way the Dart
  /// handler receives the entity identifiers as a `List<String>`, so the Dart
  /// parameter type should be `List<String>`.
  final String? entityCollectionType;

  const IntentParam({
    required this.title,
    this.description,
    this.isOptional = false,
    this.entityType,
    this.enumType,
    this.fileType,
    this.entityCollectionType,
  });
}
