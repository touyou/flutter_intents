import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

/// A generator with every WWDC26 experimental feature enabled.
SwiftGenerator _experimentalGenerator() => const SwiftGenerator(
  experimental: ExperimentalFeatures(masterEnabled: true),
);

IntentInfo _intent({
  bool longRunning = false,
  bool cancellable = false,
  List<IntentExecutionTargetType>? executionTargets,
  List<IntentParamInfo> parameters = const [],
}) {
  return IntentInfo(
    className: 'UploadPhotoIntent',
    identifier: 'com.example.uploadPhoto',
    title: 'Upload Photo',
    implementation: IntentImplementationType.dart,
    parameters: parameters,
    longRunning: longRunning,
    cancellable: cancellable,
    executionTargets: executionTargets,
  );
}

void main() {
  group('SwiftGenerator (WWDC26 experimental execution control)', () {
    group('opt-in gating', () {
      test('default generator emits no experimental code', () {
        final stable = const SwiftGenerator();
        final result = stable.generateAll(
          intents: [_intent(longRunning: true)],
        );

        expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
        expect(result, isNot(contains('LongRunningIntent')));
        expect(result, isNot(contains('performBackgroundTask')));
        expect(result, contains('struct UploadPhotoIntent: AppIntent {'));
      });

      test('master on but feature not selected emits no experimental code', () {
        final generator = const SwiftGenerator(
          experimental: ExperimentalFeatures(
            masterEnabled: true,
            enabled: {ExperimentalFeature.appSchema},
          ),
        );
        final result = generator.generateAll(
          intents: [_intent(longRunning: true)],
        );

        expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
        expect(result, isNot(contains('LongRunningIntent')));
      });
    });

    group('dual-branch emission', () {
      test('long-running intent wraps both branches in #if/#else/#endif', () {
        final result = _experimentalGenerator().generateAll(
          intents: [_intent(longRunning: true)],
        );

        // Compilation guard so released-SDK builds fall back to the stable form.
        expect(result, contains('#if APP_INTENTS_WWDC26'));
        expect(result, contains('#else'));
        expect(result, contains('#endif'));

        // Experimental branch: iOS 27, LongRunningIntent, performBackgroundTask.
        expect(result, contains('@available(iOS 27.0, *)'));
        expect(
          result,
          contains('struct UploadPhotoIntent: AppIntent, LongRunningIntent {'),
        );
        expect(result, contains('try await performBackgroundTask {'));
        expect(result, contains('FlutterBridge.shared.invoke('));

        // Stable branch: plain AppIntent at iOS 17, no LongRunningIntent.
        expect(result, contains('@available(iOS 17.0, *)'));
        expect(result, contains('struct UploadPhotoIntent: AppIntent {'));

        // The #else branch must not re-declare the experimental conformance.
        final elseIndex = result.indexOf('#else');
        final endifIndex = result.indexOf('#endif');
        final elseBranch = result.substring(elseIndex, endifIndex);
        expect(elseBranch, isNot(contains('LongRunningIntent')));
        expect(elseBranch, isNot(contains('performBackgroundTask')));
      });
    });

    group('cancellable', () {
      test('cancellable-only intent uses withIntentCancellationHandler', () {
        final result = _experimentalGenerator().generateAll(
          intents: [_intent(cancellable: true)],
        );

        // CancellableIntent alone is available from iOS 26.4.
        expect(result, contains('@available(iOS 26.4, *)'));
        expect(
          result,
          contains('struct UploadPhotoIntent: AppIntent, CancellableIntent {'),
        );
        expect(result, contains('try await withIntentCancellationHandler {'));
        expect(result, contains('} onCancel: { reason in'));
        expect(result, isNot(contains('performBackgroundTask')));
      });

      test('long-running + cancellable uses combined performBackgroundTask', () {
        final result = _experimentalGenerator().generateAll(
          intents: [_intent(longRunning: true, cancellable: true)],
        );

        expect(result, contains('@available(iOS 27.0, *)'));
        expect(
          result,
          contains(
            'struct UploadPhotoIntent: AppIntent, LongRunningIntent, CancellableIntent {',
          ),
        );
        expect(result, contains('try await performBackgroundTask {'));
        expect(result, contains('} onCancel: { reason in'));
        expect(result, isNot(contains('withIntentCancellationHandler')));
      });
    });

    group('executionTargets', () {
      test('emits allowedExecutionTargets with mapped members', () {
        final result = _experimentalGenerator().generateAll(
          intents: [
            _intent(
              longRunning: true,
              executionTargets: const [
                IntentExecutionTargetType.main,
                IntentExecutionTargetType.widgetKitExtension,
              ],
            ),
          ],
        );

        expect(
          result,
          contains(
            'static var allowedExecutionTargets: IntentExecutionTargets { [.main, .widgetKitExtension] }',
          ),
        );
      });

      test(
        'executionTargets-only intent keeps the standard background perform()',
        () {
          final result = _experimentalGenerator().generateAll(
            intents: [
              _intent(
                executionTargets: const [
                  IntentExecutionTargetType.appIntentsExtension,
                ],
              ),
            ],
          );

          // Still experimental (iOS 27 for IntentExecutionTargets) and guarded.
          expect(result, contains('#if APP_INTENTS_WWDC26'));
          expect(result, contains('@available(iOS 27.0, *)'));
          expect(
            result,
            contains(
              'static var allowedExecutionTargets: IntentExecutionTargets { [.appIntentsExtension] }',
            ),
          );
          // No wrapping when neither long-running nor cancellable.
          expect(result, isNot(contains('performBackgroundTask')));
          expect(result, isNot(contains('withIntentCancellationHandler')));
          expect(result, contains('FlutterBridge.shared.invoke('));
        },
      );
    });
  });
}
