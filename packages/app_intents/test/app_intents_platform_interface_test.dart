import 'package:flutter_test/flutter_test.dart';
import 'package:app_intents/app_intents_platform_interface.dart';

void main() {
  group('AppIntentsPlatform', () {
    test('throws UnimplementedError for getPlatformVersion', () {
      final platform = _TestAppIntentsPlatform();

      expect(
        () => platform.getPlatformVersion(),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('throws UnimplementedError for registerIntentHandler', () {
      final platform = _TestAppIntentsPlatform();

      expect(
        () => platform.registerIntentHandler(
          'test.intent',
          (params) async => {},
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('throws UnimplementedError for registerEntityQueryHandler', () {
      final platform = _TestAppIntentsPlatform();

      expect(
        () => platform.registerEntityQueryHandler(
          'test.entity',
          (identifiers) async => [],
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('throws UnimplementedError for registerSuggestedEntitiesHandler', () {
      final platform = _TestAppIntentsPlatform();

      expect(
        () => platform.registerSuggestedEntitiesHandler(
          'test.entity',
          () async => [],
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('throws UnimplementedError for onIntentExecution getter', () {
      final platform = _TestAppIntentsPlatform();

      expect(
        () => platform.onIntentExecution,
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}

/// A minimal test implementation that delegates to the base class
/// to verify UnimplementedError behavior.
class _TestAppIntentsPlatform extends AppIntentsPlatform {}
