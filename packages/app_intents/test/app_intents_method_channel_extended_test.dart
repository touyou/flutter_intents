import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_intents/app_intents_method_channel.dart';
import 'package:app_intents/src/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelAppIntents platform;
  const MethodChannel channel = MethodChannel('app_intents');
  final List<MethodCall> methodCalls = [];

  setUp(() {
    platform = MethodChannelAppIntents();
    methodCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        switch (methodCall.method) {
          case 'getPlatformVersion':
            return 'iOS 16.0';
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('MethodChannelAppIntents - Handler Registration', () {
    test('registerIntentHandler stores handler correctly', () async {
      var handlerCalled = false;
      Map<String, dynamic>? receivedParams;

      platform.registerIntentHandler(
        'com.example.testIntent',
        (params) async {
          handlerCalled = true;
          receivedParams = params;
          return {'success': true};
        },
      );

      // Simulate incoming intent execution from iOS
      final result = await platform.handleIntentExecution(
        'com.example.testIntent',
        {'key': 'value'},
      );

      expect(handlerCalled, isTrue);
      expect(receivedParams, {'key': 'value'});
      expect(result, {'success': true});
    });

    test('registerIntentHandler throws error for unknown intent', () async {
      expect(
        () => platform.handleIntentExecution('unknown.intent', {}),
        throwsA(isA<AppIntentError>()),
      );
    });

    test('registerEntityQueryHandler stores handler correctly', () async {
      var handlerCalled = false;
      List<String>? receivedIdentifiers;

      platform.registerEntityQueryHandler(
        'com.example.TaskEntity',
        (identifiers) async {
          handlerCalled = true;
          receivedIdentifiers = identifiers;
          return [
            {'id': '1', 'title': 'Task 1'},
            {'id': '2', 'title': 'Task 2'},
          ];
        },
      );

      // Simulate entity query from iOS
      final result = await platform.handleEntityQuery(
        'com.example.TaskEntity',
        ['1', '2'],
      );

      expect(handlerCalled, isTrue);
      expect(receivedIdentifiers, ['1', '2']);
      expect(result.length, 2);
      expect(result[0]['id'], '1');
    });

    test('registerEntityQueryHandler throws error for unknown entity', () async {
      expect(
        () => platform.handleEntityQuery('unknown.entity', ['1']),
        throwsA(isA<AppIntentError>()),
      );
    });

    test('registerSuggestedEntitiesHandler stores handler correctly', () async {
      var handlerCalled = false;

      platform.registerSuggestedEntitiesHandler(
        'com.example.TaskEntity',
        () async {
          handlerCalled = true;
          return [
            {'id': '1', 'title': 'Suggested Task'},
          ];
        },
      );

      // Simulate suggested entities request from iOS
      final result = await platform.handleSuggestedEntitiesQuery(
        'com.example.TaskEntity',
      );

      expect(handlerCalled, isTrue);
      expect(result.length, 1);
      expect(result[0]['title'], 'Suggested Task');
    });

    test('registerSuggestedEntitiesHandler throws error for unknown entity', () async {
      expect(
        () => platform.handleSuggestedEntitiesQuery('unknown.entity'),
        throwsA(isA<AppIntentError>()),
      );
    });
  });

  group('MethodChannelAppIntents - Intent Execution Stream', () {
    test('onIntentExecution emits events when intents are received', () async {
      final events = <IntentExecutionRequest>[];
      final subscription = platform.onIntentExecution.listen(events.add);

      // Simulate receiving intent execution from iOS via method channel
      await simulateIncomingMethodCall(
        channel,
        'executeIntent',
        {
          'identifier': 'com.example.testIntent',
          'params': {'key': 'value'},
        },
      );

      await Future.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events[0].identifier, 'com.example.testIntent');
      expect(events[0].params, {'key': 'value'});

      await subscription.cancel();
    });
  });

  group('MethodChannelAppIntents - Method Channel Calls', () {
    test('handles incoming executeIntent call', () async {
      platform.registerIntentHandler(
        'com.example.testIntent',
        (params) async => {'result': 'success'},
      );

      // The method channel handler should be set up
      expect(platform.methodChannel, isNotNull);
    });
  });
}

/// Helper to simulate an incoming method call from the native side.
Future<void> simulateIncomingMethodCall(
  MethodChannel channel,
  String method,
  Map<String, dynamic> arguments,
) async {
  final ByteData message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );

  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    channel.name,
    message,
    (ByteData? reply) {},
  );
}
