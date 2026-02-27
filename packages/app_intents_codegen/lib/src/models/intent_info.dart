/// Represents analyzed information about an intent specification.
class IntentInfo {
  /// The class name of the intent specification.
  final String className;

  /// The unique identifier for the intent.
  final String identifier;

  /// The human-readable title for the intent.
  final String title;

  /// An optional description of the intent.
  final String? description;

  /// The implementation language for the intent.
  final IntentImplementationType implementation;

  /// The parameters of the intent.
  final List<IntentParamInfo> parameters;

  /// The input type of the intent.
  final String? inputType;

  /// The output type of the intent.
  final String? outputType;

  /// The URL scheme for intent execution (e.g., 'taskapp').
  /// When non-null, Swift code uses URL scheme instead of FlutterBridge.
  final String? urlScheme;

  /// The action segment in the URL (e.g., 'create' for 'taskapp://create?...').
  final String? urlAction;

  const IntentInfo({
    required this.className,
    required this.identifier,
    required this.title,
    this.description,
    required this.implementation,
    required this.parameters,
    this.inputType,
    this.outputType,
    this.urlScheme,
    this.urlAction,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! IntentInfo) return false;
    return className == other.className &&
        identifier == other.identifier &&
        title == other.title &&
        description == other.description &&
        implementation == other.implementation &&
        _listEquals(parameters, other.parameters) &&
        inputType == other.inputType &&
        outputType == other.outputType &&
        urlScheme == other.urlScheme &&
        urlAction == other.urlAction;
  }

  @override
  int get hashCode => Object.hash(
        className,
        identifier,
        title,
        description,
        implementation,
        Object.hashAll(parameters),
        inputType,
        outputType,
        urlScheme,
        urlAction,
      );

  @override
  String toString() =>
      'IntentInfo(className: $className, identifier: $identifier, title: $title, '
      'description: $description, implementation: $implementation, '
      'parameters: $parameters, inputType: $inputType, outputType: $outputType, '
      'urlScheme: $urlScheme, urlAction: $urlAction)';
}

/// The implementation language for the intent.
enum IntentImplementationType {
  dart,
  swift,
}

/// Represents analyzed information about an intent parameter.
class IntentParamInfo {
  /// The field name of the parameter.
  final String fieldName;

  /// The Dart type of the parameter.
  final String dartType;

  /// The human-readable title for the parameter.
  final String title;

  /// An optional description of the parameter.
  final String? description;

  /// Whether the parameter is optional.
  final bool isOptional;

  /// The entity type for this parameter (e.g., 'TaskEntitySpec').
  /// When set, the Swift parameter uses an AppEntity type with picker UI.
  final String? entityType;

  const IntentParamInfo({
    required this.fieldName,
    required this.dartType,
    required this.title,
    this.description,
    required this.isOptional,
    this.entityType,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! IntentParamInfo) return false;
    return fieldName == other.fieldName &&
        dartType == other.dartType &&
        title == other.title &&
        description == other.description &&
        isOptional == other.isOptional &&
        entityType == other.entityType;
  }

  @override
  int get hashCode => Object.hash(
        fieldName,
        dartType,
        title,
        description,
        isOptional,
        entityType,
      );

  @override
  String toString() =>
      'IntentParamInfo(fieldName: $fieldName, dartType: $dartType, title: $title, '
      'description: $description, isOptional: $isOptional, entityType: $entityType)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
