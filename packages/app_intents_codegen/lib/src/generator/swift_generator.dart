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
    final baseType = isNullable
        ? dartType.substring(0, dartType.length - 1)
        : dartType;
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
    final needsBridge =
        (info.urlScheme == null &&
            info.supportedModes != IntentModeType.foreground) ||
        info.parameters.any((p) => p.entityType != null);
    if (needsBridge) {
      buffer.writeln('import AppIntentsBridge');
    }
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
    final swiftType =
        param.entityType ??
        param.enumType ??
        dartTypeToSwiftType(param.dartType);

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

    final isDate =
        param.dartType == 'DateTime' || param.dartType == 'DateTime?';
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
    StringBuffer buffer,
    IntentParamInfo param,
  ) {
    final name = param.fieldName;
    final isNullable = param.isOptional || param.dartType.endsWith('?');
    final indent2 = '$_indent$_indent';

    if (isNullable) {
      buffer.writeln('${indent2}var ${name}FileInfo: [String: Any?]? = nil');
      buffer.writeln('${indent2}if let $name {');
      buffer.writeln(
        '$indent2${_indent}let fileName = "app_intent_\\(UUID().uuidString)"',
      );
      buffer.writeln(
        '$indent2${_indent}let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory())',
      );
      buffer.writeln(
        '$indent2$_indent$_indent.appendingPathComponent(fileName, conformingTo: $name.type ?? .data)',
      );
      buffer.writeln(
        '$indent2${_indent}try $name.data.write(to: tempUrl, options: [.atomic])',
      );
      buffer.writeln('$indent2$_indent${name}FileInfo = [');
      buffer.writeln('$indent2$_indent$_indent"path": tempUrl.path(),');
      buffer.writeln(
        '$indent2$_indent$_indent"mimeType": $name.type?.preferredMIMEType as Any,',
      );
      buffer.writeln(
        '$indent2$_indent$_indent"filename": $name.filename as Any',
      );
      buffer.writeln('$indent2$_indent]');
      buffer.writeln('$indent2}');
    } else {
      buffer.writeln(
        '${indent2}let ${name}FileName = "app_intent_\\(UUID().uuidString)"',
      );
      buffer.writeln(
        '${indent2}let ${name}TempUrl = URL(fileURLWithPath: NSTemporaryDirectory())',
      );
      buffer.writeln(
        '$indent2$_indent.appendingPathComponent(${name}FileName, conformingTo: $name.type ?? .data)',
      );
      buffer.writeln(
        '${indent2}try $name.data.write(to: ${name}TempUrl, options: [.atomic])',
      );
      buffer.writeln('${indent2}let ${name}FileInfo: [String: Any?] = [');
      buffer.writeln('$indent2$_indent"path": ${name}TempUrl.path(),');
      buffer.writeln(
        '$indent2$_indent"mimeType": $name.type?.preferredMIMEType as Any,',
      );
      buffer.writeln('$indent2$_indent"filename": $name.filename as Any');
      buffer.writeln('$indent2]');
    }
  }

  /// Writes cleanup code for temp files created by [_writeFileParamSerialization].
  ///
  /// Only emitted in FlutterBridge mode where the file is consumed synchronously.
  /// In cache mode, Dart is responsible for cleanup after reading.
  void _writeFileParamCleanup(
    StringBuffer buffer,
    IntentInfo info,
    String indent,
  ) {
    final fileParams = info.parameters.where((p) => p.fileType != null);
    if (fileParams.isEmpty) return;

    for (final param in fileParams) {
      final isNullable = param.isOptional || param.dartType.endsWith('?');
      if (isNullable) {
        buffer.writeln(
          '${indent}if let path = ${param.fieldName}FileInfo?["path"] as? String {',
        );
        buffer.writeln(
          '$indent${_indent}try? FileManager.default.removeItem(atPath: path)',
        );
        buffer.writeln('$indent}');
      } else {
        buffer.writeln(
          '${indent}try? FileManager.default.removeItem(at: ${param.fieldName}TempUrl)',
        );
      }
    }
  }

  /// Whether the given intent has any file type parameters.
  bool _hasFileParams(IntentInfo info) {
    return info.parameters.any((p) => p.fileType != null);
  }

  /// Whether the intent needs to run in the foreground (URL scheme or explicit foreground mode).
  bool _needsForeground(IntentInfo info) {
    return info.urlScheme != null ||
        info.supportedModes == IntentModeType.foreground;
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

  /// Returns the Swift return type for a perform() method based on dialog presence.
  String _performReturnType(IntentInfo info) {
    return info.resultDialogTemplate != null
        ? 'some IntentResult & ProvidesDialog'
        : 'some IntentResult';
  }

  /// Writes the perform() method signature.
  void _writePerformSignature(StringBuffer buffer, IntentInfo info) {
    buffer.writeln('$_indent@MainActor');
    buffer.writeln(
      '${_indent}func perform() async throws -> ${_performReturnType(info)} {',
    );
  }

  /// Writes file parameter serialization for all file-type parameters.
  void _writeFileParamSerializations(StringBuffer buffer, IntentInfo info) {
    for (final param in info.parameters) {
      if (param.fileType != null) {
        _writeFileParamSerialization(buffer, param);
        buffer.writeln();
      }
    }
  }

  /// Writes the return statement (with optional dialog).
  void _writeReturnResult(StringBuffer buffer, IntentInfo info, String indent) {
    if (info.resultDialogTemplate != null) {
      final dialogStr = _interpolateDialogTemplate(
        info.resultDialogTemplate!,
        info.parameters,
      );
      buffer.writeln('${indent}return .result(dialog: .init("$dialogStr"))');
    } else {
      buffer.writeln('${indent}return .result()');
    }
  }

  /// Writes the perform method using FlutterBridge (MethodChannel).
  void _writeFlutterBridgePerformMethod(StringBuffer buffer, IntentInfo info) {
    _writePerformSignature(buffer, info);
    _writeFileParamSerializations(buffer, info);

    final indent2 = '$_indent$_indent';

    // Build params dictionary
    if (info.parameters.isEmpty) {
      buffer.writeln(
        '${indent2}let _ = try await FlutterBridge.shared.invoke(',
      );
      buffer.writeln('$indent2${_indent}intent: "${info.className}",');
      buffer.writeln('$indent2${_indent}params: [:]');
      buffer.writeln('$indent2)');
    } else {
      buffer.writeln(
        '${indent2}let _ = try await FlutterBridge.shared.invoke(',
      );
      buffer.writeln('$indent2${_indent}intent: "${info.className}",');
      buffer.writeln('$indent2${_indent}params: [');
      for (var i = 0; i < info.parameters.length; i++) {
        final param = info.parameters[i];
        final comma = i < info.parameters.length - 1 ? ',' : '';
        final valueExpr = _paramValueExpression(param);
        buffer.writeln(
          '$_indent$_indent$_indent$_indent"${param.fieldName}": $valueExpr$comma',
        );
      }
      buffer.writeln('$indent2$_indent]');
      buffer.writeln('$indent2)');
    }

    // Clean up temp files after FlutterBridge invoke completes
    _writeFileParamCleanup(buffer, info, indent2);

    _writeReturnResult(buffer, info, indent2);
    buffer.writeln('$_indent}');
  }

  /// Writes the perform method using cache mode (UserDefaults).
  ///
  /// Used when `supportedModes: foreground` is set without `urlScheme`.
  /// Caches intent parameters to UserDefaults via `setPendingAction()`,
  /// then returns `.result()`. The app opens in foreground, Flutter starts,
  /// and `processPendingActions()` delivers the cached action.
  void _writeCachePerformMethod(StringBuffer buffer, IntentInfo info) {
    _writePerformSignature(buffer, info);
    _writeFileParamSerializations(buffer, info);

    final indent2 = '$_indent$_indent';

    // Build params dictionary
    buffer.writeln('${indent2}var params: [String: Any] = [:]');
    for (final param in info.parameters) {
      final valueExpr = _paramValueExpression(param);
      if (param.isOptional || param.dartType.endsWith('?')) {
        buffer.writeln(
          '${indent2}if let ${param.fieldName}Value = $valueExpr {',
        );
        buffer.writeln(
          '$indent2${_indent}params["${param.fieldName}"] = ${param.fieldName}Value',
        );
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

    _writeReturnResult(buffer, info, indent2);
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
    final indent2 = '$_indent$_indent';

    _writePerformSignature(buffer, info);

    if (info.parameters.isEmpty) {
      buffer.writeln(
        '${indent2}guard let url = URL(string: "$scheme://$action") else {',
      );
      buffer.writeln(
        '$indent2${_indent}throw AppIntentError.custom(code: "URL_CONSTRUCTION_FAILED", message: "Failed to construct URL for intent")',
      );
      buffer.writeln('$indent2}');
    } else {
      buffer.writeln('${indent2}var components = URLComponents()');
      buffer.writeln('${indent2}components.scheme = "$scheme"');
      buffer.writeln('${indent2}components.host = "$action"');
      buffer.writeln();
      buffer.writeln('${indent2}var queryItems = [URLQueryItem]()');

      for (final param in info.parameters) {
        _writeUrlQueryItem(buffer, param);
      }

      buffer.writeln();
      buffer.writeln('${indent2}if !queryItems.isEmpty {');
      buffer.writeln('$indent2${_indent}components.queryItems = queryItems');
      buffer.writeln('$indent2}');
      buffer.writeln();
      buffer.writeln('${indent2}guard let url = components.url else {');
      buffer.writeln(
        '$indent2${_indent}throw AppIntentError.custom(code: "URL_CONSTRUCTION_FAILED", message: "Failed to construct URL for intent")',
      );
      buffer.writeln('$indent2}');
    }

    buffer.writeln();
    buffer.writeln('${indent2}await UIApplication.shared.open(url)');
    _writeReturnResult(buffer, info, indent2);
    buffer.writeln('$_indent}');
  }

  /// Writes a URL query item for a parameter.
  void _writeUrlQueryItem(StringBuffer buffer, IntentParamInfo param) {
    final isNullable = param.dartType.endsWith('?');
    final isDate =
        param.dartType == 'DateTime' || param.dartType == 'DateTime?';
    final isEntity = param.entityType != null;
    final isEnum = param.enumType != null;

    // Entity types: use .id for the URL value
    if (isEntity) {
      buffer.writeln(
        '$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: ${param.fieldName}.id))',
      );
      return;
    }

    // Enum types: use .rawValue for the URL value
    if (isEnum) {
      buffer.writeln(
        '$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: ${param.fieldName}.rawValue))',
      );
      return;
    }

    if (isNullable) {
      buffer.writeln('$_indent${_indent}if let ${param.fieldName} {');
      if (isDate) {
        buffer.writeln(
          '$_indent$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: ISO8601DateFormatter().string(from: ${param.fieldName})))',
        );
      } else {
        buffer.writeln(
          '$_indent$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: String(describing: ${param.fieldName})))',
        );
      }
      buffer.writeln('$_indent$_indent}');
    } else {
      if (isDate) {
        buffer.writeln(
          '$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: ISO8601DateFormatter().string(from: ${param.fieldName})))',
        );
      } else {
        buffer.writeln(
          '$_indent${_indent}queryItems.append(URLQueryItem(name: "${param.fieldName}", value: String(describing: ${param.fieldName})))',
        );
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

    // Import statements
    buffer.writeln('import AppIntents');
    if (info.indexed) {
      buffer.writeln('import CoreSpotlight');
    }
    if (info.effectiveCacheKey != null) {
      buffer.writeln('import app_intents');
    }
    buffer.writeln();

    // Entity body
    _generateEntityBody(buffer, info);

    return buffer.toString();
  }

  void _generateEntityBody(StringBuffer buffer, EntityInfo info) {
    // Availability and struct declaration
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct ${info.className}: AppEntity {');

    // Type display representation
    buffer.writeln(
      '$_indent'
      'static var typeDisplayRepresentation: TypeDisplayRepresentation =',
    );
    buffer.writeln(
      '$_indent$_indent'
      'TypeDisplayRepresentation(name: "${info.title}")',
    );
    buffer.writeln();

    // Default query
    buffer.writeln(
      '${_indent}static var defaultQuery = ${info.className}Query()',
    );
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

    // Generate EnumerableEntityQuery extension
    if (info.enumerable) {
      _writeEnumerableQueryExtension(buffer, info);
    }

    // Generate IndexedEntity extension
    if (info.indexed) {
      _writeIndexedEntityExtension(buffer, info);
    }
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

    buffer.writeln(
      '${_indent}var displayRepresentation: DisplayRepresentation {',
    );

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
    } else if (imageProp == null && info.displayImageName != null) {
      // Static display image from @EntitySpec (asset bundle image)
      args.add(
        'image: .init(named: "${info.displayImageName}", isTemplate: true)',
      );
    }

    if (imageProp != null && imageProp.dartType.endsWith('?')) {
      // Nullable image: use conditional logic with fallback
      buffer.writeln('$_indent${_indent}if let ${imageProp.fieldName} {');
      final argsWithImage = List<String>.from(args);
      argsWithImage.add('image: .init(systemName: ${imageProp.fieldName})');
      buffer.writeln(
        '$_indent$_indent${_indent}return DisplayRepresentation(${argsWithImage.join(', ')})',
      );
      buffer.writeln('$_indent$_indent}');
      // Fallback: use displayImageName if available
      final fallbackArgs = List<String>.from(args);
      if (info.displayImageName != null) {
        fallbackArgs.add(
          'image: .init(named: "${info.displayImageName}", isTemplate: true)',
        );
      }
      buffer.writeln(
        '$_indent${_indent}return DisplayRepresentation(${fallbackArgs.join(', ')})',
      );
    } else {
      buffer.writeln(
        '$_indent${_indent}return DisplayRepresentation(${args.join(', ')})',
      );
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

    final cacheKey = info.effectiveCacheKey;

    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct ${info.className}Query: EntityQuery {');

    if (cacheKey != null) {
      buffer.writeln(
        '$_indent/// App Group UserDefaults key written from Dart via setCachedValue.',
      );
      buffer.writeln('${_indent}static let cacheKey = "$cacheKey"');
      buffer.writeln();
    }

    // entities(for:) method
    buffer.writeln(
      '${_indent}func entities(for identifiers: [String]) async throws -> [${info.className}] {',
    );
    if (cacheKey != null) {
      final idField = idProp?.fieldName ?? 'id';
      buffer.writeln(
        '$_indent${_indent}if let cached = Self._readCachedEntities() {',
      );
      buffer.writeln(
        '$_indent$_indent${_indent}let filtered = cached.filter { identifiers.contains(\$0.$idField) }',
      );
      buffer.writeln('$_indent$_indent${_indent}if !filtered.isEmpty {');
      buffer.writeln('$_indent$_indent$_indent${_indent}return filtered');
      buffer.writeln('$_indent$_indent$_indent}');
      buffer.writeln('$_indent$_indent}');
    }
    buffer.writeln(
      '$_indent${_indent}let results = try await FlutterBridge.shared.queryEntities(',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}entityIdentifier: "${info.identifier}",',
    );
    buffer.writeln('$_indent$_indent${_indent}identifiers: identifiers');
    buffer.writeln('$_indent$_indent)');
    buffer.writeln('$_indent${_indent}return results.compactMap { dict in');
    _writeEntityDictMapping(
      buffer,
      info,
      idProp,
      titleProp,
      subtitleProp,
      imageProp,
    );
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.writeln();

    // suggestedEntities() method
    buffer.writeln(
      '${_indent}func suggestedEntities() async throws -> [${info.className}] {',
    );
    if (cacheKey != null) {
      buffer.writeln(
        '$_indent${_indent}if let cached = Self._readCachedEntities(), !cached.isEmpty {',
      );
      buffer.writeln('$_indent$_indent${_indent}return cached');
      buffer.writeln('$_indent$_indent}');
    }
    buffer.writeln(
      '$_indent${_indent}let results = try await FlutterBridge.shared.suggestedEntities(',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}entityIdentifier: "${info.identifier}"',
    );
    buffer.writeln('$_indent$_indent)');
    buffer.writeln('$_indent${_indent}return results.compactMap { dict in');
    _writeEntityDictMapping(
      buffer,
      info,
      idProp,
      titleProp,
      subtitleProp,
      imageProp,
    );
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');

    if (cacheKey != null) {
      buffer.writeln();
      _writeCachedEntityReader(
        buffer,
        info,
        idProp,
        titleProp,
        subtitleProp,
        imageProp,
      );
    }

    buffer.writeln('}');
  }

  /// Writes the static `_readCachedEntities()` helper used as the cold-start
  /// fallback. Returns nil when the key is missing, decode fails, or the
  /// cached payload is empty so callers can fall through to FlutterBridge.
  void _writeCachedEntityReader(
    StringBuffer buffer,
    EntityInfo info,
    EntityPropertyInfo? idProp,
    EntityPropertyInfo? titleProp,
    EntityPropertyInfo? subtitleProp,
    EntityPropertyInfo? imageProp,
  ) {
    buffer.writeln(
      '$_indent/// Reads cached entities from App Group UserDefaults.',
    );
    buffer.writeln(
      '$_indent/// Accepts either a JSON string payload or a pre-decoded array of maps.',
    );
    buffer.writeln(
      '${_indent}private static func _readCachedEntities() -> [${info.className}]? {',
    );
    buffer.writeln(
      '$_indent${_indent}guard let raw = AppIntentsPlugin.getCached(forKey: cacheKey) else {',
    );
    buffer.writeln('$_indent$_indent${_indent}return nil');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent${_indent}let dicts: [[String: Any]]');
    buffer.writeln(
      '$_indent${_indent}if let array = raw as? [[String: Any]] {',
    );
    buffer.writeln('$_indent$_indent${_indent}dicts = array');
    buffer.writeln(
      '$_indent$_indent} else if let jsonString = raw as? String,',
    );
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}let data = jsonString.data(using: .utf8),',
    );
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {',
    );
    buffer.writeln('$_indent$_indent${_indent}dicts = parsed');
    buffer.writeln('$_indent$_indent} else {');
    buffer.writeln('$_indent$_indent${_indent}return nil');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln(
      '$_indent${_indent}let entities: [${info.className}] = dicts.compactMap { dict in',
    );
    _writeEntityDictMapping(
      buffer,
      info,
      idProp,
      titleProp,
      subtitleProp,
      imageProp,
    );
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent${_indent}return entities');
    buffer.writeln('$_indent}');
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

    buffer.writeln(
      '$_indent$_indent${_indent}guard let $id = dict["$id"] as? String,',
    );
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}let $title = dict["$title"] as? String else {',
    );
    buffer.writeln('$_indent$_indent$_indent${_indent}return nil');
    buffer.writeln('$_indent$_indent$_indent}');

    if (subtitleProp != null) {
      final subtitle = subtitleProp.fieldName;
      buffer.writeln(
        '$_indent$_indent${_indent}let $subtitle = dict["$subtitle"] as? String',
      );
    }

    if (imageProp != null) {
      final image = imageProp.fieldName;
      buffer.writeln(
        '$_indent$_indent${_indent}let $image = dict["$image"] as? String',
      );
    }

    // Build initializer
    final initParts = <String>['$id: $id', '$title: $title'];
    if (subtitleProp != null) {
      initParts.add('${subtitleProp.fieldName}: ${subtitleProp.fieldName}');
    }
    if (imageProp != null) {
      initParts.add('${imageProp.fieldName}: ${imageProp.fieldName}');
    }
    buffer.writeln(
      '$_indent$_indent${_indent}return ${info.className}(${initParts.join(', ')})',
    );
  }

  /// Writes EnumerableEntityQuery extension.
  void _writeEnumerableQueryExtension(StringBuffer buffer, EntityInfo info) {
    buffer.writeln();
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('extension ${info.className}Query: EnumerableEntityQuery {');
    buffer.writeln(
      '${_indent}func allEntities() async throws -> [${info.className}] {',
    );
    buffer.writeln('$_indent${_indent}try await suggestedEntities()');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
  }

  /// Writes IndexedEntity extension with attributeSet.
  void _writeIndexedEntityExtension(StringBuffer buffer, EntityInfo info) {
    final titleProp = info.properties
        .where((p) => p.role == EntityPropertyRole.title)
        .firstOrNull;

    buffer.writeln();
    buffer.writeln('@available(iOS 26.0, *)');
    buffer.writeln('extension ${info.className}: IndexedEntity {');
    buffer.writeln(
      '${_indent}var attributeSet: CSSearchableItemAttributeSet {',
    );
    buffer.writeln(
      '$_indent${_indent}let attributes = CSSearchableItemAttributeSet()',
    );
    if (titleProp != null) {
      buffer.writeln(
        '$_indent${_indent}attributes.displayName = ${titleProp.fieldName}',
      );
    }
    buffer.writeln('$_indent${_indent}return attributes');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
  }

  /// Generates an AppShortcutsProvider struct from shortcut information.
  ///
  /// The generated struct includes:
  /// - `@available(iOS 17.0, *)` availability attribute
  /// - Static `appShortcuts` property with all configured shortcuts
  String generateAppShortcutsProvider(List<AppShortcutInfo> shortcuts) {
    final buffer = StringBuffer();
    buffer.writeln('import AppIntents');
    buffer.writeln();
    buffer.write(_generateShortcutsProviderBody(shortcuts));
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
    final needsBridge =
        entities.isNotEmpty ||
        intents.any(
          (i) =>
              i.urlScheme == null &&
              i.supportedModes != IntentModeType.foreground,
        );
    if (needsBridge) {
      buffer.writeln('import AppIntentsBridge');
    }
    if (intents.any((i) => i.urlScheme != null)) {
      buffer.writeln('import UIKit');
    }
    if (intents.any((i) => _hasFileParams(i))) {
      buffer.writeln('import UniformTypeIdentifiers');
    }
    if (intents.any((i) => _needsCacheImport(i)) ||
        entities.any((e) => e.effectiveCacheKey != null)) {
      buffer.writeln('import app_intents');
    }
    if (entities.any((e) => e.indexed)) {
      buffer.writeln('import CoreSpotlight');
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
      _generateIntentBody(buffer, intent);
      buffer.writeln();
      buffer.writeln();
    }

    // Generate entities (without individual imports)
    for (final entity in entities) {
      _generateEntityBody(buffer, entity);
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
    buffer.writeln(
      '$_indent'
      'static var title: LocalizedStringResource = "${info.title}"',
    );

    // Description (if present)
    if (info.description != null) {
      buffer.writeln(
        '$_indent'
        'static var description: IntentDescription =',
      );
      final escapedDesc = info.description!.replaceAll('\n', '\\n');
      buffer.writeln(
        '$_indent$_indent'
        'IntentDescription("$escapedDesc")',
      );
    }

    // supportedModes / openAppWhenRun
    if (_needsForeground(info)) {
      buffer.writeln();
      buffer.writeln('$_indent@available(iOS 26.0, *)');
      buffer.writeln(
        '${_indent}static var supportedModes: IntentModes { .foreground }',
      );
      buffer.writeln();
      buffer.writeln('${_indent}static var openAppWhenRun: Bool { true }');
    }

    // Parameter summary
    if (info.parameterSummary != null) {
      buffer.writeln();
      final summaryStr = _interpolateParameterSummary(info.parameterSummary!);
      buffer.writeln(
        '${_indent}static var parameterSummary: some ParameterSummary {',
      );
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

  /// Generates shortcuts provider body without import statement.
  String _generateShortcutsProviderBody(List<AppShortcutInfo> shortcuts) {
    final buffer = StringBuffer();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct AppShortcuts: AppShortcutsProvider {');
    buffer.writeln('$_indent@AppShortcutsBuilder');
    buffer.writeln('${_indent}static var appShortcuts: [AppShortcut] {');

    for (final shortcut in shortcuts) {
      buffer.writeln('$_indent${_indent}AppShortcut(');
      buffer.writeln(
        '$_indent$_indent${_indent}intent: ${shortcut.intentClassName}(),',
      );
      buffer.writeln('$_indent$_indent${_indent}phrases: [');
      for (var j = 0; j < shortcut.phrases.length; j++) {
        final phraseComma = j < shortcut.phrases.length - 1 ? ',' : '';
        final swiftPhrase = _convertPhraseToSwift(shortcut.phrases[j]);
        buffer.writeln(
          '$_indent$_indent$_indent$_indent"$swiftPhrase"$phraseComma',
        );
      }
      buffer.writeln('$_indent$_indent$_indent],');
      buffer.writeln(
        '$_indent$_indent${_indent}shortTitle: "${shortcut.shortTitle}",',
      );
      buffer.writeln(
        '$_indent$_indent${_indent}systemImageName: "${shortcut.systemImageName}"',
      );
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
    buffer.writeln(
      '${_indent}static var typeDisplayRepresentation: TypeDisplayRepresentation = "${info.title}"',
    );
    buffer.writeln();

    // caseDisplayRepresentations
    buffer.writeln(
      '${_indent}static var caseDisplayRepresentations: [${info.className}: DisplayRepresentation] = [',
    );
    for (var i = 0; i < info.cases.length; i++) {
      final c = info.cases[i];
      final comma = i < info.cases.length - 1 ? ',' : '';
      if (c.imageName != null) {
        buffer.writeln(
          '$_indent$_indent.${c.name}: .init(title: "${c.displayTitle}", '
          'image: .init(named: "${c.imageName}", isTemplate: true))$comma',
        );
      } else {
        buffer.writeln('$_indent$_indent.${c.name}: "${c.displayTitle}"$comma');
      }
    }
    buffer.writeln('$_indent]');

    buffer.write('}');
  }

  /// Converts `{paramName}` to `\(paramName)` for Swift dialog string interpolation.
  ///
  /// Also escapes double quotes to prevent conflicts with Swift string delimiters.
  String _interpolateDialogTemplate(
    String template,
    List<IntentParamInfo> params,
  ) {
    var result = template;
    // Escape double quotes for Swift string literals
    result = result.replaceAll('"', '\\"');
    for (final param in params) {
      result = result.replaceAll(
        '{${param.fieldName}}',
        '\\(${param.fieldName})',
      );
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

  /// Converts phrase placeholders to Swift string interpolation:
  /// - `{applicationName}` → `\(.applicationName)` (system variable)
  /// - `{paramName}` → `\(\.$paramName)` (intent parameter reference)
  String _convertPhraseToSwift(String phrase) {
    // First: convert {applicationName} to system variable syntax
    var result = phrase
        .replaceAll(r'${applicationName}', '\\(.applicationName)')
        .replaceAll('{applicationName}', '\\(.applicationName)');
    // Then: convert remaining {paramName} to parameter reference syntax
    result = result.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (match) => '\\(\\.\$${match.group(1)})',
    );
    return result;
  }
}
