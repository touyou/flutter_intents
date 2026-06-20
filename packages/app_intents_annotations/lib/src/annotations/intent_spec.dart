import 'intent_execution_target.dart';
import 'intent_mode.dart';

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

  /// The execution mode for the intent.
  ///
  /// Controls whether the app opens in the foreground when the intent runs.
  /// - [IntentMode.foreground]: Generates `supportedModes: .foreground` (iOS 26+)
  ///   and `openAppWhenRun = true` (iOS < 26) for backward compatibility.
  /// - [IntentMode.background]: Default behavior, no explicit properties generated.
  ///
  /// When [urlScheme] is set, foreground mode is implied automatically.
  final IntentMode? supportedModes;

  /// **Experimental (WWDC26, iOS 27+).** Marks the intent as long-running so it
  /// can exceed the standard 30-second background limit.
  ///
  /// When experimental code generation is enabled, the generated Swift conforms
  /// to `LongRunningIntent` and wraps the work in `performBackgroundTask(...)`.
  /// Long-running intents must run in the background (no [urlScheme], no
  /// [IntentMode.foreground]). Has no effect unless experimental generation is
  /// enabled.
  final bool longRunning;

  /// **Experimental (WWDC26, iOS 26.4+).** Marks the intent as cancellable so it
  /// can respond to graceful cancellation.
  ///
  /// When experimental code generation is enabled, the generated Swift conforms
  /// to `CancellableIntent` and wraps the work in a cancellation handler that
  /// receives an `IntentCancellationReason`. Cancellable intents must run in the
  /// background. Has no effect unless experimental generation is enabled.
  final bool cancellable;

  /// **Experimental (WWDC26, iOS 27+).** Restricts which processes may run this
  /// intent.
  ///
  /// When experimental code generation is enabled, the generated Swift emits
  /// `static var allowedExecutionTargets: IntentExecutionTargets`. Has no effect
  /// unless experimental generation is enabled.
  final List<IntentExecutionTarget>? executionTargets;

  /// **Experimental (WWDC26, iOS 27+).** The App Schema this intent conforms to,
  /// as a dotted `domain.schema` path (e.g. `'messages.setMessageReadStatus'`).
  ///
  /// When experimental code generation is enabled, the generated Swift adds the
  /// `@AppIntent(schema: .messages.setMessageReadStatus)` macro. Emitted in a
  /// `#if APP_INTENTS_WWDC26` block with a stable `AppIntent`-only fallback. Has
  /// no effect unless experimental generation is enabled.
  final String? schema;

  /// **Experimental (WWDC26).** Marks this intent as donatable so Siri / Apple
  /// Intelligence can learn that the user performed the action in-app (not just
  /// via Siri).
  ///
  /// `AppIntent.donate()` is a stable iOS 16+ API. We gate the generated
  /// `register<Intent>Donator()` reverse executor behind the `donation`
  /// experimental feature for consistency with the rest of #55 — the call site
  /// is additive (no `#else`), so released-SDK builds without the flag just
  /// don't emit the donator.
  ///
  /// The Dart side calls `AppIntents().donateIntent(identifier, params)`; the
  /// plugin forwards via `AppIntentsPlugin.intentDonationForwarder` to
  /// `FlutterBridge.shared.donateIntent`, which invokes the generated closure
  /// that reconstructs the concrete intent from `params` and calls
  /// `intent.donate()`.
  ///
  /// **MVP restriction**: only intents whose parameters are all primitive
  /// (`String`/`int`/`double`/`bool`/`DateTime`, with optionals allowed) can be
  /// marked donatable. Entity/file/enum/union/collection params are rejected at
  /// codegen time; they need richer reconstruction logic that's deferred to a
  /// follow-up issue. See `docs/adr/0003-donations-and-discovery.md`.
  final bool donatable;

  const IntentSpec({
    required this.identifier,
    required this.title,
    this.description,
    this.implementation = IntentImplementation.dart,
    this.urlScheme,
    this.urlAction,
    this.resultDialogTemplate,
    this.parameterSummary,
    this.supportedModes,
    this.longRunning = false,
    this.cancellable = false,
    this.executionTargets,
    this.schema,
    this.donatable = false,
  });
}

/// The implementation language for the intent.
enum IntentImplementation {
  /// Dart implementation (logic runs in Flutter).
  dart,

  /// Swift implementation (iOS native).
  swift,

  /// Kotlin implementation (Android native).
  kotlin,
}
