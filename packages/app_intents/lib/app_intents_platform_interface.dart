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
        'registerIntentHandler() has not been implemented.');
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
        'registerEntityQueryHandler() has not been implemented.');
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
        'registerSuggestedEntitiesHandler() has not been implemented.');
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
    throw UnimplementedError(
        'onIntentExecution has not been implemented.');
  }
}
