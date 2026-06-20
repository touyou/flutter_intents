/// Flutter plugin for iOS App Intents integration.
///
/// This plugin enables Flutter apps to integrate with iOS App Intents,
/// allowing them to be controlled via Siri and Shortcuts.
library;

export 'src/models/models.dart';
export 'app_intents_platform_interface.dart' show AppIntentsPlatform;
export 'app_intents_method_channel.dart'
    show
        IntentHandler,
        EntityQueryHandler,
        SuggestedEntitiesHandler,
        ValueQueryHandler;

import 'app_intents_platform_interface.dart';
import 'src/models/models.dart';

/// Main class for interacting with iOS App Intents from Flutter.
///
/// This class provides methods to:
/// - Register handlers for intent execution
/// - Register handlers for entity queries
/// - Listen to intent execution events
///
/// Example usage:
/// ```dart
/// final appIntents = AppIntents();
///
/// // Register an intent handler
/// appIntents.registerIntentHandler(
///   'com.example.AddTaskIntent',
///   (params) async {
///     final title = params['title'] as String;
///     // Add the task...
///     return {'taskId': 'new-task-id'};
///   },
/// );
///
/// // Register an entity query handler
/// appIntents.registerEntityQueryHandler(
///   'TaskEntity',
///   (identifiers) async {
///     return identifiers.map((id) => {
///       'id': id,
///       'title': 'Task $id',
///     }).toList();
///   },
/// );
///
/// // Listen to intent executions
/// appIntents.onIntentExecution.listen((request) {
///   print('Intent ${request.identifier} executed');
/// });
/// ```
class AppIntents {
  /// Returns the current platform version.
  Future<String?> getPlatformVersion() {
    return AppIntentsPlatform.instance.getPlatformVersion();
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
  /// appIntents.registerIntentHandler(
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
    AppIntentsPlatform.instance.registerIntentHandler(identifier, handler);
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
  /// appIntents.registerEntityQueryHandler(
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
    AppIntentsPlatform.instance.registerEntityQueryHandler(
      entityIdentifier,
      handler,
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
  /// appIntents.registerSuggestedEntitiesHandler(
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
    AppIntentsPlatform.instance.registerSuggestedEntitiesHandler(
      entityIdentifier,
      handler,
    );
  }

  /// Registers a handler for an `IntentValueQuery` (#51).
  ///
  /// The [handler] receives the system's serializable search input (e.g.
  /// `{'query': 'text'}`) and returns matching entities as maps. Used for
  /// content that is hard to index ahead of time (large, server-side, or
  /// fast-changing). See `docs/adr/0001-intent-value-query-bridge.md`.
  ///
  /// Example:
  /// ```dart
  /// appIntents.registerValueQueryHandler(
  ///   'com.example.app.ProductEntity',
  ///   (input) async {
  ///     final products = await catalog.search(input['query'] as String? ?? '');
  ///     return products.map((p) => p.toJson()).toList();
  ///   },
  /// );
  /// ```
  void registerValueQueryHandler(
    String entityIdentifier,
    Future<List<Map<String, dynamic>>> Function(Map<String, dynamic> input)
    handler,
  ) {
    AppIntentsPlatform.instance.registerValueQueryHandler(
      entityIdentifier,
      handler,
    );
  }

  /// Donates contextually relevant entities to the system (#55).
  ///
  /// Tells the system which [entities] are relevant right now for [context]
  /// (e.g. media to suggest during a workout). Each call is a **stateful
  /// overwrite** — pass an empty list to clear the context. [entityIdentifier]
  /// must match an entity declared `@EntitySpec(relevantEntities: true)`.
  ///
  /// iOS-only; a no-op on other platforms. See
  /// `docs/adr/0003-donations-and-discovery.md`.
  Future<void> donateRelevantEntities(
    String entityIdentifier,
    List<Map<String, dynamic>> entities, {
    String? context,
  }) {
    return AppIntentsPlatform.instance.donateRelevantEntities(
      entityIdentifier,
      entities,
      context: context,
    );
  }

  /// Donates an executed intent so Siri / Apple Intelligence learns that the
  /// user performed this action in your app (#55).
  ///
  /// [identifier] must match an intent declared `@IntentSpec(donatable: true)`;
  /// [params] is the parameter map matching the intent's fields (the same shape
  /// the generated handler receives). Calls `AppIntent.donate()` (stable iOS
  /// 16+) on a reconstructed concrete intent; the iOS-27 donation symbols stay
  /// inside the gated generated closure.
  ///
  /// iOS-only; a no-op on other platforms. See
  /// `docs/adr/0003-donations-and-discovery.md`.
  Future<void> donateIntent(String identifier, Map<String, dynamic> params) {
    return AppIntentsPlatform.instance.donateIntent(identifier, params);
  }

  /// Binds the on-screen entity to the current `NSUserActivity` so Siri can
  /// resolve "this" to it (#56). Call as the user navigates; pass the entity
  /// *type* identifier and instance [entityId]. iOS-only; a no-op elsewhere.
  ///
  /// See `docs/adr/0004-onscreen-awareness-feasibility.md`.
  Future<void> setOnscreenEntity(
    String entityIdentifier,
    String entityId, {
    String? title,
  }) {
    return AppIntentsPlatform.instance.setOnscreenEntity(
      entityIdentifier,
      entityId,
      title: title,
    );
  }

  /// Clears the onscreen entity association set by [setOnscreenEntity] (#56).
  Future<void> clearOnscreenEntity() {
    return AppIntentsPlatform.instance.clearOnscreenEntity();
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
  /// appIntents.onIntentExecution.listen((request) {
  ///   print('Intent ${request.identifier} executed with ${request.params}');
  /// });
  /// ```
  Stream<IntentExecutionRequest> get onIntentExecution {
    return AppIntentsPlatform.instance.onIntentExecution;
  }

  /// A stream of pending action notifications from native App Intents.
  ///
  /// Listen to this stream and call [processPendingActions] on each event
  /// to deliver cached intent actions to registered handlers.
  Stream<String> get pendingActionsStream {
    return AppIntentsPlatform.instance.pendingActionsStream;
  }

  /// Retrieves a cached value from native storage.
  Future<dynamic> getCachedValue(String key) {
    return AppIntentsPlatform.instance.getCachedValue(key);
  }

  /// Sets a cached value in native storage.
  Future<void> setCachedValue(String key, dynamic value) {
    return AppIntentsPlatform.instance.setCachedValue(key, value);
  }

  /// Clears a cached value from native storage.
  Future<void> clearCachedValue(String key) {
    return AppIntentsPlatform.instance.clearCachedValue(key);
  }

  /// Checks for pending intent actions cached by native App Intents.
  ///
  /// Call this after all intent handlers are registered.
  /// Pending actions are delivered via the existing executeIntent mechanism.
  /// Returns `true` if a pending action was found and delivered.
  Future<bool> processPendingActions() {
    return AppIntentsPlatform.instance.processPendingActions();
  }

  /// Configures shared storage for cross-process App Intents communication.
  ///
  /// **iOS only.** On other platforms this is a no-op.
  ///
  /// On iOS, App Intents may run in a separate extension process that does
  /// not share `UserDefaults.standard` with the main app. Without this
  /// configuration, cached data and pending actions may appear to "reset"
  /// because each process has its own isolated UserDefaults.
  ///
  /// Call this **before** any cache or pending action operations.
  ///
  /// Example:
  /// ```dart
  /// final appIntents = AppIntents();
  /// await appIntents.configureStorage(
  ///   appGroupIdentifier: 'group.com.example.app',
  /// );
  /// ```
  ///
  /// On iOS, you must also call `AppIntentsPlugin.configure()` in your
  /// AppDelegate (or wherever generated Swift code runs) with the same
  /// App Group identifier, so that the extension process uses the shared
  /// storage as well.
  Future<void> configureStorage({
    required String appGroupIdentifier,
    String? storageIdentifier,
  }) {
    return AppIntentsPlatform.instance.configureStorage(
      appGroupIdentifier: appGroupIdentifier,
      storageIdentifier: storageIdentifier,
    );
  }
}
