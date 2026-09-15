import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

SwiftGenerator _experimental() => const SwiftGenerator(
  experimental: ExperimentalFeatures(masterEnabled: true),
);

IntentInfo _intent({
  bool longRunning = false,
  bool cancellable = false,
  bool requestValue = false,
}) => IntentInfo(
  className: 'ExportTasksIntent',
  identifier: 'com.example.exportTasks',
  title: 'Export Tasks',
  implementation: IntentImplementationType.dart,
  longRunning: longRunning,
  cancellable: cancellable,
  parameters: [
    const IntentParamInfo(
      fieldName: 'format',
      dartType: 'String',
      title: 'Format',
      isOptional: false,
    ),
    if (requestValue)
      const IntentParamInfo(
        fieldName: 'note',
        dartType: 'String?',
        title: 'Note',
        isOptional: true,
        requestValue: true,
      ),
  ],
);

void main() {
  group('SwiftGenerator (#130 progress / cancellation)', () {
    test('a long-running intent opens an execution scope and feeds progress', () {
      final result = _experimental().generateIntent(
        _intent(longRunning: true, cancellable: true),
      );

      expect(result, contains('let executionId = UUID().uuidString'));
      expect(result, contains('await FlutterBridge.shared.beginExecution('));
      // Progress is a Foundation object, documented thread-safe but not
      // Sendable; the capture is stated as deliberate rather than left to warn.
      expect(
        result,
        contains('nonisolated(unsafe) let progressRef = progress'),
      );
      expect(result, contains('progressRef.completedUnitCount = completed'));
      expect(
        result,
        contains('defer { Task { await FlutterBridge.shared.endExecution('),
      );
      // The id travels to Dart in the params, which is how the handler names
      // the execution it reports progress for.
      expect(result, contains('"_executionId": executionId'));
      // Cancellation is forwarded instead of the old comment-only stub.
      expect(
        result,
        contains('await FlutterBridge.shared.reportCancellation('),
      );
      expect(result, contains('reason: String(describing: reason)'));
      expect(result, isNot(contains('Perform best-effort cleanup here')));
    });

    test('the stable #else branch opens no scope when nothing needs one', () {
      final result = _experimental().generateIntent(
        _intent(longRunning: true, cancellable: true),
      );
      final stableBranch = result.substring(result.indexOf('#else'));

      // Progress and cancellation only exist in the WWDC26 branch, so the
      // fallback deliberately has no execution id: the Dart handler then sees
      // no execution context and its `execution?.reportProgress(…)` is a no-op
      // instead of an error on a build that could never report progress.
      expect(stableBranch, isNot(contains('beginExecution')));
      expect(stableBranch, isNot(contains('_executionId')));
    });

    test('a plain intent has no execution scope at all', () {
      final result = _experimental().generateIntent(_intent());
      expect(result, isNot(contains('beginExecution')));
      expect(result, isNot(contains('_executionId')));
    });
  });

  group('SwiftGenerator (#131 requestValue)', () {
    test('a requestable parameter registers a requester in both branches', () {
      final result = _experimental().generateIntent(
        _intent(longRunning: true, cancellable: true, requestValue: true),
      );

      expect(result, contains('valueRequester: { [self] parameter in'));
      expect(result, contains('case "note":'));
      expect(result, contains(r'return try await $note.requestValue()'));

      // requestValue is iOS 16 — nothing about it is experimental, so the
      // stable fallback must offer it too.
      final stableBranch = result.substring(result.indexOf('#else'));
      expect(stableBranch, contains('valueRequester:'));
      expect(stableBranch, contains('"_executionId": executionId'));
      // ...but still no progress, which does not exist there.
      expect(stableBranch, isNot(contains('progressRef')));
    });

    test('a DateTime request is converted to an ISO-8601 string', () {
      final result = _experimental().generateIntent(
        IntentInfo(
          className: 'ScheduleIntent',
          identifier: 'com.example.schedule',
          title: 'Schedule',
          implementation: IntentImplementationType.dart,
          parameters: const [
            IntentParamInfo(
              fieldName: 'due',
              dartType: 'DateTime?',
              title: 'Due',
              isOptional: true,
              requestValue: true,
            ),
          ],
        ),
      );

      // A Date cannot cross the MethodChannel; the same ISO-8601 shape the
      // params use is applied to the answer.
      expect(
        result,
        contains(
          r'return ISO8601DateFormatter().string(from: try await $due.requestValue())',
        ),
      );
    });

    test('a requestable parameter works without any experimental feature', () {
      final result = const SwiftGenerator().generateIntent(
        _intent(requestValue: true),
      );
      expect(result, contains('beginExecution('));
      expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
    });
  });
}
