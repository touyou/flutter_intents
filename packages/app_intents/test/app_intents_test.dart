import 'package:flutter_test/flutter_test.dart';
import 'package:app_intents/app_intents.dart';
import 'package:app_intents/app_intents_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAppIntentsPlatform
    with MockPlatformInterfaceMixin
    implements AppIntentsPlatform {
  final Map<String, IntentHandler> _intentHandlers = {};
  final Map<String, EntityQueryHandler> _entityQueryHandlers = {};
  final Map<String, SuggestedEntitiesHandler> _suggestedEntitiesHandlers = {};

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  void registerIntentHandler(String identifier, IntentHandler handler) {
    _intentHandlers[identifier] = handler;
  }

  @override
  void registerEntityQueryHandler(
      String entityIdentifier, EntityQueryHandler handler) {
    _entityQueryHandlers[entityIdentifier] = handler;
  }

  @override
  void registerSuggestedEntitiesHandler(
      String entityIdentifier, SuggestedEntitiesHandler handler) {
    _suggestedEntitiesHandlers[entityIdentifier] = handler;
  }

  @override
  Stream<IntentExecutionRequest> get onIntentExecution =>
      Stream<IntentExecutionRequest>.empty();

  // Test helpers
  bool hasIntentHandler(String identifier) =>
      _intentHandlers.containsKey(identifier);
  bool hasEntityQueryHandler(String entityIdentifier) =>
      _entityQueryHandlers.containsKey(entityIdentifier);
  bool hasSuggestedEntitiesHandler(String entityIdentifier) =>
      _suggestedEntitiesHandlers.containsKey(entityIdentifier);
}

void main() {
  final AppIntentsPlatform initialPlatform = AppIntentsPlatform.instance;

  test('\$MethodChannelAppIntents is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAppIntents>());
  });

  group('AppIntents', () {
    late AppIntents appIntentsPlugin;
    late MockAppIntentsPlatform fakePlatform;

    setUp(() {
      appIntentsPlugin = AppIntents();
      fakePlatform = MockAppIntentsPlatform();
      AppIntentsPlatform.instance = fakePlatform;
    });

    test('getPlatformVersion', () async {
      expect(await appIntentsPlugin.getPlatformVersion(), '42');
    });

    test('registerIntentHandler delegates to platform', () {
      appIntentsPlugin.registerIntentHandler(
        'com.example.testIntent',
        (params) async => {'success': true},
      );

      expect(fakePlatform.hasIntentHandler('com.example.testIntent'), isTrue);
    });

    test('registerEntityQueryHandler delegates to platform', () {
      appIntentsPlugin.registerEntityQueryHandler(
        'TaskEntity',
        (identifiers) async => [],
      );

      expect(fakePlatform.hasEntityQueryHandler('TaskEntity'), isTrue);
    });

    test('registerSuggestedEntitiesHandler delegates to platform', () {
      appIntentsPlugin.registerSuggestedEntitiesHandler(
        'TaskEntity',
        () async => [],
      );

      expect(fakePlatform.hasSuggestedEntitiesHandler('TaskEntity'), isTrue);
    });

    test('onIntentExecution returns stream from platform', () {
      expect(appIntentsPlugin.onIntentExecution, isA<Stream<IntentExecutionRequest>>());
    });
  });
}
