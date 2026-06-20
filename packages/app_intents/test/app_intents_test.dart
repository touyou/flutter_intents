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
  final Map<String, ValueQueryHandler> valueQueryHandlers = {};

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  void registerIntentHandler(String identifier, IntentHandler handler) {
    _intentHandlers[identifier] = handler;
  }

  @override
  void registerEntityQueryHandler(
    String entityIdentifier,
    EntityQueryHandler handler,
  ) {
    _entityQueryHandlers[entityIdentifier] = handler;
  }

  @override
  void registerSuggestedEntitiesHandler(
    String entityIdentifier,
    SuggestedEntitiesHandler handler,
  ) {
    _suggestedEntitiesHandlers[entityIdentifier] = handler;
  }

  @override
  void registerValueQueryHandler(
    String entityIdentifier,
    ValueQueryHandler handler,
  ) {
    valueQueryHandlers[entityIdentifier] = handler;
  }

  final List<Map<String, dynamic>> donatedRelevantEntities = [];

  @override
  Future<void> donateRelevantEntities(
    String entityIdentifier,
    List<Map<String, dynamic>> entities, {
    String? context,
  }) async {
    donatedRelevantEntities.add({
      'entityIdentifier': entityIdentifier,
      'entities': entities,
      'context': context,
    });
  }

  final List<Map<String, dynamic>> donatedIntents = [];

  @override
  Future<void> donateIntent(
    String identifier,
    Map<String, dynamic> params,
  ) async {
    donatedIntents.add({'identifier': identifier, 'params': params});
  }

  final List<Map<String, dynamic>> onscreenCalls = [];

  @override
  Future<void> setOnscreenEntity(
    String entityIdentifier,
    String entityId, {
    String? title,
  }) async {
    onscreenCalls.add({
      'entityIdentifier': entityIdentifier,
      'entityId': entityId,
      'title': title,
    });
  }

  @override
  Future<void> clearOnscreenEntity() async {
    onscreenCalls.add({'cleared': true});
  }

  @override
  Stream<IntentExecutionRequest> get onIntentExecution =>
      Stream<IntentExecutionRequest>.empty();

  @override
  Stream<String> get pendingActionsStream => Stream<String>.empty();

  @override
  Future<dynamic> getCachedValue(String key) => Future.value(null);

  @override
  Future<void> setCachedValue(String key, dynamic value) => Future.value();

  @override
  Future<void> clearCachedValue(String key) => Future.value();

  @override
  Future<bool> processPendingActions() => Future.value(false);

  @override
  Future<void> configureStorage({
    required String appGroupIdentifier,
    String? storageIdentifier,
  }) => Future.value();

  // Test helpers
  bool hasIntentHandler(String identifier) =>
      _intentHandlers.containsKey(identifier);
  bool hasEntityQueryHandler(String entityIdentifier) =>
      _entityQueryHandlers.containsKey(entityIdentifier);
  bool hasSuggestedEntitiesHandler(String entityIdentifier) =>
      _suggestedEntitiesHandlers.containsKey(entityIdentifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test('registerValueQueryHandler delegates to platform', () {
      appIntentsPlugin.registerValueQueryHandler(
        'com.example.ProductEntity',
        (input) async => [],
      );

      expect(
        fakePlatform.valueQueryHandlers.containsKey(
          'com.example.ProductEntity',
        ),
        isTrue,
      );
    });

    test('donateRelevantEntities delegates to platform', () async {
      await appIntentsPlugin.donateRelevantEntities('com.example.SongEntity', [
        {'id': 's1', 'title': 'Track'},
      ], context: 'audio.nowPlaying');

      expect(fakePlatform.donatedRelevantEntities, hasLength(1));
      expect(
        fakePlatform.donatedRelevantEntities.first['entityIdentifier'],
        'com.example.SongEntity',
      );
      expect(
        fakePlatform.donatedRelevantEntities.first['context'],
        'audio.nowPlaying',
      );
    });

    test('donateIntent delegates to platform (#55)', () async {
      await appIntentsPlugin.donateIntent('com.example.taskapp.createTask', {
        'title': 'Buy milk',
      });

      expect(fakePlatform.donatedIntents, hasLength(1));
      expect(
        fakePlatform.donatedIntents.first['identifier'],
        'com.example.taskapp.createTask',
      );
      expect(fakePlatform.donatedIntents.first['params'], {
        'title': 'Buy milk',
      });
    });

    test(
      'setOnscreenEntity / clearOnscreenEntity delegate to platform',
      () async {
        await appIntentsPlugin.setOnscreenEntity(
          'com.example.TaskEntity',
          't1',
          title: 'My Task',
        );
        await appIntentsPlugin.clearOnscreenEntity();

        expect(fakePlatform.onscreenCalls, hasLength(2));
        expect(fakePlatform.onscreenCalls[0]['entityId'], 't1');
        expect(fakePlatform.onscreenCalls[0]['title'], 'My Task');
        expect(fakePlatform.onscreenCalls[1]['cleared'], isTrue);
      },
    );

    test('onIntentExecution returns stream from platform', () {
      expect(
        appIntentsPlugin.onIntentExecution,
        isA<Stream<IntentExecutionRequest>>(),
      );
    });
  });
}
