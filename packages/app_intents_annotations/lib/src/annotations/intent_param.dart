/// Annotation to describe a parameter of an app intent.
class IntentParam {
  /// A human-readable title for the parameter.
  final String title;

  /// An optional description of the parameter.
  final String? description;

  /// Whether the parameter is optional.
  final bool isOptional;

  const IntentParam({
    required this.title,
    this.description,
    this.isOptional = false,
  });
}
