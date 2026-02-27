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

  const IntentParam({
    required this.title,
    this.description,
    this.isOptional = false,
    this.entityType,
  });
}
