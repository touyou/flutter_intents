/// Annotation to specify an app intent.
class IntentSpec {
  /// A unique identifier for the intent.
  final String identifier;

  /// A human-readable title for the intent.
  final String title;

  /// An optional description of the intent.
  final String? description;

  /// The implementation language for the intent.
  final IntentImplementation implementation;

  const IntentSpec({
    required this.identifier,
    required this.title,
    this.description,
    this.implementation = IntentImplementation.dart,
  });
}

/// The implementation language for the intent.
enum IntentImplementation {
  /// Dart implementation.
  dart,

  /// Swift implementation.
  swift,
}
