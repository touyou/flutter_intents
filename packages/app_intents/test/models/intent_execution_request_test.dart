import 'package:flutter_test/flutter_test.dart';
import 'package:app_intents/src/models/intent_execution_request.dart';

void main() {
  group('IntentExecutionRequest', () {
    test('creates instance with required parameters', () {
      final request = IntentExecutionRequest(
        identifier: 'com.example.testIntent',
        params: {'key': 'value'},
      );

      expect(request.identifier, 'com.example.testIntent');
      expect(request.params, {'key': 'value'});
    });

    test('creates instance with empty params', () {
      final request = IntentExecutionRequest(
        identifier: 'com.example.testIntent',
        params: {},
      );

      expect(request.identifier, 'com.example.testIntent');
      expect(request.params, isEmpty);
    });

    group('fromMap', () {
      test('creates instance from valid map', () {
        final map = {
          'identifier': 'com.example.testIntent',
          'params': {'key': 'value', 'count': 42},
        };

        final request = IntentExecutionRequest.fromMap(map);

        expect(request.identifier, 'com.example.testIntent');
        expect(request.params, {'key': 'value', 'count': 42});
      });

      test('creates instance with empty params when params is null', () {
        final map = {
          'identifier': 'com.example.testIntent',
          'params': null,
        };

        final request = IntentExecutionRequest.fromMap(map);

        expect(request.identifier, 'com.example.testIntent');
        expect(request.params, isEmpty);
      });

      test('creates instance with empty params when params is missing', () {
        final map = {
          'identifier': 'com.example.testIntent',
        };

        final request = IntentExecutionRequest.fromMap(map);

        expect(request.identifier, 'com.example.testIntent');
        expect(request.params, isEmpty);
      });
    });

    group('toMap', () {
      test('converts instance to map', () {
        final request = IntentExecutionRequest(
          identifier: 'com.example.testIntent',
          params: {'key': 'value'},
        );

        final map = request.toMap();

        expect(map, {
          'identifier': 'com.example.testIntent',
          'params': {'key': 'value'},
        });
      });
    });

    group('equality', () {
      test('equal instances have same hashCode', () {
        final request1 = IntentExecutionRequest(
          identifier: 'com.example.testIntent',
          params: {'key': 'value'},
        );
        final request2 = IntentExecutionRequest(
          identifier: 'com.example.testIntent',
          params: {'key': 'value'},
        );

        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
      });

      test('different identifiers are not equal', () {
        final request1 = IntentExecutionRequest(
          identifier: 'com.example.intent1',
          params: {'key': 'value'},
        );
        final request2 = IntentExecutionRequest(
          identifier: 'com.example.intent2',
          params: {'key': 'value'},
        );

        expect(request1, isNot(equals(request2)));
      });

      test('different params are not equal', () {
        final request1 = IntentExecutionRequest(
          identifier: 'com.example.testIntent',
          params: {'key': 'value1'},
        );
        final request2 = IntentExecutionRequest(
          identifier: 'com.example.testIntent',
          params: {'key': 'value2'},
        );

        expect(request1, isNot(equals(request2)));
      });
    });

    test('toString returns readable format', () {
      final request = IntentExecutionRequest(
        identifier: 'com.example.testIntent',
        params: {'key': 'value'},
      );

      expect(
        request.toString(),
        "IntentExecutionRequest(identifier: com.example.testIntent, params: {key: value})",
      );
    });
  });
}
