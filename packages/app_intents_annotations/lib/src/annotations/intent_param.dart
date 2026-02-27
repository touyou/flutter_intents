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

  const IntentParam({
    required this.title,
    this.description,
    this.isOptional = false,
    this.entityType,
    this.enumType,
    this.fileType,
  });
}
