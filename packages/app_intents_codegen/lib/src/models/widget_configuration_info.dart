/// Represents analyzed information about a `@WidgetConfigurationSpec` class
/// (#98).
///
/// A widget configuration intent is compiled into the Widget Extension target,
/// which cannot start a Flutter engine — so everything generated from this
/// model reads the App Group persisted entity cache instead of calling into
/// Dart.
class WidgetConfigurationInfo {
  /// The class name of the widget configuration specification.
  final String className;

  /// The unique identifier for the configuration intent.
  final String identifier;

  /// The human-readable title.
  final String title;

  /// An optional description.
  final String? description;

  /// Whether the intent is exposed as a Shortcuts action.
  final bool isDiscoverable;

  /// Whether the generated entity queries implement `defaultResult()`.
  final bool generateDefaultResult;

  /// The configuration parameters.
  final List<WidgetParamInfo> parameters;

  const WidgetConfigurationInfo({
    required this.className,
    required this.identifier,
    required this.title,
    this.description,
    this.isDiscoverable = false,
    this.generateDefaultResult = false,
    required this.parameters,
  });

  /// The generated Swift struct name for the configuration intent.
  ///
  /// The Dart class name is used verbatim, matching how `@IntentSpec` and
  /// `@EntitySpec` name their generated structs.
  String get swiftName => className;

  /// The entity class names referenced by this configuration's parameters.
  Iterable<String> get referencedEntityTypes =>
      parameters.map((p) => p.entityType).whereType<String>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WidgetConfigurationInfo) return false;
    return className == other.className &&
        identifier == other.identifier &&
        title == other.title &&
        description == other.description &&
        isDiscoverable == other.isDiscoverable &&
        generateDefaultResult == other.generateDefaultResult &&
        _listEquals(parameters, other.parameters);
  }

  @override
  int get hashCode => Object.hash(
    className,
    identifier,
    title,
    description,
    isDiscoverable,
    generateDefaultResult,
    Object.hashAll(parameters),
  );

  @override
  String toString() =>
      'WidgetConfigurationInfo(className: $className, identifier: $identifier, '
      'title: $title, description: $description, '
      'isDiscoverable: $isDiscoverable, '
      'generateDefaultResult: $generateDefaultResult, '
      'parameters: $parameters)';
}

/// Represents analyzed information about a `@WidgetParameter` field.
class WidgetParamInfo {
  /// The field name of the parameter.
  final String name;

  /// The Dart type of the parameter (nullability preserved).
  final String dartType;

  /// The human-readable title.
  final String title;

  /// An optional description.
  final String? description;

  /// The referenced `@EntitySpec` class name, when this parameter is an entity
  /// picker. Null for plain scalar parameters.
  final String? entityType;

  const WidgetParamInfo({
    required this.name,
    required this.dartType,
    required this.title,
    this.description,
    this.entityType,
  });

  /// Whether the parameter is optional (its Dart type is nullable).
  bool get isOptional => dartType.endsWith('?');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WidgetParamInfo) return false;
    return name == other.name &&
        dartType == other.dartType &&
        title == other.title &&
        description == other.description &&
        entityType == other.entityType;
  }

  @override
  int get hashCode =>
      Object.hash(name, dartType, title, description, entityType);

  @override
  String toString() =>
      'WidgetParamInfo(name: $name, dartType: $dartType, title: $title, '
      'description: $description, entityType: $entityType)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
