/// Represents a request to execute an intent from the native platform.
///
/// This class encapsulates the information needed to handle an intent
/// execution request that originates from iOS App Intents or Shortcuts.
class IntentExecutionRequest {
  /// The unique identifier of the intent to be executed.
  ///
  /// This corresponds to the intent identifier registered with
  /// [AppIntentsPlatform.registerIntentHandler].
  final String identifier;

  /// The parameters passed to the intent from the native platform.
  ///
  /// These parameters are provided by the user through Siri or Shortcuts
  /// and correspond to the intent's parameter definitions.
  final Map<String, dynamic> params;

  /// Creates a new [IntentExecutionRequest].
  ///
  /// Both [identifier] and [params] are required.
  IntentExecutionRequest({
    required this.identifier,
    required this.params,
  });

  /// Creates an [IntentExecutionRequest] from a map.
  ///
  /// This is typically used when deserializing data received from
  /// the native platform via Method Channel.
  factory IntentExecutionRequest.fromMap(Map<String, dynamic> map) {
    return IntentExecutionRequest(
      identifier: map['identifier'] as String,
      params: Map<String, dynamic>.from(map['params'] as Map? ?? {}),
    );
  }

  /// Converts this request to a map.
  ///
  /// This is useful for serialization or debugging purposes.
  Map<String, dynamic> toMap() {
    return {
      'identifier': identifier,
      'params': params,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! IntentExecutionRequest) return false;
    return identifier == other.identifier && _mapsEqual(params, other.params);
  }

  @override
  int get hashCode => Object.hash(identifier, Object.hashAll(params.entries));

  @override
  String toString() {
    return 'IntentExecutionRequest(identifier: $identifier, params: $params)';
  }

  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
