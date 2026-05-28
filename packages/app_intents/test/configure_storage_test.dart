import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_intents/app_intents.dart';
import 'package:app_intents/app_intents_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('configureStorage - Platform Interface', () {
    test('throws UnimplementedError by default', () {
      final platform = _TestAppIntentsPlatform();

      expect(
        () => platform.configureStorage(appGroupIdentifier: 'group.test'),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('configureStorage - MethodChannel', () {
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
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends appGroupIdentifier to native', () async {
      await platform.configureStorage(
        appGroupIdentifier: 'group.com.example.app',
      );

      expect(methodCalls, hasLength(1));
      expect(methodCalls[0].method, 'configureStorage');
      expect(
        methodCalls[0].arguments,
        {'appGroupIdentifier': 'group.com.example.app'},
      );
    });

    test('sends both appGroupIdentifier and storageIdentifier', () async {
      await platform.configureStorage(
        appGroupIdentifier: 'group.com.example.app',
        storageIdentifier: 'com.example.app',
      );

      expect(methodCalls, hasLength(1));
      expect(methodCalls[0].method, 'configureStorage');
      expect(
        methodCalls[0].arguments,
        {
          'appGroupIdentifier': 'group.com.example.app',
          'storageIdentifier': 'com.example.app',
        },
      );
    });

    test('omits storageIdentifier when null', () async {
      await platform.configureStorage(
        appGroupIdentifier: 'group.com.example.app',
      );

      final args = methodCalls[0].arguments as Map;
      expect(args.containsKey('storageIdentifier'), isFalse);
    });
  });

  group('configureStorage - Public API', () {
    late MethodChannelAppIntents mockPlatform;
    const MethodChannel channel = MethodChannel('app_intents');
    final List<MethodCall> methodCalls = [];

    setUp(() {
      mockPlatform = MethodChannelAppIntents();
      methodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          return null;
        },
      );

      AppIntentsPlatform.instance = mockPlatform;
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('AppIntents.configureStorage delegates to platform', () async {
      final appIntents = AppIntents();
      await appIntents.configureStorage(
        appGroupIdentifier: 'group.com.example.app',
      );

      expect(methodCalls, hasLength(1));
      expect(methodCalls[0].method, 'configureStorage');
    });
  });

  group('configureStorage - cache operations after configuration', () {
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
            case 'configureStorage':
              return null;
            case 'setCachedValue':
              return null;
            case 'getCachedValue':
              return 'cached_value';
            case 'clearCachedValue':
              return null;
            case 'processPendingActions':
              return null;
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

    test('cache operations work after configureStorage', () async {
      // Configure storage first
      await platform.configureStorage(
        appGroupIdentifier: 'group.com.example.app',
      );

      // Then use cache operations
      await platform.setCachedValue('testKey', 'testValue');
      final value = await platform.getCachedValue('testKey');
      await platform.clearCachedValue('testKey');

      expect(methodCalls, hasLength(4));
      expect(methodCalls[0].method, 'configureStorage');
      expect(methodCalls[1].method, 'setCachedValue');
      expect(methodCalls[2].method, 'getCachedValue');
      expect(methodCalls[3].method, 'clearCachedValue');
      expect(value, 'cached_value');
    });

    test('processPendingActions works after configureStorage', () async {
      // Register a handler so processPendingActions can dispatch
      platform.registerIntentHandler(
        'com.example.test',
        (params) async => {'result': 'ok'},
      );

      await platform.configureStorage(
        appGroupIdentifier: 'group.com.example.app',
      );

      final result = await platform.processPendingActions();

      expect(methodCalls, hasLength(2));
      expect(methodCalls[0].method, 'configureStorage');
      expect(methodCalls[1].method, 'processPendingActions');
      expect(result, isFalse);
    });
  });
}

class _TestAppIntentsPlatform extends AppIntentsPlatform {}
