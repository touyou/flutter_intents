/// Defines the execution mode for an App Intent.
///
/// Maps to iOS 26+ `IntentModes` (`supportedModes` property).
/// For iOS < 26, the equivalent `openAppWhenRun` property is also generated.
enum IntentMode {
  /// The intent runs in the background without opening the app (default).
  background,

  /// The app opens in the foreground when the intent runs.
  foreground,
}
