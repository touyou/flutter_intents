/// Annotation that declares a WidgetKit `WidgetConfigurationIntent` (iOS 17+).
///
/// A widget configuration intent is what powers "long-press → Edit Widget" on
/// the Home Screen: each widget instance gets its own configuration, chosen
/// from a picker that iOS renders from the intent's parameters.
///
/// ## Why this is generated separately
/// A Widget Extension cannot start a Flutter engine, so the usual
/// `FlutterBridge` round-trip to a Dart `EntityQuery` handler is unavailable
/// there. The generated code therefore reads the **App Group persisted entity
/// cache** synchronously instead — the same cache the cold-start fallback uses
/// (see `@EntitySpec(persistedCacheKey:)`).
///
/// For the same reason the output goes to its own file, produced by a separate
/// command:
///
/// ```bash
/// dart run app_intents_codegen:generate_widget_swift \
///   -o ios/MyWidget/GeneratedIntents \
///   --app-group group.com.example.app \
///   --storage-identifier com.example.app
/// ```
///
/// The generated file must be added **only** to the Widget Extension target.
/// Compiling the same App Intent type into both the app target and the
/// extension target duplicates it in `Metadata.appIntents`, and iOS then fails
/// to resolve the intent at runtime.
///
/// ## Example
/// ```dart
/// @WidgetConfigurationSpec(
///   identifier: 'com.example.selectTeam',
///   title: 'Displayed team',
///   description: 'Choose which team this widget shows.',
/// )
/// class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {
///   @WidgetParameter(title: 'Team')
///   final TeamEntitySpec? team;
///
///   const SelectTeamWidgetConfig({this.team});
/// }
/// ```
class WidgetConfigurationSpec {
  /// A unique identifier for the configuration intent.
  ///
  /// Used for the generated `persistentIdentifier`, so it must stay stable —
  /// changing it invalidates existing widget configurations.
  final String identifier;

  /// A human-readable title, shown as the heading of the widget's edit sheet.
  final String title;

  /// An optional description shown in the edit sheet.
  final String? description;

  /// Whether the intent shows up as an action in the Shortcuts app.
  ///
  /// Defaults to `false`: a configuration intent exists to configure a widget,
  /// and surfacing it as a standalone Shortcuts action is almost always noise.
  /// Set to `true` only if the intent is genuinely useful on its own.
  final bool isDiscoverable;

  /// Whether the generated entity queries implement `defaultResult()`.
  ///
  /// Defaults to `false`, and that default is deliberate. `defaultResult()`
  /// pre-fills an unedited widget instance with a concrete value captured **at
  /// the moment the widget was added**. That is incompatible with the common
  /// "unconfigured widgets follow the app's global setting" fallback: once the
  /// value is baked in, changing the in-app setting no longer moves those
  /// widgets.
  ///
  /// Enable it only when a snapshot-at-add-time default is what you want. When
  /// `false`, an unconfigured parameter arrives as `nil` and the widget's
  /// timeline provider decides what to fall back to.
  final bool generateDefaultResult;

  const WidgetConfigurationSpec({
    required this.identifier,
    required this.title,
    this.description,
    this.isDiscoverable = false,
    this.generateDefaultResult = false,
  });
}

/// Annotation to describe a parameter of a [WidgetConfigurationSpec].
///
/// The field's Dart type decides what is generated:
///
/// - A type annotated with `@EntitySpec` (e.g. `TeamEntitySpec?`) generates a
///   cache-backed `AppEntity` + `EnumerableEntityQuery` pair for the Widget
///   Extension target, and an entity picker in the widget's edit sheet.
/// - `String`, `int`, `double`, `bool` generate a plain `@Parameter`.
///
/// Prefer optional (`?`) entity fields: a non-optional entity parameter forces
/// iOS to demand a value before the widget can render.
class WidgetParameter {
  /// A human-readable title for the parameter.
  final String title;

  /// An optional description shown under the parameter in the edit sheet.
  final String? description;

  /// The entity type for this parameter (e.g. `'TeamEntitySpec'`).
  ///
  /// Only needed when the field's declared type does not resolve to an
  /// `@EntitySpec` class — for example when the field is declared as `String?`
  /// but should present an entity picker.
  final String? entityType;

  const WidgetParameter({
    required this.title,
    this.description,
    this.entityType,
  });
}
