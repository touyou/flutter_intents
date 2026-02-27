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

  /// The URL scheme for intent execution (e.g., 'taskapp').
  ///
  /// When set, the generated Swift `perform()` method opens a URL
  /// (e.g., `taskapp://create?title=Hello`) instead of calling FlutterBridge.
  /// The Flutter app receives it via the `app_links` package.
  /// This avoids Flutter engine timing issues with Shortcuts/Siri.
  final String? urlScheme;

  /// The action segment in the URL (e.g., 'create' for 'taskapp://create?...').
  ///
  /// If null and [urlScheme] is set, the last segment of [identifier] is used.
  /// For example, identifier 'com.example.taskapp.createTask' becomes 'createTask'.
  final String? urlAction;

  /// Template for the dialog shown after intent execution.
  ///
  /// Supports `{paramName}` interpolation for parameter values.
  /// When set, `perform()` returns `some IntentResult & ProvidesDialog`.
  /// Example: `'Created task "{title}"'`
  final String? resultDialogTemplate;

  /// Template for the parameter summary shown in Shortcuts UI.
  ///
  /// Supports `{paramName}` references to parameters.
  /// Example: `'Create "{title}"'` generates `Summary("Create \(\.$title)")`
  final String? parameterSummary;

  const IntentSpec({
    required this.identifier,
    required this.title,
    this.description,
    this.implementation = IntentImplementation.dart,
    this.urlScheme,
    this.urlAction,
    this.resultDialogTemplate,
    this.parameterSummary,
  });
}

/// The implementation language for the intent.
enum IntentImplementation {
  /// Dart implementation.
  dart,

  /// Swift implementation.
  swift,
}
