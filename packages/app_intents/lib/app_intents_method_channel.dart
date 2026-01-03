import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_intents_platform_interface.dart';
import 'src/models/models.dart';

/// Type definition for intent handler functions.
typedef IntentHandler = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> params);

/// Type definition for entity query handler functions.
typedef EntityQueryHandler = Future<List<Map<String, dynamic>>> Function(
    List<String> identifiers);

/// Type definition for suggested entities handler functions.
typedef SuggestedEntitiesHandler = Future<List<Map<String, dynamic>>> Function();

/// An implementation of [AppIntentsPlatform] that uses method channels.
class MethodChannelAppIntents extends AppIntentsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('app_intents');

  /// Registered intent handlers, keyed by intent identifier.
  final Map<String, IntentHandler> _intentHandlers = {};

  /// Registered entity query handlers, keyed by entity identifier.
  final Map<String, EntityQueryHandler> _entityQueryHandlers = {};

  /// Registered suggested entities handlers, keyed by entity identifier.
  final Map<String, SuggestedEntitiesHandler> _suggestedEntitiesHandlers = {};

  /// Stream controller for intent execution events.
  final StreamController<IntentExecutionRequest> _intentExecutionController =
      StreamController<IntentExecutionRequest>.broadcast();

  /// Whether the method call handler has been set up.
  bool _isHandlerSetUp = false;

  /// Constructor that sets up the method call handler.
  MethodChannelAppIntents() {
    _setupMethodCallHandler();
  }

  /// Sets up the method call handler for incoming calls from iOS.
  void _setupMethodCallHandler() {
    if (_isHandlerSetUp) return;
    _isHandlerSetUp = true;

    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handles incoming method calls from the native platform.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'executeIntent':
        return _onExecuteIntent(call.arguments as Map<Object?, Object?>);
      case 'queryEntities':
        return _onQueryEntities(call.arguments as Map<Object?, Object?>);
      case 'getSuggestedEntities':
        return _onGetSuggestedEntities(call.arguments as Map<Object?, Object?>);
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} is not implemented',
        );
    }
  }

  /// Handles intent execution requests from iOS.
  Future<Map<String, dynamic>> _onExecuteIntent(
      Map<Object?, Object?> arguments) async {
    final identifier = arguments['identifier'] as String;
    final params = _convertToStringDynamicMap(arguments['params']);

    // Emit event to the stream
    _intentExecutionController.add(IntentExecutionRequest(
      identifier: identifier,
      params: params,
    ));

    // Call the registered handler if available
    return handleIntentExecution(identifier, params);
  }

  /// Handles entity query requests from iOS.
  Future<List<Map<String, dynamic>>> _onQueryEntities(
      Map<Object?, Object?> arguments) async {
    final entityIdentifier = arguments['entityIdentifier'] as String;
    final identifiers = (arguments['identifiers'] as List<Object?>)
        .cast<String>()
        .toList();

    return handleEntityQuery(entityIdentifier, identifiers);
  }

  /// Handles suggested entities requests from iOS.
  Future<List<Map<String, dynamic>>> _onGetSuggestedEntities(
      Map<Object?, Object?> arguments) async {
    final entityIdentifier = arguments['entityIdentifier'] as String;

    return handleSuggestedEntitiesQuery(entityIdentifier);
  }

  /// Converts a dynamic map to Map<String, dynamic>.
  Map<String, dynamic> _convertToStringDynamicMap(Object? value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  void registerIntentHandler(
    String identifier,
    IntentHandler handler,
  ) {
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
  Stream<IntentExecutionRequest> get onIntentExecution =>
      _intentExecutionController.stream;

  /// Executes the registered handler for the given intent.
  ///
  /// This method is called internally when an intent execution request
  /// is received from iOS, and can also be called directly for testing.
  ///
  /// Throws [AppIntentError] if no handler is registered for the identifier.
  Future<Map<String, dynamic>> handleIntentExecution(
    String identifier,
    Map<String, dynamic> params,
  ) async {
    final handler = _intentHandlers[identifier];
    if (handler == null) {
      throw AppIntentError.fromCode(
        AppIntentErrorCode.handlerNotFound,
        message: 'No handler registered for intent: $identifier',
        details: {'identifier': identifier},
      );
    }

    try {
      return await handler(params);
    } catch (e) {
      if (e is AppIntentError) rethrow;
      throw AppIntentError(
        code: 'execution_error',
        message: 'Error executing intent: $e',
        details: {'identifier': identifier, 'error': e.toString()},
      );
    }
  }

  /// Queries entities using the registered handler.
  ///
  /// This method is called internally when an entity query request
  /// is received from iOS, and can also be called directly for testing.
  ///
  /// Throws [AppIntentError] if no handler is registered for the entity type.
  Future<List<Map<String, dynamic>>> handleEntityQuery(
    String entityIdentifier,
    List<String> identifiers,
  ) async {
    final handler = _entityQueryHandlers[entityIdentifier];
    if (handler == null) {
      throw AppIntentError.fromCode(
        AppIntentErrorCode.entityQueryHandlerNotFound,
        message: 'No entity query handler registered for: $entityIdentifier',
        details: {'entityIdentifier': entityIdentifier},
      );
    }

    try {
      return await handler(identifiers);
    } catch (e) {
      if (e is AppIntentError) rethrow;
      throw AppIntentError(
        code: 'query_error',
        message: 'Error querying entities: $e',
        details: {'entityIdentifier': entityIdentifier, 'error': e.toString()},
      );
    }
  }

  /// Gets suggested entities using the registered handler.
  ///
  /// This method is called internally when a suggested entities request
  /// is received from iOS, and can also be called directly for testing.
  ///
  /// Throws [AppIntentError] if no handler is registered for the entity type.
  Future<List<Map<String, dynamic>>> handleSuggestedEntitiesQuery(
    String entityIdentifier,
  ) async {
    final handler = _suggestedEntitiesHandlers[entityIdentifier];
    if (handler == null) {
      throw AppIntentError.fromCode(
        AppIntentErrorCode.entityQueryHandlerNotFound,
        message:
            'No suggested entities handler registered for: $entityIdentifier',
        details: {'entityIdentifier': entityIdentifier},
      );
    }

    try {
      return await handler();
    } catch (e) {
      if (e is AppIntentError) rethrow;
      throw AppIntentError(
        code: 'query_error',
        message: 'Error getting suggested entities: $e',
        details: {'entityIdentifier': entityIdentifier, 'error': e.toString()},
      );
    }
  }

  /// Disposes the stream controller.
  ///
  /// Call this method when the plugin is no longer needed to free resources.
  void dispose() {
    _intentExecutionController.close();
  }
}
