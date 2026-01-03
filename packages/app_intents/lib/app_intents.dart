/// Flutter plugin for iOS App Intents integration.
///
/// This plugin enables Flutter apps to integrate with iOS App Intents,
/// allowing them to be controlled via Siri and Shortcuts.
library app_intents;

export 'src/models/models.dart';
export 'app_intents_platform_interface.dart' show AppIntentsPlatform;
export 'app_intents_method_channel.dart'
    show IntentHandler, EntityQueryHandler, SuggestedEntitiesHandler;

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
    AppIntentsPlatform.instance
        .registerEntityQueryHandler(entityIdentifier, handler);
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
    AppIntentsPlatform.instance
        .registerSuggestedEntitiesHandler(entityIdentifier, handler);
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
}
