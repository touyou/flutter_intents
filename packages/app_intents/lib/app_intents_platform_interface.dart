import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'app_intents_method_channel.dart';
import 'src/models/models.dart';

/// The interface that implementations of app_intents must implement.
///
/// Platform implementations should extend this class rather than implement it
/// as `app_intents` does not consider newly added methods to be breaking
/// changes. Extending this class (using `extends`) ensures that the subclass
/// will get the default implementation, while platform implementations that
/// `implements` this interface will be broken by newly added
/// [AppIntentsPlatform] methods.
abstract class AppIntentsPlatform extends PlatformInterface {
  /// Constructs a AppIntentsPlatform.
  AppIntentsPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppIntentsPlatform _instance = MethodChannelAppIntents();

  /// The default instance of [AppIntentsPlatform] to use.
  ///
  /// Defaults to [MethodChannelAppIntents].
  static AppIntentsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AppIntentsPlatform] when
  /// they register themselves.
  static set instance(AppIntentsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the current platform version.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Registers a handler for the specified intent.
  ///
  /// When an intent with the given [identifier] is executed from iOS
  /// (via Siri or Shortcuts), the [handler] will be called with the
  /// intent's parameters.
  ///
  /// The [handler] should return a map containing the result of the
  /// intent execution, which will be passed back to iOS.
  ///
  /// Example:
  /// ```dart
  /// AppIntentsPlatform.instance.registerIntentHandler(
  ///   'com.example.AddTaskIntent',
  ///   (params) async {
  ///     final title = params['title'] as String;
  ///     // Add the task...
  ///     return {'taskId': 'new-task-id'};
  ///   },
  /// );
  /// ```
  void registerIntentHandler(
    String identifier,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> params) handler,
  ) {
    throw UnimplementedError(
      'registerIntentHandler() has not been implemented.',
    );
  }

  /// Registers a handler for querying entities by their identifiers.
  ///
  /// When iOS needs to resolve entity references (e.g., when a user
  /// selects a specific item in Shortcuts), this handler will be called
  /// with the list of entity identifiers to look up.
  ///
  /// The [handler] should return a list of entity maps, each containing
  /// at minimum an 'id' field and any display properties needed by iOS.
  ///
  /// Example:
  /// ```dart
  /// AppIntentsPlatform.instance.registerEntityQueryHandler(
  ///   'TaskEntity',
  ///   (identifiers) async {
  ///     final tasks = await database.getTasksByIds(identifiers);
  ///     return tasks.map((t) => {
  ///       'id': t.id,
  ///       'title': t.title,
  ///       'displayRepresentation': t.title,
  ///     }).toList();
  ///   },
  /// );
  /// ```
  void registerEntityQueryHandler(
    String entityIdentifier,
    Future<List<Map<String, dynamic>>> Function(List<String> identifiers)
    handler,
  ) {
    throw UnimplementedError(
      'registerEntityQueryHandler() has not been implemented.',
    );
  }

  /// Registers a handler for providing suggested/default entities.
  ///
  /// When iOS displays a picker for the entity type, this handler will
  /// be called to provide a list of suggested entities that the user
  /// can choose from.
  ///
  /// The [handler] should return a list of entity maps representing
  /// commonly used or recently accessed items.
  ///
  /// Example:
  /// ```dart
  /// AppIntentsPlatform.instance.registerSuggestedEntitiesHandler(
  ///   'TaskEntity',
  ///   () async {
  ///     final recentTasks = await database.getRecentTasks(limit: 10);
  ///     return recentTasks.map((t) => {
  ///       'id': t.id,
  ///       'title': t.title,
  ///       'displayRepresentation': t.title,
  ///     }).toList();
  ///   },
  /// );
  /// ```
  void registerSuggestedEntitiesHandler(
    String entityIdentifier,
    Future<List<Map<String, dynamic>>> Function() handler,
  ) {
    throw UnimplementedError(
      'registerSuggestedEntitiesHandler() has not been implemented.',
    );
  }

  /// Registers a handler for an `IntentValueQuery` (#51).
  ///
  /// An `IntentValueQuery` receives a serializable search input from the system
  /// (for content that is hard to index ahead of time) and returns matching
  /// entities. The [handler] receives the input map (e.g. `{'query': 'text'}`)
  /// and returns a list of entity maps.
  ///
  /// Example:
  /// ```dart
  /// AppIntentsPlatform.instance.registerValueQueryHandler(
  ///   'com.example.app.ProductEntity',
  ///   (input) async {
  ///     final products = await catalog.search(input['query'] as String? ?? '');
  ///     return products.map((p) => p.toJson()).toList();
  ///   },
  /// );
  /// ```
  ///
  /// See `docs/adr/0001-intent-value-query-bridge.md`.
  void registerValueQueryHandler(
    String entityIdentifier,
    Future<List<Map<String, dynamic>>> Function(Map<String, dynamic> input)
    handler,
  ) {
    throw UnimplementedError(
      'registerValueQueryHandler() has not been implemented.',
    );
  }

  /// Donates a set of contextually relevant entities to the system (#55).
  ///
  /// Tells the system which entities are relevant right now, scoped by
  /// [context] (e.g. media to suggest during a workout). Each call is a
  /// **stateful overwrite** for that context — passing an empty [entities] list
  /// clears the previously donated set.
  ///
  /// [entityIdentifier] must match an entity whose generated Swift registered a
  /// donator (via `@EntitySpec(relevantEntities: true)`). [context] is an opaque
  /// token understood by the generated code (e.g. `'audio.nowPlaying'`).
  ///
  /// See `docs/adr/0003-donations-and-discovery.md`.
  Future<void> donateRelevantEntities(
    String entityIdentifier,
    List<Map<String, dynamic>> entities, {
    String? context,
  }) {
    throw UnimplementedError(
      'donateRelevantEntities() has not been implemented.',
    );
  }

  /// Binds the entity currently shown on screen to an `NSUserActivity` so Siri
  /// and Apple Intelligence can resolve references like "this" (#56).
  ///
  /// Call this as the user navigates, passing the primary entity for the
  /// current screen ([entityIdentifier] = the entity *type* identifier,
  /// [entityId] = the instance id). Creates/updates the current user activity
  /// and makes it current. Call [clearOnscreenEntity] when leaving the screen.
  ///
  /// **PoC status**: the user-activity lifecycle (`becomeCurrent` /
  /// `targetContentIdentifier`) uses stable APIs and works today. The actual
  /// `NSUserActivity.appEntityIdentifier` AppEntity association is iOS 26+ and
  /// needs the concrete entity type — see the on-device PoC note in
  /// `docs/adr/0004-onscreen-awareness-feasibility.md`. iOS-only; a no-op
  /// elsewhere.
  Future<void> setOnscreenEntity(
    String entityIdentifier,
    String entityId, {
    String? title,
  }) {
    throw UnimplementedError('setOnscreenEntity() has not been implemented.');
  }

  /// Clears the onscreen entity association set by [setOnscreenEntity] (#56).
  Future<void> clearOnscreenEntity() {
    throw UnimplementedError('clearOnscreenEntity() has not been implemented.');
  }

  /// Retrieves a cached value from native storage.
  Future<dynamic> getCachedValue(String key) {
    throw UnimplementedError('getCachedValue() has not been implemented.');
  }

  /// Sets a cached value in native storage.
  Future<void> setCachedValue(String key, dynamic value) {
    throw UnimplementedError('setCachedValue() has not been implemented.');
  }

  /// Clears a cached value from native storage.
  Future<void> clearCachedValue(String key) {
    throw UnimplementedError('clearCachedValue() has not been implemented.');
  }

  /// Checks for pending intent actions cached by native App Intents.
  ///
  /// Call this after all intent handlers are registered.
  /// Pending actions are delivered via the existing executeIntent mechanism.
  /// Returns `true` if a pending action was found and delivered.
  Future<bool> processPendingActions() {
    throw UnimplementedError(
      'processPendingActions() has not been implemented.',
    );
  }

  /// Configures shared storage for cross-process App Intents communication.
  ///
  /// On iOS, App Intents may run in a separate extension process
  /// (`WFIsolatedShortcutRunner`) that does not share `UserDefaults.standard`
  /// with the main app. Without App Group configuration, data written by one
  /// process is invisible to the other, causing apparent "data resets."
  ///
  /// Call this **before** any cache or pending action operations (typically
  /// at the start of `main()` or in the AppDelegate).
  ///
  /// - [appGroupIdentifier]: The App Group identifier (e.g.,
  ///   `"group.com.example.app"`). Must match the App Group configured in
  ///   Xcode under Signing & Capabilities.
  /// - [storageIdentifier]: Optional fixed identifier for cache key prefixes.
  ///   Ensures consistent keys across processes. Defaults to the
  ///   [appGroupIdentifier].
  Future<void> configureStorage({
    required String appGroupIdentifier,
    String? storageIdentifier,
  }) {
    throw UnimplementedError('configureStorage() has not been implemented.');
  }

  /// A stream of pending action notifications from native App Intents.
  ///
  /// Emits the intent identifier when a cache-mode intent's `perform()`
  /// stores a pending action via `setPendingAction()`. Events are buffered
  /// on the native side until Dart subscribes.
  ///
  /// Listen to this stream and call [processPendingActions] when an event
  /// arrives to deliver the cached action to the registered handler.
  Stream<String> get pendingActionsStream {
    throw UnimplementedError('pendingActionsStream has not been implemented.');
  }

  /// A stream of intent execution requests from the native platform.
  ///
  /// This stream emits [IntentExecutionRequest] objects whenever iOS
  /// triggers an intent execution. Use this for reactive programming
  /// patterns or when you need to handle intents outside of the
  /// registered handler pattern.
  ///
  /// Example:
  /// ```dart
  /// AppIntentsPlatform.instance.onIntentExecution.listen((request) {
  ///   print('Intent ${request.identifier} executed with ${request.params}');
  /// });
  /// ```
  Stream<IntentExecutionRequest> get onIntentExecution {
    throw UnimplementedError('onIntentExecution has not been implemented.');
  }
}
