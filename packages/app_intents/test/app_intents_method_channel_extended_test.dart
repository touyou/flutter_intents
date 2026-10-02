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
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          switch (methodCall.method) {
            case 'getPlatformVersion':
              return 'iOS 17.0';
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('MethodChannelAppIntents - Handler Registration', () {
    test('registerIntentHandler stores handler correctly', () async {
      var handlerCalled = false;
      Map<String, dynamic>? receivedParams;

      platform.registerIntentHandler('com.example.testIntent', (params) async {
        handlerCalled = true;
        receivedParams = params;
        return {'success': true};
      });

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

      platform.registerEntityQueryHandler('com.example.TaskEntity', (
        identifiers,
      ) async {
        handlerCalled = true;
        receivedIdentifiers = identifiers;
        return [
          {'id': '1', 'title': 'Task 1'},
          {'id': '2', 'title': 'Task 2'},
        ];
      });

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

    test(
      'handleEntityQuery returns empty list for unregistered entity',
      () async {
        final result = await platform.handleEntityQuery('unknown.entity', [
          '1',
        ]);
        expect(result, isEmpty);
      },
    );

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

    test(
      'handleSuggestedEntitiesQuery returns empty list for unregistered entity',
      () async {
        final result = await platform.handleSuggestedEntitiesQuery(
          'unknown.entity',
        );
        expect(result, isEmpty);
      },
    );

    test('registerValueQueryHandler stores handler correctly', () async {
      var handlerCalled = false;
      Map<String, dynamic>? receivedInput;

      platform.registerValueQueryHandler('com.example.ProductEntity', (
        input,
      ) async {
        handlerCalled = true;
        receivedInput = input;
        return [
          {'id': 'p1', 'title': 'Matched Product'},
        ];
      });

      // Simulate an IntentValueQuery from iOS.
      final result = await platform.handleValueQuery(
        'com.example.ProductEntity',
        {'query': 'shoes'},
      );

      expect(handlerCalled, isTrue);
      expect(receivedInput, {'query': 'shoes'});
      expect(result.length, 1);
      expect(result[0]['title'], 'Matched Product');
    });

    test(
      'handleValueQuery returns empty list for unregistered entity',
      () async {
        final result = await platform.handleValueQuery('unknown.entity', {
          'query': 'x',
        });
        expect(result, isEmpty);
      },
    );
  });

  group('MethodChannelAppIntents - Intent Execution Stream', () {
    test('onIntentExecution emits events when intents are received', () async {
      final events = <IntentExecutionRequest>[];
      final subscription = platform.onIntentExecution.listen(events.add);

      // Simulate receiving intent execution from iOS via method channel
      await simulateIncomingMethodCall(channel, 'executeIntent', {
        'identifier': 'com.example.testIntent',
        'params': {'key': 'value'},
      });

      await Future.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events[0].identifier, 'com.example.testIntent');
      expect(events[0].params, {'key': 'value'});

      await subscription.cancel();
    });

    Future<void> emit(String identifier) => simulateIncomingMethodCall(
      channel,
      'executeIntent',
      {'identifier': identifier, 'params': <String, dynamic>{}},
    );

    test(
      'replays requests emitted before the first listener, in order (#150)',
      () async {
        // Cold start: processPendingActions() dispatches before any widget
        // has subscribed.
        await emit('com.example.first');
        await emit('com.example.second');

        final events = <IntentExecutionRequest>[];
        final subscription = platform.onIntentExecution.listen(events.add);
        await Future.delayed(Duration.zero);
        await emit('com.example.live');
        await Future.delayed(Duration.zero);

        expect(events.map((e) => e.identifier), [
          'com.example.first',
          'com.example.second',
          'com.example.live',
        ]);
        await subscription.cancel();
      },
    );

    test('replays only to the first subscriber (#150)', () async {
      await emit('com.example.cold');

      final first = <IntentExecutionRequest>[];
      final second = <IntentExecutionRequest>[];
      final a = platform.onIntentExecution.listen(first.add);
      final b = platform.onIntentExecution.listen(second.add);
      await Future.delayed(Duration.zero);

      expect(first.map((e) => e.identifier), ['com.example.cold']);
      expect(second, isEmpty);
      await a.cancel();
      await b.cancel();
    });

    test('stops buffering once anyone has listened (#150)', () async {
      final early = platform.onIntentExecution.listen((_) {});
      await Future.delayed(Duration.zero);
      await early.cancel();

      // Nobody listens now. Replaying this to a screen opened later would
      // navigate on a stale intent, so it is dropped.
      await emit('com.example.unheard');

      final events = <IntentExecutionRequest>[];
      final late = platform.onIntentExecution.listen(events.add);
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      await late.cancel();
    });

    test('keeps only the newest unheard requests (#150)', () async {
      const limit = MethodChannelAppIntents.unheardIntentExecutionLimit;
      for (var i = 0; i < limit + 3; i++) {
        await emit('com.example.intent$i');
      }

      final events = <IntentExecutionRequest>[];
      final subscription = platform.onIntentExecution.listen(events.add);
      await Future.delayed(Duration.zero);

      expect(events, hasLength(limit));
      expect(events.first.identifier, 'com.example.intent3');
      expect(events.last.identifier, 'com.example.intent${limit + 2}');
      await subscription.cancel();
    });

    test('still runs the registered handler while buffering (#150)', () async {
      var handled = 0;
      platform.registerIntentHandler('com.example.cold', (params) async {
        handled++;
        return <String, dynamic>{};
      });

      await emit('com.example.cold');

      expect(handled, 1);
    });
  });

  group('MethodChannelAppIntents - updateAppShortcutParameters (#149)', () {
    test('invokes the native method', () async {
      await platform.updateAppShortcutParameters();

      expect(methodCalls.single.method, 'updateAppShortcutParameters');
    });

    test('is a no-op when the platform has no implementation', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      await expectLater(platform.updateAppShortcutParameters(), completes);
    });

    test('surfaces a missing updater as a PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'SHORTCUT_UPDATER_NOT_CONFIGURED');
          });

      await expectLater(
        platform.updateAppShortcutParameters(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'SHORTCUT_UPDATER_NOT_CONFIGURED',
          ),
        ),
      );
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
      .handlePlatformMessage(channel.name, message, (ByteData? reply) {});
}
