/// Annotation to define an AppEnum for use in App Intents.
///
/// Apply to a Dart enum to generate a Swift `AppEnum` conforming type.
///
/// ```dart
/// @EnumSpec(identifier: 'com.example.Priority', title: 'Priority')
/// enum Priority {
///   @EnumCaseDisplay(title: 'High')
///   high,
///   @EnumCaseDisplay(title: 'Medium')
///   medium,
///   @EnumCaseDisplay(title: 'Low')
///   low,
/// }
/// ```
class EnumSpec {
  /// A unique identifier for the enum.
  final String identifier;

  /// A human-readable title for the enum type.
  final String title;

  /// **Experimental (WWDC26, iOS 27+).** The App Schema this enum conforms to,
  /// as a dotted `domain.schema` path (e.g. `'messages.messageType'`).
  ///
  /// When experimental code generation is enabled (the `app-schema` feature),
  /// the generated Swift adds the `@AppEnum(schema: .messages.messageType)`
  /// macro, in a `#if APP_INTENTS_WWDC26` block with a stable fallback. Has no
  /// effect unless experimental generation is enabled.
  final String? schema;

  const EnumSpec({required this.identifier, required this.title, this.schema});
}

/// Annotation to customize the display title of an enum case.
///
/// If not provided, the enum value name with first letter capitalized is used.
class EnumCaseDisplay {
  /// The display title for this enum case.
  final String title;

  /// Optional asset image name for this enum case.
  ///
  /// When set, generates `DisplayRepresentation` with
  /// `.init(named: imageName, isTemplate: true)` image.
  final String? imageName;

  const EnumCaseDisplay({required this.title, this.imageName});
}
