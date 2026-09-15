import 'package:app_intents/app_intents_method_channel.dart';
import 'package:app_intents/src/models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelAppIntents platform;
  const MethodChannel channel = MethodChannel('app_intents');
  final List<MethodCall> methodCalls = [];

  setUp(() {
    platform = MethodChannelAppIntents();
    methodCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'requestIntentValue') {
            return 'answered';
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Delivers an `executeIntent` call the way iOS does.
  Future<void> execute(String identifier, Map<String, dynamic> params) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'app_intents',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('executeIntent', {
              'identifier': identifier,
              'params': params,
            }),
          ),
          (_) {},
        );
  }

  /// Delivers an `intentCancelled` call the way iOS does.
  Future<void> cancel(String executionId, String reason) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'app_intents',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('intentCancelled', {
              'executionId': executionId,
              'reason': reason,
            }),
          ),
          (_) {},
        );
  }

  group('AppIntentExecution (#130 / #131)', () {
    test('is visible to the handler and strips the reserved key', () async {
      AppIntentExecution? seen;
      Map<String, dynamic>? seenParams;

      platform.registerIntentHandler('com.example.export', (params) async {
        seen = AppIntentExecution.current;
        seenParams = params;
        return {};
      });

      await execute('com.example.export', {
        'format': 'csv',
        intentExecutionIdKey: 'exec-1',
      });

      expect(seen, isNotNull);
      expect(seen!.executionId, equals('exec-1'));
      // The generated Params.fromMap never has to know about the reserved key.
      expect(seenParams, equals({'format': 'csv'}));
    });

    test('is absent for an intent that opened no execution scope', () async {
      AppIntentExecution? seen = AppIntentExecution.current;

      platform.registerIntentHandler('com.example.plain', (params) async {
        seen = AppIntentExecution.current;
        return {};
      });

      await execute('com.example.plain', {'format': 'csv'});

      expect(seen, isNull);
    });

    test('reportProgress scales a fraction to unit counts', () async {
      platform.registerIntentHandler('com.example.export', (params) async {
        await AppIntentExecution.current!.reportProgress(0.25);
        return {};
      });

      await execute('com.example.export', {intentExecutionIdKey: 'exec-1'});

      final call = methodCalls.firstWhere(
        (c) => c.method == 'reportIntentProgress',
      );
      expect(call.arguments['executionId'], equals('exec-1'));
      expect(call.arguments['completed'], equals(250));
      expect(call.arguments['total'], equals(1000));
    });

    test('reportProgress clamps out-of-range fractions', () async {
      platform.registerIntentHandler('com.example.export', (params) async {
        await AppIntentExecution.current!.reportProgress(4.2);
        return {};
      });

      await execute('com.example.export', {intentExecutionIdKey: 'exec-1'});

      final call = methodCalls.firstWhere(
        (c) => c.method == 'reportIntentProgress',
      );
      expect(call.arguments['completed'], equals(1000));
    });

    test('a cancellation reaches the running execution', () async {
      final observed = <bool>[];

      platform.registerIntentHandler('com.example.export', (params) async {
        final execution = AppIntentExecution.current!;
        observed.add(execution.isCancelled);
        await cancel('exec-1', 'userCancelled');
        observed.add(execution.isCancelled);
        expect(execution.cancellation?.reason, equals('userCancelled'));
        return {};
      });

      await execute('com.example.export', {intentExecutionIdKey: 'exec-1'});

      expect(observed, equals([false, true]));
    });

    test('a cancellation is also emitted on the stream', () async {
      final events = <IntentCancellation>[];
      platform.onIntentCancellation.listen(events.add);

      await cancel('exec-9', 'systemCancelled');
      await Future<void>.delayed(Duration.zero);

      expect(events.single.executionId, equals('exec-9'));
      expect(events.single.reason, equals('systemCancelled'));
    });

    test('requestValue asks the platform and returns the answer', () async {
      String? answer;

      platform.registerIntentHandler('com.example.note', (params) async {
        answer = await AppIntentExecution.current!.requestValue<String>('note');
        return {};
      });

      await execute('com.example.note', {intentExecutionIdKey: 'exec-1'});

      expect(answer, equals('answered'));
      final call = methodCalls.firstWhere(
        (c) => c.method == 'requestIntentValue',
      );
      expect(call.arguments['parameter'], equals('note'));
      expect(call.arguments['executionId'], equals('exec-1'));
    });

    test('the execution is dropped once the handler returns', () async {
      late AppIntentExecution execution;

      platform.registerIntentHandler('com.example.export', (params) async {
        execution = AppIntentExecution.current!;
        return {};
      });

      await execute('com.example.export', {intentExecutionIdKey: 'exec-1'});

      // A cancellation arriving after the handler finished must not resurrect
      // the execution — there is nothing left to cancel.
      await cancel('exec-1', 'tooLate');
      expect(execution.isCancelled, isFalse);
    });
  });
}
