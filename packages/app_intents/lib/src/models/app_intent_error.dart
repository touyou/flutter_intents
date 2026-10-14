/// Error codes for App Intent operations.
///
/// These codes correspond to standard iOS App Intent error types
/// as well as custom error scenarios.
///
/// A handler reports one by throwing `AppIntentError.fromCode(...)`. The code
/// crosses the MethodChannel unchanged, as the `PlatformException` code, so the
/// native side can turn it into a typed error. On Android the generated
/// `AppFunctionsBridge` maps the codes below to the matching
/// `androidx.appfunctions` exception; any other code becomes
/// `AppFunctionAppUnknownException` with the code kept in its message. That
/// table lives in `KotlinGenerator.appFunctionExceptionByErrorCode` in the
/// codegen package and is keyed by these enum names, so renaming a value here
/// means renaming it there too.
enum AppIntentErrorCode {
  /// The intent handler was not found for the given identifier.
  handlerNotFound,

  /// The entity query handler was not found for the given identifier.
  entityQueryHandlerNotFound,

  /// Invalid parameters were provided to the intent.
  invalidParameters,

  /// The operation was cancelled by the user.
  userCancelled,

  /// A network error occurred during the operation.
  networkError,

  /// An unknown error occurred.
  unknown,

  /// The requested resource or entity does not exist.
  notFound,

  /// The resource to create already exists, or conflicts with an existing one.
  alreadyExists,

  /// The caller is not allowed to perform this operation.
  denied,

  /// The app lacks a permission the user has not granted (e.g. calendar access).
  permissionRequired,

  /// The requested action is not supported by the app.
  notSupported,

  /// The requested feature is disabled, e.g. by a user setting.
  disabled,

  /// The caller exceeded a rate or quota limit.
  limitExceeded,
}

/// Represents an error that occurred during App Intent operations.
///
/// This class provides both a machine-readable [code] and a
/// human-readable [message] for error handling and display.
class AppIntentError implements Exception {
  /// The error code identifying the type of error.
  final String code;

  /// A human-readable description of the error.
  final String message;

  /// Optional additional details about the error.
  ///
  /// Travels to the native side with the error, so it must hold only values
  /// the `StandardMessageCodec` can encode.
  final Map<String, dynamic>? details;

  /// Creates a new [AppIntentError].
  ///
  /// Both [code] and [message] are required.
  AppIntentError({required this.code, required this.message, this.details});

  /// Creates an [AppIntentError] from a predefined error code.
  factory AppIntentError.fromCode(
    AppIntentErrorCode errorCode, {
    String? message,
    Map<String, dynamic>? details,
  }) {
    return AppIntentError(
      code: errorCode.name,
      message: message ?? _defaultMessage(errorCode),
      details: details,
    );
  }

  /// Creates an [AppIntentError] from a map.
  ///
  /// This is typically used when deserializing error data received
  /// from the native platform via Method Channel.
  factory AppIntentError.fromMap(Map<String, dynamic> map) {
    return AppIntentError(
      code: map['code'] as String? ?? 'unknown',
      message: map['message'] as String? ?? 'An unknown error occurred',
      details: map['details'] as Map<String, dynamic>?,
    );
  }

  /// Converts this error to a map.
  ///
  /// This is useful for serialization or sending back to the native platform.
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'message': message,
      if (details != null) 'details': details,
    };
  }

  @override
  String toString() {
    if (details != null) {
      return 'AppIntentError($code): $message, details: $details';
    }
    return 'AppIntentError($code): $message';
  }

  static String _defaultMessage(AppIntentErrorCode code) {
    switch (code) {
      case AppIntentErrorCode.handlerNotFound:
        return 'No handler registered for the specified intent';
      case AppIntentErrorCode.entityQueryHandlerNotFound:
        return 'No entity query handler registered for the specified entity type';
      case AppIntentErrorCode.invalidParameters:
        return 'Invalid parameters provided to the intent';
      case AppIntentErrorCode.userCancelled:
        return 'The operation was cancelled by the user';
      case AppIntentErrorCode.networkError:
        return 'A network error occurred';
      case AppIntentErrorCode.unknown:
        return 'An unknown error occurred';
      case AppIntentErrorCode.notFound:
        return 'The requested resource was not found';
      case AppIntentErrorCode.alreadyExists:
        return 'The resource already exists';
      case AppIntentErrorCode.denied:
        return 'The caller is not allowed to perform this operation';
      case AppIntentErrorCode.permissionRequired:
        return 'The app is missing a required permission';
      case AppIntentErrorCode.notSupported:
        return 'The requested action is not supported';
      case AppIntentErrorCode.disabled:
        return 'The requested feature is disabled';
      case AppIntentErrorCode.limitExceeded:
        return 'The request limit was exceeded';
    }
  }
}
