import '../models/entity_info.dart';
import '../models/enum_info.dart';
import '../models/intent_info.dart';

/// Information about an App Shortcut to generate.
class AppShortcutInfo {
  /// The class name of the intent this shortcut triggers.
  final String intentClassName;

  /// The phrases that trigger this shortcut.
  final List<String> phrases;

  /// The short title displayed for this shortcut.
  final String shortTitle;

  /// The SF Symbol name for this shortcut's icon.
  final String systemImageName;

  const AppShortcutInfo({
    required this.intentClassName,
    required this.phrases,
    required this.shortTitle,
    required this.systemImageName,
  });
}

/// Generates Swift code for iOS AppIntents from analyzed Dart specifications.
///
/// This generator produces Swift code that can be used in iOS 17+ applications
/// to integrate with the App Intents framework.
class SwiftGenerator {
  /// Mapping of Dart types to Swift types.
  static const _typeMapping = <String, String>{
    'String': 'String',
    'int': 'Int',
    'double': 'Double',
    'bool': 'Bool',
    'DateTime': 'Date',
  };

  /// Indentation used for generated Swift code.
  static const _indent = '    ';

  /// Converts a Dart type to its Swift equivalent.
  ///
  /// Handles nullable types by preserving the `?` suffix.
  /// Unknown types are returned as-is.
  String dartTypeToSwiftType(String dartType) {
    final isNullable = dartType.endsWith('?');
    final baseType = isNullable ? dartType.substring(0, dartType.length - 1) : dartType;
    final swiftBaseType = _typeMapping[baseType] ?? baseType;
    return isNullable ? '$swiftBaseType?' : swiftBaseType;
  }

  /// Generates a Swift AppIntent struct from an [IntentInfo].
  ///
  /// The generated struct includes:
  /// - `@available(iOS 17.0, *)` availability attribute
  /// - Static title and optional description
  /// - `@Parameter` properties for each intent parameter
  /// - A `perform()` method that calls FlutterBridge or opens a URL
  String generateIntent(IntentInfo info) {
    final buffer = StringBuffer();

    // Import statements
    buffer.writeln('import AppIntents');
    if (info.urlScheme != null) {
      buffer.writeln('import UIKit');
    }
    if (_hasFileParams(info)) {
      buffer.writeln('import UniformTypeIdentifiers');
    }
    if (_needsCacheImport(info)) {
      buffer.writeln('import app_intents');
    }
    buffer.writeln();

    _generateIntentBody(buffer, info);

    return buffer.toString();
  }

  /// Writes a parameter declaration to the buffer.
  void _writeParameter(StringBuffer buffer, IntentParamInfo param) {
    // File type parameters use IntentFile
    if (param.fileType != null) {
      final isNullable = param.isOptional || param.dartType.endsWith('?');
      final swiftType = isNullable ? 'IntentFile?' : 'IntentFile';
      final paramParts = <String>['title: "${param.title}"'];
      if (param.description != null) {
        paramParts.add('description: "${param.description}"');
      }
      paramParts.add('supportedTypeIdentifiers: ["${param.fileType}"]');
      buffer.writeln('$_indent@Parameter(${paramParts.join(', ')})');
      buffer.writeln('${_indent}var ${param.fieldName}: $swiftType');
      return;
    }

    // Use entity type, enum type, or map Dart type to Swift type
    final swiftType = param.entityType ?? param.enumType ?? dartTypeToSwiftType(param.dartType);

    // Build @Parameter annotation
    final paramParts = <String>['title: "${param.title}"'];
    if (param.description != null) {
      paramParts.add('description: "${param.description}"');
    }
    buffer.writeln('$_indent@Parameter(${paramParts.join(', ')})');
    buffer.writeln('${_indent}var ${param.fieldName}: $swiftType');
  }

  /// Returns the Swift expression to convert a parameter value for MethodChannel.
  ///
  /// Date types need to be converted to ISO8601 strings since MethodChannel
  /// doesn't support NSDate directly.
  /// Entity types use `.id` to extract the entity identifier.
  /// File types use a pre-serialized variable name (see [_writeFileParamSerialization]).
  String _paramValueExpression(IntentParamInfo param) {
    // File types: use pre-serialized variable
    if (param.fileType != null) {
      return '${param.fieldName}FileInfo';
    }

    // Entity types: use .id
    if (param.entityType != null) {
      return '${param.fieldName}.id';
    }

    // Enum types: use .rawValue
    if (param.enumType != null) {
      return '${param.fieldName}.rawValue';
    }

    final isDate = param.dartType == 'DateTime' || param.dartType == 'DateTime?';
    final isNullable = param.dartType.endsWith('?');

    if (isDate) {
      if (isNullable) {
        return '${param.fieldName}.map { ISO8601DateFormatter().string(from: \$0) }';
      } else {
        return 'ISO8601DateFormatter().string(from: ${param.fieldName})';
      }
    }
    return param.fieldName;
  }

  /// Writes IntentFile serialization code before the params dictionary.
  ///
  /// Generates Swift code that writes the IntentFile data to a temporary file
  /// and creates a dictionary with path, mimeType, and filename.
  void _writeFileParamSerialization(
      StringBuffer buffer, IntentParamInfo param) {
    final name = param.fieldName;
    final isNullable = param.isOptional || param.dartType.endsWith('?');
    final indent2 = '$_indent$_indent';

    if (isNullable) {
      buffer.writeln('${indent2}var ${name}FileInfo: [String: Any?]? = nil');
      buffer.writeln('${indent2}if let $name {');
      buffer.writeln(
          '$indent2${_indent}let fileName = "app_intent_\\(UUID().uuidString)"');
      buffer.writeln(
          '$indent2${_indent}let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory())');
      buffer.writeln(
          '$indent2$_indent$_indent.appendingPathComponent(fileName, conformingTo: $name.type ?? .data)');
      buffer.writeln(
          '$indent2${_indent}try $name.data.write(to: tempUrl, options: [.atomic])');
      buffer.writeln('$indent2$_indent${name}FileInfo = [');
      buffer.writeln(
          '$indent2$_indent$_indent"path": tempUrl.path(),');
      buffer.writeln(
          '$indent2$_indent$_indent"mimeType": $name.type?.preferredMIMEType as Any,');
      buffer.writeln(
          '$indent2$_indent$_indent"filename": $name.filename as Any');
      buffer.writeln('$indent2$_indent]');
      buffer.writeln('$indent2}');
    } else {
      buffer.writeln(
          '${indent2}let ${name}FileName = "app_intent_\\(UUID().uuidString)"');
      buffer.writeln(
          '${indent2}let ${name}TempUrl = URL(fileURLWithPath: NSTemporaryDirectory())');
      buffer.writeln(
          '$indent2$_indent.appendingPathComponent(${name}FileName, conformingTo: $name.type ?? .data)');
      buffer.writeln(
          '${indent2}try $name.data.write(to: ${name}TempUrl, options: [.atomic])');
      buffer.writeln('${indent2}let ${name}FileInfo: [String: Any?] = [');
      buffer.writeln(
          '$indent2$_indent"path": ${name}TempUrl.path(),');
      buffer.writeln(
          '$indent2$_indent"mimeType": $name.type?.preferredMIMEType as Any,');
      buffer.writeln(
          '$indent2$_indent"filename": $name.filename as Any');
      buffer.writeln('$indent2]');
    }
  }

  /// Whether the given intent has any file type parameters.
  bool _hasFileParams(IntentInfo info) {
    return info.parameters.any((p) => p.fileType != null);
  }

  /// Whether the intent uses cache mode (needs `import app_intents`).
  bool _needsCacheImport(IntentInfo info) {
    return info.urlScheme == null &&
        info.supportedModes == IntentModeType.foreground;
  }

  /// Writes the perform method to the buffer, dispatching based on execution mode.
  ///
  /// Three modes:
  /// 1. URL scheme: urlScheme is set → opens URL
  /// 2. Cache: supportedModes is foreground without urlScheme → caches to UserDefaults
  /// 3. FlutterBridge: default → direct MethodChannel via FlutterBridge actor
  void _writePerformMethod(StringBuffer buffer, IntentInfo info) {
    if (info.urlScheme != null) {
      _writeUrlSchemePerformMethod(buffer, info);
    } else if (info.supportedModes == IntentModeType.foreground) {
      _writeCachePerformMethod(buffer, info);
    } else {
      _writeFlutterBridgePerformMethod(buffer, info);
    }
  }

  /// Writes the perform method using FlutterBridge (MethodChannel).
  void _writeFlutterBridgePerformMethod(StringBuffer buffer, IntentInfo info) {
    final hasDialog = info.resultDialogTemplate != null;
    final returnType = hasDialog
        ? 'some IntentResult & ProvidesDialog'
        : 'some IntentResult';

    buffer.writeln('$_indent@MainActor');
    buffer.writeln('${_indent}func perform() async throws -> $returnType {');

    // File parameter serialization (before params dictionary)
    for (final param in info.parameters) {
      if (param.fileType != null) {
        _writeFileParamSerialization(buffer, param);
        buffer.writeln();
      }
    }

    // Build params dictionary
    if (info.parameters.isEmpty) {
      buffer.writeln('$_indent${_indent}let _ = try await FlutterBridge.shared.invoke(');
      buffer.writeln('$_indent$_indent${_indent}intent: "${info.className}",');
      buffer.writeln('$_indent$_indent${_indent}params: [:]');
      buffer.writeln('$_indent$_indent)');
    } else {
      buffer.writeln('$_indent${_indent}let _ = try await FlutterBridge.shared.invoke(');
      buffer.writeln('$_indent$_indent${_indent}intent: "${info.className}",');
      buffer.writeln('$_indent$_indent${_indent}params: [');
      for (var i = 0; i < info.parameters.length; i++) {
        final param = info.parameters[i];
        final comma = i < info.parameters.length - 1 ? ',' : '';
        final valueExpr = _paramValueExpression(param);
        buffer.writeln('$_indent$_indent$_indent$_indent"${param.fieldName}": $valueExpr$comma');
      }
      buffer.writeln('$_indent$_indent$_indent]');
      buffer.writeln('$_indent$_indent)');
    }

    if (hasDialog) {
      final dialogStr = _interpolateDialogTemplate(info.resultDialogTemplate!, info.parameters);
      buffer.writeln('$_indent${_indent}return .result(dialog: .init("$dialogStr"))');
    } else {
      buffer.writeln('$_indent${_indent}return .result()');
    }
    buffer.writeln('$_indent}');
  }

  /// Writes the perform method using cache mode (UserDefaults).
  ///
  /// Used when `supportedModes: foreground` is set without `urlScheme`.
  /// Caches intent parameters to UserDefaults via `setPendingAction()`,
  /// then returns `.result()`. The app opens in foreground, Flutter starts,
  /// and `processPendingActions()` delivers the cached action.
  void _writeCachePerformMethod(StringBuffer buffer, IntentInfo info) {
    final hasDialog = info.resultDialogTemplate != null;
    final returnType = hasDialog
        ? 'some IntentResult & ProvidesDialog'
        : 'some IntentResult';

    buffer.writeln('$_indent@MainActor');
    buffer.writeln('${_indent}func perform() async throws -> $returnType {');

    final indent2 = '$_indent$_indent';

    // File parameter serialization (before params dictionary)
    for (final param in info.parameters) {
      if (param.fileType != null) {
        _writeFileParamSerialization(buffer, param);
        buffer.writeln();
      }
    }

    // Build params dictionary
    buffer.writeln('${indent2}var params: [String: Any] = [:]');
    for (final param in info.parameters) {
      final valueExpr = _paramValueExpression(param);
      if (param.isOptional || param.dartType.endsWith('?')) {
        buffer.writeln('${indent2}if let ${param.fieldName}Value = $valueExpr {');
        buffer.writeln('$indent2${_indent}params["${param.fieldName}"] = ${param.fieldName}Value');
        buffer.writeln('$indent2}');
      } else {
        buffer.writeln('${indent2}params["${param.fieldName}"] = $valueExpr');
      }
    }

    buffer.writeln();
    buffer.writeln('${indent2}AppIntentsPlugin.setPendingAction(');
    buffer.writeln('$indent2${_indent}identifier: "${info.identifier}",');
    buffer.writeln('$indent2${_indent}params: params');
    buffer.writeln('$indent2)');

    if (hasDialog) {
      final dialogStr = _interpolateDialogTemplate(
          info.resultDialogTemplate!, info.parameters);
      buffer.writeln(
          '${indent2}return .result(dialog: .init("$dialogStr"))');
    } else {
      buffer.writeln('${indent2}return .result()');
    }
    buffer.writeln('$_indent}');
  }

  /// Derives a default URL action from an intent identifier.
  ///
  /// e.g., 'com.example.taskapp.createTask' -> 'createTask'
  String _defaultAction(String identifier) {
    final parts = identifier.split('.');
    return parts.last;
  }

  /// Writes the perform method using URL scheme execution.
  void _writeUrlSchemePerformMethod(StringBuffer buffer, IntentInfo info) {
    final scheme = info.urlScheme!;
    final action = info.urlAction ?? _defaultAction(info.identifier);
    final hasDialog = info.resultDialogTemplate != null;
    final returnType = hasDialog
        ? 'some IntentResult & ProvidesDialog'
        : 'some IntentResult';

    buffer.writeln('$_indent@MainActor');
    buffer.writeln('${_indent}func perform() async throws -> $returnType {');

    if (info.parameters.isEmpty) {
      buffer.writeln('$_indent${_indent}guard let url = URL(string: "$scheme://$action") else {');
      buffer.writeln('$_indent$_indent${_indent}throw AppIntentError.custom(code: "URL_CONSTRUCTION_FAILED", message: "Failed to construct URL for intent")');
      buffer.writeln('$_indent$_indent}');
    } else {
      buffer.writeln('$_indent${_indent}var components = URLComponents()');
      buffer.writeln('$_indent${_indent}components.scheme = "$scheme"');
      buffer.writeln('$_indent${_indent}components.host = "$action"');
      buffer.writeln();
      buffer.writeln('$_indent${_indent}var queryItems = [URLQueryItem]()');

      for (final param in info.parameters) {
        _writeUrlQueryItem(buffer, param);
      }

      buffer.writeln();
      buffer.writeln('$_indent${_indent}if !queryItems.isEmpty {');
      buffer.writeln('$_indent$_indent${_indent}components.queryItems = queryItems');
      buffer.writeln('$_indent$_indent}');
      buffer.writeln();
      buffer.writeln('$_indent${_indent}guard let url = components.url else {');
      buffer.writeln('$_indent$_indent${_indent}throw AppIntentError.custom(code: "URL_CONSTRUCTION_FAILED", message: "Failed to construct URL for intent")');
      buffer.writeln('$_indent$_indent}');
    }

    buffer.writeln();
    buffer.writeln('$_indent${_indent}await UIApplication.shared.open(url)');
    if (hasDialog) {
      final dialogStr = _interpolateDialogTemplate(info.resultDialogTemplate!, info.parameters);
      buffer.writeln('$_indent${_indent}return .result(dialog: .init("$dialogStr"))');
    } else {
      buffer.writeln('$_indent${_indent}return .result()');
    }
    buffer.writeln('$_indent}');
  }

  /// Writes a URL query item for a parameter.
  void _writeUrlQueryItem(StringBuffer buffer, IntentParamInfo param) {
    final isNullable = param.dartType.endsWith('?');
    final isDate = param.dartType == 'DateTime' || param.dartType == 'DateTime?';
    final isEntity = param.entityType != null;
    final isEnum = param.enumType != null;

    // Entity types: use .id for the URL value
    if (isEntity) {
      buffer.writeln('$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: ${param.fieldName}.id))');
      return;
    }

    // Enum types: use .rawValue for the URL value
    if (isEnum) {
      buffer.writeln('$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: ${param.fieldName}.rawValue))');
      return;
    }

    if (isNullable) {
      buffer.writeln('$_indent${_indent}if let ${param.fieldName} {');
      if (isDate) {
        buffer.writeln('$_indent$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: ISO8601DateFormatter().string(from: ${param.fieldName})))');
      } else {
        buffer.writeln('$_indent$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: String(describing: ${param.fieldName})))');
      }
      buffer.writeln('$_indent$_indent}');
    } else {
      if (isDate) {
        buffer.writeln('$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: ISO8601DateFormatter().string(from: ${param.fieldName})))');
      } else {
        buffer.writeln('$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: String(describing: ${param.fieldName})))');
      }
    }
  }

  /// Generates a Swift AppEntity struct from an [EntityInfo].
  ///
  /// The generated struct includes:
  /// - `@available(iOS 17.0, *)` availability attribute
  /// - `typeDisplayRepresentation` static property
  /// - `displayRepresentation` computed property
  /// - ID and other properties based on EntityPropertyInfo
  /// - A default query struct
  String generateEntity(EntityInfo info) {
    final buffer = StringBuffer();

    // Import statement
    buffer.writeln('import AppIntents');
    buffer.writeln();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct ${info.className}: AppEntity {');

    // Type display representation
    buffer.writeln('$_indent' 'static var typeDisplayRepresentation: TypeDisplayRepresentation =');
    buffer.writeln('$_indent$_indent' 'TypeDisplayRepresentation(name: "${info.title}")');
    buffer.writeln();

    // Default query
    buffer.writeln('${_indent}static var defaultQuery = ${info.className}Query()');
    buffer.writeln();

    // Properties
    for (final prop in info.properties) {
      final swiftType = dartTypeToSwiftType(prop.dartType);
      buffer.writeln('${_indent}var ${prop.fieldName}: $swiftType');
    }

    // Display representation
    buffer.writeln();
    _writeDisplayRepresentation(buffer, info);

    buffer.writeln('}');
    buffer.writeln();

    // Generate query struct
    _writeQueryStruct(buffer, info);

    return buffer.toString();
  }

  /// Writes the displayRepresentation computed property.
  void _writeDisplayRepresentation(StringBuffer buffer, EntityInfo info) {
    final titleProp = info.properties
        .where((p) => p.role == EntityPropertyRole.title)
        .firstOrNull;
    final subtitleProp = info.properties
        .where((p) => p.role == EntityPropertyRole.subtitle)
        .firstOrNull;
    final imageProp = info.properties
        .where((p) => p.role == EntityPropertyRole.image)
        .firstOrNull;

    buffer.writeln('${_indent}var displayRepresentation: DisplayRepresentation {');

    // Build arguments for DisplayRepresentation
    final titleExpr = titleProp != null ? titleProp.fieldName : 'id';
    final args = <String>['title: "\\($titleExpr)"'];

    if (subtitleProp != null) {
      final subtitleExpr = subtitleProp.dartType.endsWith('?')
          ? '${subtitleProp.fieldName} ?? ""'
          : subtitleProp.fieldName;
      args.add('subtitle: "\\($subtitleExpr)"');
    }

    if (imageProp != null && !imageProp.dartType.endsWith('?')) {
      args.add('image: .init(systemName: ${imageProp.fieldName})');
    }

    if (imageProp != null && imageProp.dartType.endsWith('?')) {
      // Nullable image: use conditional logic
      buffer.writeln('$_indent${_indent}if let ${imageProp.fieldName} {');
      final argsWithImage = List<String>.from(args);
      argsWithImage.add('image: .init(systemName: ${imageProp.fieldName})');
      buffer.writeln('$_indent$_indent${_indent}return DisplayRepresentation(${argsWithImage.join(', ')})');
      buffer.writeln('$_indent$_indent}');
      buffer.writeln('$_indent${_indent}return DisplayRepresentation(${args.join(', ')})');
    } else {
      buffer.writeln('$_indent${_indent}DisplayRepresentation(${args.join(', ')})');
    }

    buffer.writeln('$_indent}');
  }

  /// Writes the entity query struct with FlutterBridge integration.
  void _writeQueryStruct(StringBuffer buffer, EntityInfo info) {
    final idProp = info.properties
        .where((p) => p.role == EntityPropertyRole.id)
        .firstOrNull;
    final titleProp = info.properties
        .where((p) => p.role == EntityPropertyRole.title)
        .firstOrNull;
    final subtitleProp = info.properties
        .where((p) => p.role == EntityPropertyRole.subtitle)
        .firstOrNull;
    final imageProp = info.properties
        .where((p) => p.role == EntityPropertyRole.image)
        .firstOrNull;

    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct ${info.className}Query: EntityQuery {');

    // entities(for:) method
    buffer.writeln('${_indent}func entities(for identifiers: [String]) async throws -> [${info.className}] {');
    buffer.writeln('$_indent${_indent}let results = try await FlutterBridge.shared.queryEntities(');
    buffer.writeln('$_indent$_indent${_indent}entityIdentifier: "${info.identifier}",');
    buffer.writeln('$_indent$_indent${_indent}identifiers: identifiers');
    buffer.writeln('$_indent$_indent)');
    buffer.writeln('$_indent${_indent}return results.compactMap { dict in');
    _writeEntityDictMapping(buffer, info, idProp, titleProp, subtitleProp, imageProp);
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.writeln();

    // suggestedEntities() method
    buffer.writeln('${_indent}func suggestedEntities() async throws -> [${info.className}] {');
    buffer.writeln('$_indent${_indent}let results = try await FlutterBridge.shared.suggestedEntities(');
    buffer.writeln('$_indent$_indent${_indent}entityIdentifier: "${info.identifier}"');
    buffer.writeln('$_indent$_indent)');
    buffer.writeln('$_indent${_indent}return results.compactMap { dict in');
    _writeEntityDictMapping(buffer, info, idProp, titleProp, subtitleProp, imageProp);
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');

    buffer.writeln('}');
  }

  /// Writes the dictionary-to-entity mapping inside compactMap.
  void _writeEntityDictMapping(
    StringBuffer buffer,
    EntityInfo info,
    EntityPropertyInfo? idProp,
    EntityPropertyInfo? titleProp,
    EntityPropertyInfo? subtitleProp,
    EntityPropertyInfo? imageProp,
  ) {
    final id = idProp?.fieldName ?? 'id';
    final title = titleProp?.fieldName ?? 'title';

    buffer.writeln('$_indent$_indent${_indent}guard let $id = dict["$id"] as? String,');
    buffer.writeln('$_indent$_indent$_indent${_indent}let $title = dict["$title"] as? String else {');
    buffer.writeln('$_indent$_indent$_indent${_indent}return nil');
    buffer.writeln('$_indent$_indent$_indent}');

    if (subtitleProp != null) {
      final subtitle = subtitleProp.fieldName;
      buffer.writeln('$_indent$_indent${_indent}let $subtitle = dict["$subtitle"] as? String');
    }

    if (imageProp != null) {
      final image = imageProp.fieldName;
      buffer.writeln('$_indent$_indent${_indent}let $image = dict["$image"] as? String');
    }

    // Build initializer
    final initParts = <String>['$id: $id', '$title: $title'];
    if (subtitleProp != null) {
      initParts.add('${subtitleProp.fieldName}: ${subtitleProp.fieldName}');
    }
    if (imageProp != null) {
      initParts.add('${imageProp.fieldName}: ${imageProp.fieldName}');
    }
    buffer.writeln('$_indent$_indent${_indent}return ${info.className}(${initParts.join(', ')})');
  }

  /// Generates an AppShortcutsProvider struct from shortcut information.
  ///
  /// The generated struct includes:
  /// - `@available(iOS 17.0, *)` availability attribute
  /// - Static `appShortcuts` property with all configured shortcuts
  String generateAppShortcutsProvider(List<AppShortcutInfo> shortcuts) {
    final buffer = StringBuffer();

    // Import statement
    buffer.writeln('import AppIntents');
    buffer.writeln();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct AppShortcuts: AppShortcutsProvider {');
    buffer.writeln('${_indent}static var appShortcuts: [AppShortcut] {');

    for (final shortcut in shortcuts) {
      buffer.writeln('$_indent${_indent}AppShortcut(');
      buffer.writeln('$_indent$_indent${_indent}intent: ${shortcut.intentClassName}(),');
      buffer.writeln('$_indent$_indent${_indent}phrases: [');
      for (var j = 0; j < shortcut.phrases.length; j++) {
        final phraseComma = j < shortcut.phrases.length - 1 ? ',' : '';
        final swiftPhrase = _convertPhraseToSwift(shortcut.phrases[j]);
        buffer.writeln('$_indent$_indent$_indent$_indent"$swiftPhrase"$phraseComma');
      }
      buffer.writeln('$_indent$_indent$_indent],');
      buffer.writeln('$_indent$_indent${_indent}shortTitle: "${shortcut.shortTitle}",');
      buffer.writeln('$_indent$_indent${_indent}systemImageName: "${shortcut.systemImageName}"');
      buffer.writeln('$_indent$_indent)');
    }

    buffer.writeln('$_indent}');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates a complete Swift file containing all intents, entities, and shortcuts.
  ///
  /// This method combines all generated code into a single file with a single
  /// import statement at the top.
  String generateAll({
    List<IntentInfo> intents = const [],
    List<EntityInfo> entities = const [],
    List<AppShortcutInfo> shortcuts = const [],
    List<EnumInfo> enums = const [],
  }) {
    final buffer = StringBuffer();

    // Single import at the top
    buffer.writeln('import AppIntents');
    if (intents.any((i) => i.urlScheme != null)) {
      buffer.writeln('import UIKit');
    }
    if (intents.any((i) => _hasFileParams(i))) {
      buffer.writeln('import UniformTypeIdentifiers');
    }
    if (intents.any((i) => _needsCacheImport(i))) {
      buffer.writeln('import app_intents');
    }
    buffer.writeln();

    // Generate enums (before intents, since intents may reference them)
    for (final enumInfo in enums) {
      _generateEnumBody(buffer, enumInfo);
      buffer.writeln();
      buffer.writeln();
    }

    // Generate intents (without individual imports)
    for (final intent in intents) {
      final intentBuffer = StringBuffer();
      _generateIntentBody(intentBuffer, intent);
      buffer.writeln(intentBuffer.toString());
      buffer.writeln();
    }

    // Generate entities (without individual imports)
    for (final entity in entities) {
      buffer.writeln(_generateEntityBody(entity));
      buffer.writeln();
    }

    // Generate shortcuts provider (without individual imports)
    if (shortcuts.isNotEmpty) {
      buffer.writeln(_generateShortcutsProviderBody(shortcuts));
    }

    return buffer.toString();
  }

  /// Generates intent body without import statement.
  void _generateIntentBody(StringBuffer buffer, IntentInfo info) {
    // Availability and struct declaration
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct ${info.className}: AppIntent {');

    // Title
    buffer.writeln('$_indent' 'static var title: LocalizedStringResource = "${info.title}"');

    // Description (if present)
    if (info.description != null) {
      buffer.writeln('$_indent' 'static var description: IntentDescription =');
      buffer.writeln('$_indent$_indent' 'IntentDescription("${info.description}")');
    }

    // supportedModes / openAppWhenRun
    final needsForeground = info.urlScheme != null ||
        info.supportedModes == IntentModeType.foreground;
    if (needsForeground) {
      buffer.writeln();
      buffer.writeln('${_indent}@available(iOS 26.0, *)');
      buffer.writeln(
          '${_indent}static var supportedModes: IntentModes { .foreground }');
      buffer.writeln();
      buffer.writeln('${_indent}static var openAppWhenRun: Bool { true }');
    }

    // Parameter summary
    if (info.parameterSummary != null) {
      buffer.writeln();
      final summaryStr = _interpolateParameterSummary(info.parameterSummary!);
      buffer.writeln('${_indent}static var parameterSummary: some ParameterSummary {');
      buffer.writeln('$_indent${_indent}Summary("$summaryStr")');
      buffer.writeln('$_indent}');
    }

    // Parameters
    if (info.parameters.isNotEmpty) {
      buffer.writeln();
      for (final param in info.parameters) {
        _writeParameter(buffer, param);
      }
    }

    // Perform method
    buffer.writeln();
    _writePerformMethod(buffer, info);

    buffer.write('}');
  }

  /// Generates entity body without import statement.
  String _generateEntityBody(EntityInfo info) {
    final buffer = StringBuffer();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct ${info.className}: AppEntity {');

    // Type display representation
    buffer.writeln('$_indent' 'static var typeDisplayRepresentation: TypeDisplayRepresentation =');
    buffer.writeln('$_indent$_indent' 'TypeDisplayRepresentation(name: "${info.title}")');
    buffer.writeln();

    // Default query
    buffer.writeln('${_indent}static var defaultQuery = ${info.className}Query()');
    buffer.writeln();

    // Properties
    for (final prop in info.properties) {
      final swiftType = dartTypeToSwiftType(prop.dartType);
      buffer.writeln('${_indent}var ${prop.fieldName}: $swiftType');
    }

    // Display representation
    buffer.writeln();
    _writeDisplayRepresentation(buffer, info);

    buffer.writeln('}');
    buffer.writeln();

    // Generate query struct
    _writeQueryStruct(buffer, info);

    return buffer.toString();
  }

  /// Generates shortcuts provider body without import statement.
  String _generateShortcutsProviderBody(List<AppShortcutInfo> shortcuts) {
    final buffer = StringBuffer();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct AppShortcuts: AppShortcutsProvider {');
    buffer.writeln('${_indent}static var appShortcuts: [AppShortcut] {');

    for (final shortcut in shortcuts) {
      buffer.writeln('$_indent${_indent}AppShortcut(');
      buffer.writeln('$_indent$_indent${_indent}intent: ${shortcut.intentClassName}(),');
      buffer.writeln('$_indent$_indent${_indent}phrases: [');
      for (var j = 0; j < shortcut.phrases.length; j++) {
        final phraseComma = j < shortcut.phrases.length - 1 ? ',' : '';
        final swiftPhrase = _convertPhraseToSwift(shortcut.phrases[j]);
        buffer.writeln('$_indent$_indent$_indent$_indent"$swiftPhrase"$phraseComma');
      }
      buffer.writeln('$_indent$_indent$_indent],');
      buffer.writeln('$_indent$_indent${_indent}shortTitle: "${shortcut.shortTitle}",');
      buffer.writeln('$_indent$_indent${_indent}systemImageName: "${shortcut.systemImageName}"');
      buffer.writeln('$_indent$_indent)');
    }

    buffer.writeln('$_indent}');
    buffer.write('}');

    return buffer.toString();
  }

  /// Generates a Swift AppEnum from an [EnumInfo].
  String generateEnum(EnumInfo info) {
    final buffer = StringBuffer();
    buffer.writeln('import AppIntents');
    buffer.writeln();
    _generateEnumBody(buffer, info);
    return buffer.toString();
  }

  /// Generates enum body without import statement.
  void _generateEnumBody(StringBuffer buffer, EnumInfo info) {
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('enum ${info.className}: String, AppEnum {');

    // Cases
    for (final enumCase in info.cases) {
      buffer.writeln('${_indent}case ${enumCase.name}');
    }
    buffer.writeln();

    // typeDisplayRepresentation
    buffer.writeln('${_indent}static var typeDisplayRepresentation: TypeDisplayRepresentation = "${info.title}"');
    buffer.writeln();

    // caseDisplayRepresentations
    buffer.writeln('${_indent}static var caseDisplayRepresentations: [${info.className}: DisplayRepresentation] = [');
    for (var i = 0; i < info.cases.length; i++) {
      final c = info.cases[i];
      final comma = i < info.cases.length - 1 ? ',' : '';
      buffer.writeln('$_indent$_indent.${c.name}: "${c.displayTitle}"$comma');
    }
    buffer.writeln('$_indent]');

    buffer.write('}');
  }

  /// Converts `{paramName}` to `\(paramName)` for Swift dialog string interpolation.
  ///
  /// Also escapes double quotes to prevent conflicts with Swift string delimiters.
  String _interpolateDialogTemplate(String template, List<IntentParamInfo> params) {
    var result = template;
    // Escape double quotes for Swift string literals
    result = result.replaceAll('"', '\\"');
    for (final param in params) {
      result = result.replaceAll('{${param.fieldName}}', '\\(${param.fieldName})');
    }
    return result;
  }

  /// Converts `{paramName}` to `\(\.$paramName)` for Swift ParameterSummary.
  String _interpolateParameterSummary(String template) {
    return template.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (match) => '\\(\\.\$${match.group(1)})',
    );
  }

  /// Converts `{applicationName}` or `${applicationName}` to Swift's
  /// `\(.applicationName)` string interpolation for AppShortcut phrases.
  String _convertPhraseToSwift(String phrase) {
    return phrase
        .replaceAll(r'${applicationName}', '\\(.applicationName)')
        .replaceAll('{applicationName}', '\\(.applicationName)');
  }
}
