import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

/// Tests for `@IntentParam(useValueState: true)` — distinguishing "unset" vs
/// "cleared" vs "set" on optional update-intent parameters via the iOS 18.2+
/// `IntentParameter.ValueState` projection.
///
/// SDK fact (spike against Xcode 27 beta `arm64e-apple-ios.swiftinterface`):
/// `IntentParameter.ValueState` is `@available(iOS 18.2, *)` **stable** — no
/// `#if APP_INTENTS_WWDC26` gating; the generated Swift uses a runtime
/// `if #available(iOS 18.2, *)` block instead so older OS versions still
/// compile and the state field is simply absent from the params dict.
IntentInfo _intent({List<IntentParamInfo> parameters = const []}) => IntentInfo(
  className: 'UpdateEventIntent',
  identifier: 'com.example.calendar.updateEvent',
  title: 'Update Event',
  implementation: IntentImplementationType.dart,
  parameters: parameters,
);

void main() {
  group('SwiftGenerator IntentParameter.ValueState (#52, iOS 18.2+)', () {
    test('emits valueState pre-serialization for opt-in optional param', () {
      final result = const SwiftGenerator().generateIntent(
        _intent(
          parameters: const [
            IntentParamInfo(
              fieldName: 'note',
              dartType: 'String?',
              title: 'Note',
              isOptional: true,
              useValueState: true,
            ),
          ],
        ),
      );

      // The local is declared as String? so it stays nil on iOS < 18.2.
      expect(result, contains('var noteState: String?'));
      expect(result, contains('if #available(iOS 18.2, *) {'));
      expect(result, contains(r'switch $note.valueState {'));
      expect(result, contains('case .unset:'));
      expect(result, contains('noteState = "unset"'));
      expect(result, contains('case .set(.some):'));
      expect(result, contains('noteState = "set"'));
      expect(result, contains('case .set(.none):'));
      expect(result, contains('noteState = "cleared"'));
      // Swift 6 / non-frozen enum: explicit @unknown default guards the switch.
      expect(result, contains('@unknown default:'));

      // FlutterBridge mode now builds the params dict imperatively when any
      // param opts into valueState, so the state sibling is added via an
      // `if let` guard (matching the cache-mode wire shape) rather than as a
      // mandatory `as Any`-cast nil entry.
      expect(result, contains('"note": note'));
      expect(result, contains('if let noteStateValue = noteState {'));
      expect(result, contains('params["noteState"] = noteStateValue'));
      expect(result, isNot(contains('noteState as Any')));
    });

    test('does NOT emit valueState for params without the opt-in', () {
      final result = const SwiftGenerator().generateIntent(
        _intent(
          parameters: const [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String?',
              title: 'Title',
              isOptional: true,
              // useValueState defaults to false
            ),
          ],
        ),
      );
      expect(result, isNot(contains('valueState')));
      expect(result, isNot(contains('titleState')));
      expect(result, isNot(contains('#available(iOS 18.2')));
    });

    test('mixes opt-in and plain params correctly', () {
      final result = const SwiftGenerator().generateIntent(
        _intent(
          parameters: const [
            IntentParamInfo(
              fieldName: 'eventId',
              dartType: 'String',
              title: 'Event ID',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'note',
              dartType: 'String?',
              title: 'Note',
              isOptional: true,
              useValueState: true,
            ),
          ],
        ),
      );
      // Both fields' values go into the imperatively-built dict; only `note`
      // has a state sibling, added via `if let` so iOS<18.2 keeps the key absent.
      expect(result, contains('"eventId": eventId'));
      expect(result, contains('"note": note'));
      expect(result, contains('if let noteStateValue = noteState {'));
      expect(result, contains('params["noteState"] = noteStateValue'));
      // No state local for eventId.
      expect(result, isNot(contains('eventIdState')));
    });

    test('emits state assignment in cache-mode perform too', () {
      // Cache-mode is selected by foreground supportedModes (no URL scheme).
      final result = const SwiftGenerator().generateIntent(
        IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.taskapp.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          supportedModes: IntentModeType.foreground,
          parameters: const [
            IntentParamInfo(
              fieldName: 'note',
              dartType: 'String?',
              title: 'Note',
              isOptional: true,
              useValueState: true,
            ),
          ],
        ),
      );
      // Cache-mode populates a `var params` dict conditionally.
      expect(result, contains('AppIntentsPlugin.setPendingAction('));
      expect(result, contains('var noteState: String?'));
      expect(result, contains('if let noteStateValue = noteState {'));
      expect(result, contains('params["noteState"] = noteStateValue'));
    });
  });
}
