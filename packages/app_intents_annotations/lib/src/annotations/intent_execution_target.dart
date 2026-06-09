/// A target process an intent is allowed to execute in.
///
/// Maps to the WWDC26 `IntentExecutionTargets` option set (iOS 27+). When you
/// reuse intents between your app, a widget extension, or an App Intents
/// extension via a Swift package, the system may run the intent from any of
/// them. Use these values with `@IntentSpec(executionTargets: ...)` to restrict
/// execution to specific targets.
///
/// This is an **experimental WWDC26 feature**: the generated
/// `allowedExecutionTargets` is only emitted when experimental code generation
/// is enabled, and is wrapped in a `#if APP_INTENTS_WWDC26` compilation
/// condition so it compiles only against a beta SDK.
enum IntentExecutionTarget {
  /// The main app process. Generates `.main`.
  main,

  /// An App Intents extension process. Generates `.appIntentsExtension`.
  appIntentsExtension,

  /// A WidgetKit extension process. Generates `.widgetKitExtension`.
  widgetKitExtension,
}
