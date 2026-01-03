/// Error codes for App Intent operations.
///
/// These codes correspond to standard iOS App Intent error types
/// as well as custom error scenarios.
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
  final Map<String, dynamic>? details;

  /// Creates a new [AppIntentError].
  ///
  /// Both [code] and [message] are required.
  AppIntentError({
    required this.code,
    required this.message,
    this.details,
  });

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
    }
  }
}
