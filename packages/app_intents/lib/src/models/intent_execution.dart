import 'dart:async';

/// Why and which execution the system cancelled (#130).
///
/// [reason] is the Swift `IntentCancellationReason` rendered as a string; it is
/// informational — the system does not promise a fixed vocabulary, and new
/// reasons can appear in a future OS.
class IntentCancellation {
  /// Creates a cancellation notice.
  const IntentCancellation({required this.executionId, required this.reason});

  /// The execution the system cancelled.
  final String executionId;

  /// The system's reason, as a string.
  final String reason;

  @override
  String toString() =>
      'IntentCancellation(executionId: $executionId, reason: $reason)';
}

/// The running intent execution a handler is currently inside (#130, #131).
///
/// Obtained from [AppIntentExecution.current] rather than passed as an
/// argument: the generated handler signature is derived from the intent's own
/// parameters, and threading a context object through it would change every
/// existing handler. The plugin installs this in a [Zone] around the handler
/// call, so `current` is correct even deep inside the handler's own async
/// call tree.
///
/// ```dart
/// Future<void> exportTasksHandler({required String format}) async {
///   final execution = AppIntentExecution.current;
///   for (var i = 0; i < tasks.length; i++) {
///     if (execution?.isCancelled ?? false) return;   // stop cleanly
///     await exportOne(tasks[i]);
///     await execution?.reportProgress((i + 1) / tasks.length);
///   }
/// }
/// ```
///
/// `current` is null when the intent did not open an execution scope — which
/// is every intent that is neither `longRunning`/`cancellable` nor declares a
/// `requestValue` parameter. Handlers should treat it as optional.
class AppIntentExecution {
  /// Creates an execution context. The plugin constructs these; the closures
  /// are how it reaches the platform channel without this model depending on
  /// it.
  AppIntentExecution({
    required this.executionId,
    required Future<void> Function(int completed, int total) reportUnits,
    required Future<Object?> Function(String parameter) requestParameterValue,
  }) : _reportUnits = reportUnits,
       _requestParameterValue = requestParameterValue;

  /// The zone key the plugin stores the active execution under.
  static const Object zoneKey = #appIntentsExecution;

  /// The execution the calling code is running inside, or null.
  static AppIntentExecution? get current =>
      Zone.current[zoneKey] as AppIntentExecution?;

  /// Identifies this `perform()` call on the native side.
  final String executionId;

  final Future<void> Function(int completed, int total) _reportUnits;
  final Future<Object?> Function(String parameter) _requestParameterValue;

  final Completer<IntentCancellation> _cancellation =
      Completer<IntentCancellation>();

  IntentCancellation? _cancelled;

  /// Whether the system has cancelled this execution.
  ///
  /// Poll this between units of work: cancellation is cooperative, and iOS
  /// gives a cancelled intent only a short grace period before suspending the
  /// process.
  bool get isCancelled => _cancelled != null;

  /// The cancellation notice, once the system has sent one.
  IntentCancellation? get cancellation => _cancelled;

  /// Completes when the system cancels this execution.
  ///
  /// Useful to race against your own work
  /// (`await Future.any([work, execution.cancelled])`). Never completes if the
  /// intent runs to completion, so do not `await` it on its own.
  Future<IntentCancellation> get cancelled => _cancellation.future;

  /// Reports progress as a fraction between 0 and 1.
  ///
  /// Scaled to a fixed 1000-unit total, so successive reports stay comparable
  /// even when the caller's own denominator changes mid-run.
  Future<void> reportProgress(double fraction) {
    final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return reportProgressUnits((clamped * 1000).round(), 1000);
  }

  /// Reports progress as explicit unit counts, feeding the intent's `Progress`.
  Future<void> reportProgressUnits(int completed, int total) =>
      _reportUnits(completed, total);

  /// Asks the system to prompt the user for [parameterName] (#131).
  ///
  /// Only parameters declared `@IntentParam(requestValue: true)` can be
  /// requested; anything else throws. Resolves when the user answers, so this
  /// can be outstanding for as long as the dialog is on screen.
  ///
  /// This exists for **optional** parameters: the system already prompts on its
  /// own for a missing non-optional one, which is why a request is the only way
  /// to ask for a value the caller legitimately omitted.
  Future<T?> requestValue<T>(String parameterName) async {
    final value = await _requestParameterValue(parameterName);
    return value as T?;
  }

  /// Marks the execution cancelled. Called by the plugin.
  void markCancelled(IntentCancellation notice) {
    if (_cancelled != null) return;
    _cancelled = notice;
    if (!_cancellation.isCompleted) _cancellation.complete(notice);
  }
}
