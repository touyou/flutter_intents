import 'package:flutter_test/flutter_test.dart';
import 'package:app_intents/src/models/app_intent_error.dart';

void main() {
  group('AppIntentError', () {
    test('creates instance with required parameters', () {
      final error = AppIntentError(
        code: 'test_error',
        message: 'Test error message',
      );

      expect(error.code, 'test_error');
      expect(error.message, 'Test error message');
      expect(error.details, isNull);
    });

    test('creates instance with optional details', () {
      final error = AppIntentError(
        code: 'test_error',
        message: 'Test error message',
        details: {'field': 'value'},
      );

      expect(error.code, 'test_error');
      expect(error.message, 'Test error message');
      expect(error.details, {'field': 'value'});
    });

    group('fromCode', () {
      test('creates error with default message for handlerNotFound', () {
        final error = AppIntentError.fromCode(AppIntentErrorCode.handlerNotFound);

        expect(error.code, 'handlerNotFound');
        expect(error.message, 'No handler registered for the specified intent');
      });

      test('creates error with default message for entityQueryHandlerNotFound', () {
        final error = AppIntentError.fromCode(AppIntentErrorCode.entityQueryHandlerNotFound);

        expect(error.code, 'entityQueryHandlerNotFound');
        expect(error.message, 'No entity query handler registered for the specified entity type');
      });

      test('creates error with default message for invalidParameters', () {
        final error = AppIntentError.fromCode(AppIntentErrorCode.invalidParameters);

        expect(error.code, 'invalidParameters');
        expect(error.message, 'Invalid parameters provided to the intent');
      });

      test('creates error with default message for userCancelled', () {
        final error = AppIntentError.fromCode(AppIntentErrorCode.userCancelled);

        expect(error.code, 'userCancelled');
        expect(error.message, 'The operation was cancelled by the user');
      });

      test('creates error with default message for networkError', () {
        final error = AppIntentError.fromCode(AppIntentErrorCode.networkError);

        expect(error.code, 'networkError');
        expect(error.message, 'A network error occurred');
      });

      test('creates error with default message for unknown', () {
        final error = AppIntentError.fromCode(AppIntentErrorCode.unknown);

        expect(error.code, 'unknown');
        expect(error.message, 'An unknown error occurred');
      });

      test('allows custom message override', () {
        final error = AppIntentError.fromCode(
          AppIntentErrorCode.handlerNotFound,
          message: 'Custom error message',
        );

        expect(error.code, 'handlerNotFound');
        expect(error.message, 'Custom error message');
      });

      test('allows adding details', () {
        final error = AppIntentError.fromCode(
          AppIntentErrorCode.invalidParameters,
          details: {'parameter': 'taskId'},
        );

        expect(error.details, {'parameter': 'taskId'});
      });
    });

    group('fromMap', () {
      test('creates error from valid map', () {
        final map = {
          'code': 'custom_error',
          'message': 'Custom error message',
          'details': {'key': 'value'},
        };

        final error = AppIntentError.fromMap(map);

        expect(error.code, 'custom_error');
        expect(error.message, 'Custom error message');
        expect(error.details, {'key': 'value'});
      });

      test('uses defaults for missing code and message', () {
        final map = <String, dynamic>{};

        final error = AppIntentError.fromMap(map);

        expect(error.code, 'unknown');
        expect(error.message, 'An unknown error occurred');
        expect(error.details, isNull);
      });

      test('handles null details', () {
        final map = {
          'code': 'test_error',
          'message': 'Test message',
          'details': null,
        };

        final error = AppIntentError.fromMap(map);

        expect(error.details, isNull);
      });
    });

    group('toMap', () {
      test('converts error to map without details', () {
        final error = AppIntentError(
          code: 'test_error',
          message: 'Test message',
        );

        final map = error.toMap();

        expect(map, {
          'code': 'test_error',
          'message': 'Test message',
        });
        expect(map.containsKey('details'), isFalse);
      });

      test('converts error to map with details', () {
        final error = AppIntentError(
          code: 'test_error',
          message: 'Test message',
          details: {'field': 'value'},
        );

        final map = error.toMap();

        expect(map, {
          'code': 'test_error',
          'message': 'Test message',
          'details': {'field': 'value'},
        });
      });
    });

    group('toString', () {
      test('returns readable format without details', () {
        final error = AppIntentError(
          code: 'test_error',
          message: 'Test message',
        );

        expect(error.toString(), 'AppIntentError(test_error): Test message');
      });

      test('returns readable format with details', () {
        final error = AppIntentError(
          code: 'test_error',
          message: 'Test message',
          details: {'field': 'value'},
        );

        expect(
          error.toString(),
          'AppIntentError(test_error): Test message, details: {field: value}',
        );
      });
    });

    test('implements Exception interface', () {
      final error = AppIntentError(
        code: 'test_error',
        message: 'Test message',
      );

      expect(error, isA<Exception>());
    });
  });
}
