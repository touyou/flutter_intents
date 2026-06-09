import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:test/test.dart';

void main() {
  group('ExperimentalFeature', () {
    test('fromFlag resolves known tokens and rejects unknown', () {
      expect(
        ExperimentalFeature.fromFlag('long-running'),
        ExperimentalFeature.longRunning,
      );
      expect(
        ExperimentalFeature.fromFlag('app-schema'),
        ExperimentalFeature.appSchema,
      );
      expect(
        ExperimentalFeature.fromFlag('rich-types'),
        ExperimentalFeature.richTypes,
      );
      expect(ExperimentalFeature.fromFlag('nope'), isNull);
    });

    test('allFlags lists every feature token', () {
      expect(
        ExperimentalFeature.allFlags,
        containsAll(<String>[
          'long-running',
          'app-schema',
          'ownership',
          'rich-types',
        ]),
      );
    });
  });

  group('ExperimentalFeatures', () {
    test('none disables everything', () {
      const features = ExperimentalFeatures.none;
      expect(features.masterEnabled, isFalse);
      expect(features.anyEnabled, isFalse);
      expect(features.isEnabled(ExperimentalFeature.longRunning), isFalse);
      expect(features.isEnabled(ExperimentalFeature.appSchema), isFalse);
    });

    test('master off ignores selected features', () {
      const features = ExperimentalFeatures(
        masterEnabled: false,
        enabled: {ExperimentalFeature.longRunning},
      );
      expect(features.isEnabled(ExperimentalFeature.longRunning), isFalse);
      expect(features.anyEnabled, isFalse);
    });

    test('master on with empty set enables all features', () {
      const features = ExperimentalFeatures(masterEnabled: true);
      expect(features.isEnabled(ExperimentalFeature.longRunning), isTrue);
      expect(features.isEnabled(ExperimentalFeature.appSchema), isTrue);
      expect(features.anyEnabled, isTrue);
    });

    test('master on with explicit set narrows to listed features', () {
      const features = ExperimentalFeatures(
        masterEnabled: true,
        enabled: {ExperimentalFeature.longRunning},
      );
      expect(features.isEnabled(ExperimentalFeature.longRunning), isTrue);
      expect(features.isEnabled(ExperimentalFeature.appSchema), isFalse);
    });

    test('value equality is order-independent for the enabled set', () {
      const a = ExperimentalFeatures(
        masterEnabled: true,
        enabled: {
          ExperimentalFeature.longRunning,
          ExperimentalFeature.appSchema,
        },
      );
      const b = ExperimentalFeatures(
        masterEnabled: true,
        enabled: {
          ExperimentalFeature.appSchema,
          ExperimentalFeature.longRunning,
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(ExperimentalFeatures.none)));
    });
  });
}
