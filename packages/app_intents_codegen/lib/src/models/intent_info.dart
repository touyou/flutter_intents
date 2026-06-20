import 'union_info.dart';

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

  /// The URL scheme for intent execution (e.g., 'taskapp').
  /// When non-null, Swift code uses URL scheme instead of FlutterBridge.
  final String? urlScheme;

  /// The action segment in the URL (e.g., 'create' for 'taskapp://create?...').
  final String? urlAction;

  /// Template for the dialog shown after intent execution.
  /// Supports {paramName} interpolation.
  final String? resultDialogTemplate;

  /// Template for the parameter summary shown in Shortcuts UI.
  /// Supports {paramName} references.
  final String? parameterSummary;

  /// The execution mode for the intent.
  /// When foreground, both `supportedModes` (iOS 26+) and `openAppWhenRun` are generated.
  final IntentModeType? supportedModes;

  /// Experimental (WWDC26): whether the intent conforms to `LongRunningIntent`.
  /// Only emitted when the long-running experimental feature is enabled.
  final bool longRunning;

  /// Experimental (WWDC26): whether the intent conforms to `CancellableIntent`.
  /// Only emitted when the long-running experimental feature is enabled.
  final bool cancellable;

  /// Experimental (WWDC26): the targets this intent may execute against.
  /// When non-empty, generates `allowedExecutionTargets: IntentExecutionTargets`.
  final List<IntentExecutionTargetType>? executionTargets;

  /// Experimental (WWDC26): the App Schema this intent conforms to, as a dotted
  /// `domain.schema` path (e.g. `messages.setMessageReadStatus`). When set and
  /// the `app-schema` feature is enabled, adds the `@AppIntent(schema:)` macro.
  final String? schema;

  /// Experimental (WWDC26): whether the intent emits a generated
  /// `register<Intent>Donator()` reverse executor (#55). Only effective when the
  /// `donation` feature is enabled.
  final bool donatable;

  const IntentInfo({
    required this.className,
    required this.identifier,
    required this.title,
    this.description,
    required this.implementation,
    required this.parameters,
    this.urlScheme,
    this.urlAction,
    this.resultDialogTemplate,
    this.parameterSummary,
    this.supportedModes,
    this.longRunning = false,
    this.cancellable = false,
    this.executionTargets,
    this.schema,
    this.donatable = false,
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
        urlScheme == other.urlScheme &&
        urlAction == other.urlAction &&
        resultDialogTemplate == other.resultDialogTemplate &&
        parameterSummary == other.parameterSummary &&
        supportedModes == other.supportedModes &&
        longRunning == other.longRunning &&
        cancellable == other.cancellable &&
        schema == other.schema &&
        donatable == other.donatable &&
        _nullableListEquals(executionTargets, other.executionTargets);
  }

  @override
  int get hashCode => Object.hash(
    className,
    identifier,
    title,
    description,
    implementation,
    Object.hashAll(parameters),
    urlScheme,
    urlAction,
    resultDialogTemplate,
    parameterSummary,
    supportedModes,
    longRunning,
    cancellable,
    schema,
    donatable,
    executionTargets == null ? null : Object.hashAll(executionTargets!),
  );

  @override
  String toString() =>
      'IntentInfo(className: $className, identifier: $identifier, title: $title, '
      'description: $description, implementation: $implementation, '
      'parameters: $parameters, '
      'urlScheme: $urlScheme, urlAction: $urlAction, '
      'resultDialogTemplate: $resultDialogTemplate, parameterSummary: $parameterSummary, '
      'supportedModes: $supportedModes, longRunning: $longRunning, '
      'cancellable: $cancellable, executionTargets: $executionTargets, '
      'schema: $schema, donatable: $donatable)';
}

/// The implementation language for the intent.
enum IntentImplementationType { dart, swift, kotlin }

/// The execution mode for the intent.
enum IntentModeType { background, foreground }

/// Experimental (WWDC26): a process target an intent may execute against.
///
/// Maps to members of the Swift `IntentExecutionTargets` option set.
enum IntentExecutionTargetType { main, appIntentsExtension, widgetKitExtension }

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

  /// The enum type for this parameter (e.g., 'Priority').
  /// When set, the Swift parameter uses an AppEnum type.
  final String? enumType;

  /// The UTType identifier for file parameters (e.g., 'public.image').
  /// When set, the Swift parameter uses IntentFile with supportedTypeIdentifiers.
  final String? fileType;

  /// The element entity type for an entity-collection parameter (#53).
  /// When set, the Swift parameter uses `EntityCollection<Entity>` (native) or
  /// `[Entity]` (fallback), and the Dart handler receives a `List<String>` of
  /// identifiers.
  final String? entityCollectionType;

  /// The resolved union (#53) when this parameter's type is a `@UnionValueSpec`
  /// sealed class. When set, the Swift parameter uses the native `@UnionValue
  /// enum` (or the first case's entity type as the stable fallback).
  final UnionInfo? unionInfo;

  /// Opt-in to `IntentParameter.ValueState` reporting (iOS 18.2+ stable; no
  /// `#if` gating). When true and the param is optional, the generated Swift
  /// adds a sibling `<field>State: "unset" | "cleared" | "set"` to the params
  /// dict by reading `$field.valueState`. See `IntentParam.useValueState`.
  final bool useValueState;

  const IntentParamInfo({
    required this.fieldName,
    required this.dartType,
    required this.title,
    this.description,
    required this.isOptional,
    this.entityType,
    this.enumType,
    this.fileType,
    this.entityCollectionType,
    this.unionInfo,
    this.useValueState = false,
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
        entityType == other.entityType &&
        enumType == other.enumType &&
        fileType == other.fileType &&
        entityCollectionType == other.entityCollectionType &&
        unionInfo == other.unionInfo &&
        useValueState == other.useValueState;
  }

  @override
  int get hashCode => Object.hash(
    fieldName,
    dartType,
    title,
    description,
    isOptional,
    entityType,
    enumType,
    fileType,
    entityCollectionType,
    unionInfo,
    useValueState,
  );

  @override
  String toString() =>
      'IntentParamInfo(fieldName: $fieldName, dartType: $dartType, title: $title, '
      'description: $description, isOptional: $isOptional, entityType: $entityType, '
      'enumType: $enumType, fileType: $fileType, '
      'entityCollectionType: $entityCollectionType, unionInfo: $unionInfo, '
      'useValueState: $useValueState)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _nullableListEquals<T>(List<T>? a, List<T>? b) {
  if (a == null || b == null) return a == b;
  return _listEquals(a, b);
}
