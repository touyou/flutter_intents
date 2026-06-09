import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

/// A generator with every WWDC26 experimental feature enabled.
SwiftGenerator _experimentalGenerator() =>
    const SwiftGenerator(experimental: ExperimentalFeatures(masterEnabled: true));

IntentInfo _intent({List<IntentParamInfo> parameters = const []}) => IntentInfo(
  className: 'StartTimerIntent',
  identifier: 'com.example.startTimer',
  title: 'Start Timer',
  implementation: IntentImplementationType.dart,
  parameters: parameters,
);

const _duration = IntentParamInfo(
  fieldName: 'timer',
  dartType: 'Duration',
  title: 'Timer',
  isOptional: false,
);

const _nullableDuration = IntentParamInfo(
  fieldName: 'timer',
  dartType: 'Duration?',
  title: 'Timer',
  isOptional: true,
);

const _fallbackMicros =
    'let timerMicros: Int = Int(timer.converted(to: .seconds).value * 1_000_000)';
const _nativeMicros =
    'let timerMicros: Int = Int(timer.components.seconds) * 1_000_000 + '
    'Int(timer.components.attoseconds / 1_000_000_000_000)';

void main() {
  group('SwiftGenerator (#53 Duration parameters)', () {
    group('default / fallback (rich-types OFF)', () {
      test('emits Measurement<UnitDuration> in a single struct, no #if', () {
        final result = const SwiftGenerator().generateAll(
          intents: [_intent(parameters: [_duration])],
        );

        expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
        expect(result, contains('var timer: Measurement<UnitDuration>'));
        // The native Duration type must never leak into the default output.
        expect(result, isNot(contains('var timer: Duration\n')));
        expect(result, contains(_fallbackMicros));
        expect(result, contains('"timer": timerMicros'));
      });

      test('master on but rich-types not selected keeps the fallback', () {
        final generator = const SwiftGenerator(
          experimental: ExperimentalFeatures(
            masterEnabled: true,
            enabled: {ExperimentalFeature.appSchema},
          ),
        );
        final result = generator.generateAll(
          intents: [_intent(parameters: [_duration])],
        );

        expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
        expect(result, contains('var timer: Measurement<UnitDuration>'));
        expect(result, contains(_fallbackMicros));
      });

      test('nullable Duration falls back to optional Measurement', () {
        final result = const SwiftGenerator().generateAll(
          intents: [_intent(parameters: [_nullableDuration])],
        );

        expect(result, contains('var timer: Measurement<UnitDuration>?'));
        expect(
          result,
          contains(
            'let timerMicros: Int? = timer.map { '
            'Int(\$0.converted(to: .seconds).value * 1_000_000) }',
          ),
        );
      });
    });

    group('rich-types ON (dual-branch)', () {
      test('native Duration in #if, Measurement fallback in #else', () {
        final result = _experimentalGenerator().generateAll(
          intents: [_intent(parameters: [_duration])],
        );

        expect(result, contains('#if APP_INTENTS_WWDC26'));
        expect(result, contains('#else'));
        expect(result, contains('#endif'));

        final ifBranch = result.substring(
          result.indexOf('#if'),
          result.indexOf('#else'),
        );
        final elseBranch = result.substring(
          result.indexOf('#else'),
          result.indexOf('#endif'),
        );

        // #if branch: native iOS 27 Duration, components-based microseconds.
        expect(ifBranch, contains('@available(iOS 27.0, *)'));
        expect(ifBranch, contains('var timer: Duration'));
        expect(ifBranch, contains(_nativeMicros));
        expect(ifBranch, isNot(contains('Measurement<UnitDuration>')));

        // #else branch: stable Measurement fallback at iOS 17.
        expect(elseBranch, contains('@available(iOS 17.0, *)'));
        expect(elseBranch, contains('var timer: Measurement<UnitDuration>'));
        expect(elseBranch, contains(_fallbackMicros));

        // Both branches serialize to the same branch-agnostic Dart wire value.
        expect(ifBranch, contains('"timer": timerMicros'));
        expect(elseBranch, contains('"timer": timerMicros'));
      });
    });
  });
}
