import 'package:source_gen/source_gen.dart';

import '../experimental/experimental_features.dart';
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
  /// Creates a Swift generator.
  ///
  /// [experimental] controls opt-in WWDC26 code generation. It defaults to
  /// [ExperimentalFeatures.none], reproducing the stable output exactly.
  const SwiftGenerator({this.experimental = ExperimentalFeatures.none});

  /// Opt-in WWDC26 experimental code-generation configuration.
  final ExperimentalFeatures experimental;

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
  ///
  /// When [nativeRichTypes] is true (the experimental WWDC26 `#if` branch with
  /// the `rich-types` feature enabled), the "rich" Dart types are emitted as
  /// their native iOS 27 equivalents (`Duration`, `PersonNameComponents`).
  /// Otherwise they fall back to types the stable SDK supports
  /// (`Measurement<UnitDuration>`, `String`) — so the default and `#else`
  /// output always compiles.
  void _writeParameter(
    StringBuffer buffer,
    IntentParamInfo param, {
    bool nativeRichTypes = false,
  }) {
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
        _swiftParameterType(param, nativeRichTypes: nativeRichTypes);

    // Build @Parameter annotation
    final paramParts = <String>['title: "${param.title}"'];
    if (param.description != null) {
      paramParts.add('description: "${param.description}"');
    }
    buffer.writeln('$_indent@Parameter(${paramParts.join(', ')})');
    buffer.writeln('${_indent}var ${param.fieldName}: $swiftType');
  }

  /// The Swift `@Parameter` type for [param], accounting for the rich-type
  /// fallbacks. See [_writeParameter] for the [nativeRichTypes] semantics.
  String _swiftParameterType(
    IntentParamInfo param, {
    required bool nativeRichTypes,
  }) {
    final nullable = param.dartType.endsWith('?');
    if (_isDurationParam(param)) {
      final base = nativeRichTypes ? 'Duration' : 'Measurement<UnitDuration>';
      return nullable ? '$base?' : base;
    }
    if (_isPersonNameParam(param)) {
      // No PersonNameComponents @Parameter conformance on the stable SDK, so
      // the fallback is a plain formatted String.
      final base = nativeRichTypes ? 'PersonNameComponents' : 'String';
      return nullable ? '$base?' : base;
    }
    return dartTypeToSwiftType(param.dartType);
  }

  /// Whether [param] is a Dart `Duration` (nullable or not).
  bool _isDurationParam(IntentParamInfo param) =>
      param.dartType == 'Duration' || param.dartType == 'Duration?';

  /// Whether [param] is a Dart `PersonName` (nullable or not).
  bool _isPersonNameParam(IntentParamInfo param) =>
      param.dartType == 'PersonName' || param.dartType == 'PersonName?';

  /// Whether [param] is a WWDC26 "rich" parameter type (#53).
  bool _isRichTypeParam(IntentParamInfo param) =>
      _isDurationParam(param) || _isPersonNameParam(param);

  /// Whether [info] has any rich (#53) parameter.
  bool _hasRichTypeParams(IntentInfo info) =>
      info.parameters.any(_isRichTypeParam);

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

    // Duration types: use pre-serialized microseconds local (see
    // [_writeDurationSerializations]), so both Swift type branches agree.
    if (_isDurationParam(param)) {
      return '${param.fieldName}Micros';
    }

    // PersonName types: use pre-serialized component-map local (see
    // [_writePersonNameSerializations]).
    if (_isPersonNameParam(param)) {
      return '${param.fieldName}Name';
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
  void _writePerformMethod(
    StringBuffer buffer,
    IntentInfo info, {
    bool nativeRichTypes = false,
  }) {
    if (info.urlScheme != null) {
      _writeUrlSchemePerformMethod(buffer, info, nativeRichTypes);
    } else if (info.supportedModes == IntentModeType.foreground) {
      _writeCachePerformMethod(buffer, info, nativeRichTypes);
    } else {
      _writeFlutterBridgePerformMethod(buffer, info, nativeRichTypes);
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

  /// Writes `<field>Micros` locals converting Duration parameters to an `Int`
  /// number of microseconds.
  ///
  /// The native `Duration` (`#if` branch) and the `Measurement<UnitDuration>`
  /// fallback have different APIs, but both reduce to the same microseconds
  /// integer here — so the params dictionary and URL query items are identical
  /// across branches and the Dart handler stays branch-agnostic
  /// (`Duration(microseconds:)`).
  void _writeDurationSerializations(
    StringBuffer buffer,
    IntentInfo info,
    bool nativeRichTypes,
  ) {
    final indent2 = '$_indent$_indent';
    for (final param in info.parameters) {
      if (!_isDurationParam(param)) continue;
      final name = param.fieldName;
      final isNullable = param.isOptional || param.dartType.endsWith('?');
      if (isNullable) {
        final conv = _durationToMicrosExpression(r'$0', nativeRichTypes);
        buffer.writeln(
          '${indent2}let ${name}Micros: Int? = $name.map { $conv }',
        );
      } else {
        final conv = _durationToMicrosExpression(name, nativeRichTypes);
        buffer.writeln('${indent2}let ${name}Micros: Int = $conv');
      }
    }
  }

  /// The Swift expression converting [ref] (a `Duration` when [nativeRichTypes],
  /// otherwise a `Measurement<UnitDuration>`) to an `Int` of microseconds.
  String _durationToMicrosExpression(String ref, bool nativeRichTypes) {
    if (nativeRichTypes) {
      // 1 microsecond == 1_000_000_000_000 attoseconds.
      return 'Int($ref.components.seconds) * 1_000_000 + '
          'Int($ref.components.attoseconds / 1_000_000_000_000)';
    }
    return 'Int($ref.converted(to: .seconds).value * 1_000_000)';
  }

  /// The `PersonNameComponents` properties carried over the wire, in order.
  static const _personNameComponents = <String>[
    'givenName',
    'familyName',
    'middleName',
    'namePrefix',
    'nameSuffix',
    'nickname',
  ];

  /// Writes `<field>Name` locals converting PersonName parameters to a
  /// `[String: String]` map of the non-null components.
  ///
  /// The native `PersonNameComponents` (`#if` branch) reads each component; the
  /// `String` fallback (`#else` / default) carries only `givenName`. Both reduce
  /// to the same `[String: String]` shape so the params dictionary stays
  /// branch-agnostic and the Dart handler always uses `PersonName.fromMap`.
  void _writePersonNameSerializations(
    StringBuffer buffer,
    IntentInfo info,
    bool nativeRichTypes,
  ) {
    final indent2 = '$_indent$_indent';
    final indent3 = '$_indent$_indent$_indent';
    for (final param in info.parameters) {
      if (!_isPersonNameParam(param)) continue;
      final name = param.fieldName;
      final isNullable = param.isOptional || param.dartType.endsWith('?');

      if (!nativeRichTypes) {
        // Fallback: the Swift parameter is a plain formatted String.
        if (isNullable) {
          buffer.writeln(
            '${indent2}let ${name}Name: [String: String]? = '
            '$name.map { ["givenName": \$0] }',
          );
        } else {
          buffer.writeln(
            '${indent2}let ${name}Name: [String: String] = '
            '["givenName": $name]',
          );
        }
        continue;
      }

      // Native PersonNameComponents: collect every non-null component.
      if (isNullable) {
        buffer.writeln('${indent2}var ${name}Name: [String: String]? = nil');
        buffer.writeln('${indent2}if let $name {');
        buffer.writeln('${indent3}var components: [String: String] = [:]');
        for (final c in _personNameComponents) {
          buffer.writeln(
            '${indent3}if let v = $name.$c { components["$c"] = v }',
          );
        }
        buffer.writeln('$indent3${name}Name = components');
        buffer.writeln('$indent2}');
      } else {
        buffer.writeln('${indent2}var ${name}Name: [String: String] = [:]');
        for (final c in _personNameComponents) {
          buffer.writeln(
            '${indent2}if let v = $name.$c { ${name}Name["$c"] = v }',
          );
        }
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
  void _writeFlutterBridgePerformMethod(
    StringBuffer buffer,
    IntentInfo info,
    bool nativeRichTypes,
  ) {
    _writePerformSignature(buffer, info);
    _writeFileParamSerializations(buffer, info);
    _writeDurationSerializations(buffer, info, nativeRichTypes);
    _writePersonNameSerializations(buffer, info, nativeRichTypes);

    final indent2 = '$_indent$_indent';

    _writeFlutterBridgeInvoke(buffer, info, indent2);

    // Clean up temp files after FlutterBridge invoke completes
    _writeFileParamCleanup(buffer, info, indent2);

    _writeReturnResult(buffer, info, indent2);
    buffer.writeln('$_indent}');
  }

  /// Writes a `FlutterBridge.shared.invoke(...)` call at [baseIndent].
  ///
  /// Shared by the stable FlutterBridge perform() and the experimental
  /// long-running/cancellable perform(), where it sits inside a wrapping
  /// closure at a deeper indent.
  void _writeFlutterBridgeInvoke(
    StringBuffer buffer,
    IntentInfo info,
    String baseIndent,
  ) {
    buffer.writeln(
      '${baseIndent}let _ = try await FlutterBridge.shared.invoke(',
    );
    buffer.writeln('$baseIndent${_indent}intent: "${info.className}",');
    if (info.parameters.isEmpty) {
      buffer.writeln('$baseIndent${_indent}params: [:]');
    } else {
      buffer.writeln('$baseIndent${_indent}params: [');
      for (var i = 0; i < info.parameters.length; i++) {
        final param = info.parameters[i];
        final comma = i < info.parameters.length - 1 ? ',' : '';
        final valueExpr = _paramValueExpression(param);
        buffer.writeln(
          '$baseIndent$_indent$_indent"${param.fieldName}": $valueExpr$comma',
        );
      }
      buffer.writeln('$baseIndent$_indent]');
    }
    buffer.writeln('$baseIndent)');
  }

  /// Writes the experimental perform() that wraps the background invoke in
  /// `performBackgroundTask` and/or `withIntentCancellationHandler`.
  ///
  /// An intent that only restricts `executionTargets` or conforms to a schema
  /// (without long-running or cancellable) keeps its standard perform() for the
  /// configured execution mode.
  void _writeExperimentalPerformMethod(
    StringBuffer buffer,
    IntentInfo info,
    bool nativeRichTypes,
  ) {
    if (!info.longRunning && !info.cancellable) {
      _writePerformMethod(buffer, info, nativeRichTypes: nativeRichTypes);
      return;
    }

    _writePerformSignature(buffer, info);
    _writeFileParamSerializations(buffer, info);
    _writeDurationSerializations(buffer, info, nativeRichTypes);
    _writePersonNameSerializations(buffer, info, nativeRichTypes);

    final indent2 = '$_indent$_indent';
    final indent3 = '$_indent$_indent$_indent';

    // Long-running work uses performBackgroundTask; cancellable-only work uses
    // the cancellation handler. Both take the operation as a trailing closure.
    // When the intent is both long-running and cancellable, the combined
    // performBackgroundTask(operation:onCancel:) overload (which requires
    // CancellableIntent conformance) is used.
    final wrapper = info.longRunning
        ? 'performBackgroundTask'
        : 'withIntentCancellationHandler';
    buffer.writeln('${indent2}try await $wrapper {');
    _writeFlutterBridgeInvoke(buffer, info, indent3);
    if (info.cancellable) {
      buffer.writeln('$indent2} onCancel: { reason in');
      buffer.writeln(
        '$indent3// The system cancelled this intent; `reason` explains why.',
      );
      buffer.writeln('$indent3// Perform best-effort cleanup here.');
      buffer.writeln('$indent2}');
    } else {
      buffer.writeln('$indent2}');
    }

    // Clean up temp files after the background work completes.
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
  void _writeCachePerformMethod(
    StringBuffer buffer,
    IntentInfo info,
    bool nativeRichTypes,
  ) {
    _writePerformSignature(buffer, info);
    _writeFileParamSerializations(buffer, info);
    _writeDurationSerializations(buffer, info, nativeRichTypes);
    _writePersonNameSerializations(buffer, info, nativeRichTypes);

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
  void _writeUrlSchemePerformMethod(
    StringBuffer buffer,
    IntentInfo info,
    bool nativeRichTypes,
  ) {
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
      _writeDurationSerializations(buffer, info, nativeRichTypes);
      _writePersonNameSerializations(buffer, info, nativeRichTypes);
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

    // Duration types: use the pre-serialized microseconds local.
    if (_isDurationParam(param)) {
      final name = param.fieldName;
      if (isNullable) {
        buffer.writeln('$_indent${_indent}if let ${name}Micros {');
        buffer.writeln(
          '$_indent$_indent${_indent}queryItems.append(URLQueryItem(name: "$name", value: String(${name}Micros)))',
        );
        buffer.writeln('$_indent$_indent}');
      } else {
        buffer.writeln(
          '$_indent${_indent}queryItems.append(URLQueryItem(name: "$name", value: String(${name}Micros)))',
        );
      }
      return;
    }

    // PersonName types: a URL query value can't carry a structured name, so
    // carry the given name only (degraded — the structured channels are
    // FlutterBridge/cache). Reads from the pre-serialized component map.
    if (_isPersonNameParam(param)) {
      final name = param.fieldName;
      final indent3 = '$_indent$_indent$_indent';
      final guard = isNullable
          ? 'if let ${name}Name, let ${name}Given = ${name}Name["givenName"] {'
          : 'if let ${name}Given = ${name}Name["givenName"] {';
      buffer.writeln('$_indent$_indent$guard');
      buffer.writeln(
        '${indent3}queryItems.append(URLQueryItem(name: "$name", value: ${name}Given))',
      );
      buffer.writeln('$_indent$_indent}');
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
    if (info.indexed || info.hasIndexingKeys) {
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
    if (_usesExperimentalEntitySchema(info)) {
      // App Schema (#49) is iOS 27+: the entity, its query and extensions all
      // move to iOS 27 in the experimental branch. The #else branch keeps the
      // stable form so released-SDK builds without the flag still compile.
      buffer.writeln('#if APP_INTENTS_WWDC26');
      _writeEntityAndQuery(
        buffer,
        info,
        availability: 'iOS 27.0',
        indexedAvailability: 'iOS 27.0',
        schemaMacro: '@AppEntity(schema: .${info.schema})',
      );
      buffer.writeln();
      buffer.writeln('#else');
      _writeEntityAndQuery(
        buffer,
        info,
        availability: _stableEntityAvailability(info),
        indexedAvailability: 'iOS 26.0',
      );
      buffer.writeln();
      buffer.write('#endif');
    } else {
      _writeEntityAndQuery(
        buffer,
        info,
        availability: _stableEntityAvailability(info),
        indexedAvailability: 'iOS 26.0',
      );
    }

    // #55 ownership: a purely additive iOS 27 conformance, in its own #if block
    // (no #else needed — without the flag the entity just isn't ownership-aware).
    if (experimental.isEnabled(ExperimentalFeature.ownership) &&
        info.ownership != null) {
      buffer.writeln();
      buffer.writeln();
      _writeOwnershipExtension(buffer, info);
    }
  }

  /// Writes the experimental `OwnershipProvidingEntity` conformance extension.
  void _writeOwnershipExtension(StringBuffer buffer, EntityInfo info) {
    buffer.writeln('#if APP_INTENTS_WWDC26');
    buffer.writeln('@available(iOS 27.0, *)');
    buffer.writeln('extension ${info.className}: OwnershipProvidingEntity {');
    buffer.writeln(
      '${_indent}var ownership: EntityOwnership { ${_ownershipToSwift(info.ownership!)} }',
    );
    buffer.writeln('}');
    buffer.write('#endif');
  }

  /// Maps an ownership state to its Swift `EntityOwnership` member.
  String _ownershipToSwift(EntityOwnershipType ownership) {
    switch (ownership) {
      case EntityOwnershipType.unknown:
        return '.unknown';
      case EntityOwnershipType.shared:
        return '.shared';
      case EntityOwnershipType.public:
        return '.public';
    }
  }

  /// Whether [info] should emit the `@AppEntity(schema:)` macro.
  bool _usesExperimentalEntitySchema(EntityInfo info) =>
      experimental.isEnabled(ExperimentalFeature.appSchema) &&
      info.schema != null;

  /// Stable-SDK availability for an entity. Bumped to iOS 18.4 when any property
  /// uses semantic `indexingKey` (the `@Property(indexingKey:)` init is 18.4+).
  String _stableEntityAvailability(EntityInfo info) =>
      info.hasIndexingKeys ? 'iOS 18.4' : 'iOS 17.0';

  /// Emits the entity struct, its query struct and any extensions at the given
  /// availability, optionally prefixing the struct with an App Schema macro.
  void _writeEntityAndQuery(
    StringBuffer buffer,
    EntityInfo info, {
    required String availability,
    required String indexedAvailability,
    String? schemaMacro,
  }) {
    buffer.writeln('@available($availability, *)');
    if (schemaMacro != null) {
      buffer.writeln(schemaMacro);
    }
    buffer.writeln('struct ${info.className}: AppEntity {');

    buffer.writeln(
      '$_indent'
      'static var typeDisplayRepresentation: TypeDisplayRepresentation =',
    );
    buffer.writeln(
      '$_indent$_indent'
      'TypeDisplayRepresentation(name: "${info.title}")',
    );
    buffer.writeln();

    buffer.writeln(
      '${_indent}static var defaultQuery = ${info.className}Query()',
    );
    buffer.writeln();

    _writeEntityProperties(buffer, info);

    // The @Property wrapper has no init(wrappedValue:), so an entity that
    // exposes properties needs an explicit initializer; exposed properties get
    // defaults so the role-only construction in the query keeps compiling.
    if (info.hasExposedProperties) {
      buffer.writeln();
      _writeEntityInit(buffer, info);
    }

    buffer.writeln();
    _writeDisplayRepresentation(buffer, info);

    buffer.writeln('}');
    buffer.writeln();

    _writeQueryStruct(buffer, info, availability);

    if (info.enumerable) {
      _writeEnumerableQueryExtension(buffer, info, availability);
    }

    if (info.indexed) {
      _writeIndexedEntityExtension(buffer, info, indexedAvailability);
    }
  }

  /// Writes the entity's stored properties, using `@Property(...)` for fields
  /// marked with `@EntityProperty`.
  void _writeEntityProperties(StringBuffer buffer, EntityInfo info) {
    for (final prop in info.properties) {
      final swiftType = dartTypeToSwiftType(prop.dartType);
      if (prop.exposeAsProperty) {
        buffer.writeln('$_indent${_propertyAttribute(prop)}');
      }
      buffer.writeln('${_indent}var ${prop.fieldName}: $swiftType');
    }
  }

  /// Builds the `@Property(...)` attribute for an exposed property. Falls back
  /// to `@Property(title:)` (the bare `@Property` init is unavailable).
  String _propertyAttribute(EntityPropertyInfo prop) {
    final args = <String>[];
    if (prop.propertyTitle != null) {
      args.add('title: "${prop.propertyTitle}"');
    }
    if (prop.indexingKey != null) {
      args.add('indexingKey: \\.${prop.indexingKey}');
    }
    if (args.isEmpty) {
      args.add('title: "${prop.fieldName}"');
    }
    return '@Property(${args.join(', ')})';
  }

  /// Writes an explicit initializer covering all properties. Exposed properties
  /// receive type-appropriate defaults so callers that only pass the role
  /// fields still compile.
  void _writeEntityInit(StringBuffer buffer, EntityInfo info) {
    // The initializer's parameter order MUST match the construction call site
    // (`_writeEntityDictMapping`), which lists role fields first
    // (id, title, subtitle, image) then exposed properties. Swift requires the
    // labeled arguments a caller *does* provide to appear in declaration order
    // even when the omitted ones have defaults, so emitting parameters in Dart
    // field-declaration order would produce non-compiling Swift whenever the
    // field order differs from the role order.
    final ordered = _initOrderedProperties(info);
    final params = ordered
        .map((prop) {
          final swiftType = dartTypeToSwiftType(prop.dartType);
          if (prop.exposeAsProperty) {
            return '${prop.fieldName}: $swiftType = '
                '${_defaultForSwiftType(swiftType, prop.fieldName)}';
          }
          return '${prop.fieldName}: $swiftType';
        })
        .join(', ');
    buffer.writeln('${_indent}init($params) {');
    for (final prop in ordered) {
      buffer.writeln(
        '$_indent${_indent}self.${prop.fieldName} = ${prop.fieldName}',
      );
    }
    buffer.writeln('$_indent}');
  }

  /// Properties in the order the generated initializer and every construction
  /// call site list them: the role fields first (id, title, subtitle, image),
  /// then exposed `@EntityProperty` fields in declaration order. Mirrors the
  /// argument order built in [_writeEntityDictMapping] so the two cannot drift.
  List<EntityPropertyInfo> _initOrderedProperties(EntityInfo info) {
    final ordered = <EntityPropertyInfo>[];
    for (final role in const [
      EntityPropertyRole.id,
      EntityPropertyRole.title,
      EntityPropertyRole.subtitle,
      EntityPropertyRole.image,
    ]) {
      final prop = info.properties.where((p) => p.role == role).firstOrNull;
      if (prop != null) ordered.add(prop);
    }
    // `_extractProperties` keeps only role-annotated or exposed fields, so every
    // remaining (role == none) property is an exposed @EntityProperty and is
    // given a default below — the call site may safely omit it.
    ordered.addAll(
      info.properties.where((p) => p.role == EntityPropertyRole.none),
    );
    return ordered;
  }

  /// A literal default value for an exposed property's Swift type, used so a
  /// construction call site that only passes the role fields (and exposed
  /// String properties) still compiles.
  ///
  /// Throws for types that have no synthesizable default — those cannot be
  /// exposed via `@EntityProperty`. Note: non-String exposed properties (e.g.
  /// `Date`) compile via this default but are not populated from the cached
  /// dict (the query reads only String properties), so they always take the
  /// default value at construction.
  String _defaultForSwiftType(String swiftType, String fieldName) {
    if (swiftType.endsWith('?')) return 'nil';
    switch (swiftType) {
      case 'Int':
        return '0';
      case 'Double':
        return '0';
      case 'Bool':
        return 'false';
      case 'String':
        return '""';
      case 'Date':
        return 'Date()';
      default:
        throw InvalidGenerationSourceError(
          'Cannot expose entity property `$fieldName` of Swift type '
          '`$swiftType` via @EntityProperty: no default value can be '
          'synthesized for the generated initializer. Expose only '
          'String/int/double/bool/DateTime (or their nullable forms).',
        );
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
  void _writeQueryStruct(
    StringBuffer buffer,
    EntityInfo info, [
    String availability = 'iOS 17.0',
  ]) {
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

    buffer.writeln('@available($availability, *)');
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

    // Exposed @Property string fields (role: none) are read from the dict so
    // semantic content is populated; other types fall back to the init default.
    final exposedStringProps = info.properties.where(
      (p) =>
          p.exposeAsProperty &&
          p.role == EntityPropertyRole.none &&
          (p.dartType == 'String' || p.dartType == 'String?'),
    );
    for (final prop in exposedStringProps) {
      buffer.writeln(
        '$_indent$_indent${_indent}let ${prop.fieldName} = dict["${prop.fieldName}"] as? String',
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
    for (final prop in exposedStringProps) {
      final value = prop.dartType.endsWith('?')
          ? prop.fieldName
          : '${prop.fieldName} ?? ""';
      initParts.add('${prop.fieldName}: $value');
    }
    buffer.writeln(
      '$_indent$_indent${_indent}return ${info.className}(${initParts.join(', ')})',
    );
  }

  /// Writes EnumerableEntityQuery extension.
  void _writeEnumerableQueryExtension(
    StringBuffer buffer,
    EntityInfo info, [
    String availability = 'iOS 17.0',
  ]) {
    buffer.writeln();
    buffer.writeln('@available($availability, *)');
    buffer.writeln('extension ${info.className}Query: EnumerableEntityQuery {');
    buffer.writeln(
      '${_indent}func allEntities() async throws -> [${info.className}] {',
    );
    buffer.writeln('$_indent${_indent}try await suggestedEntities()');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
  }

  /// Writes IndexedEntity extension with attributeSet.
  void _writeIndexedEntityExtension(
    StringBuffer buffer,
    EntityInfo info, [
    String availability = 'iOS 26.0',
  ]) {
    final titleProp = info.properties
        .where((p) => p.role == EntityPropertyRole.title)
        .firstOrNull;

    buffer.writeln();
    buffer.writeln('@available($availability, *)');
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
    if (entities.any((e) => e.indexed || e.hasIndexingKeys)) {
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
  ///
  /// When experimental execution control is enabled for this intent, emits two
  /// variants guarded by a compilation condition: the WWDC26 form inside
  /// `#if APP_INTENTS_WWDC26` and the stable form inside `#else`, so projects
  /// that build against a released SDK (without the `APP_INTENTS_WWDC26` flag)
  /// still compile.
  void _generateIntentBody(StringBuffer buffer, IntentInfo info) {
    if (_usesExperimentalIntent(info)) {
      buffer.writeln('#if APP_INTENTS_WWDC26');
      _generateExperimentalIntentBody(buffer, info);
      buffer.writeln();
      buffer.writeln('#else');
      _generateStableIntentBody(buffer, info);
      buffer.writeln();
      buffer.write('#endif');
    } else {
      _generateStableIntentBody(buffer, info);
    }
  }

  /// Whether [info] uses any experimental WWDC26 feature (execution control or
  /// App Schema), which triggers dual-branch emission.
  bool _usesExperimentalIntent(IntentInfo info) =>
      _usesExperimentalExecution(info) ||
      _usesExperimentalSchema(info) ||
      _usesExperimentalRichTypes(info);

  /// Whether [info] should emit the native rich (#53) parameter forms
  /// (`rich-types` feature enabled and at least one rich parameter). This
  /// triggers dual-branch emission so the stable `#else` keeps the
  /// `Measurement<UnitDuration>` / `String` fallbacks.
  bool _usesExperimentalRichTypes(IntentInfo info) =>
      experimental.isEnabled(ExperimentalFeature.richTypes) &&
      _hasRichTypeParams(info);

  /// Whether [info] should emit the experimental WWDC26 execution-control form.
  ///
  /// Requires both the opt-in `long-running` feature to be enabled and the
  /// intent to actually declare one of the experimental execution attributes.
  bool _usesExperimentalExecution(IntentInfo info) {
    if (!experimental.isEnabled(ExperimentalFeature.longRunning)) return false;
    return info.longRunning ||
        info.cancellable ||
        (info.executionTargets != null && info.executionTargets!.isNotEmpty);
  }

  /// Whether [info] should emit the `@AppIntent(schema:)` macro (app-schema
  /// feature enabled and a schema declared).
  bool _usesExperimentalSchema(IntentInfo info) =>
      experimental.isEnabled(ExperimentalFeature.appSchema) &&
      info.schema != null;

  /// Generates the stable (released-SDK) intent struct.
  void _generateStableIntentBody(StringBuffer buffer, IntentInfo info) {
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct ${info.className}: AppIntent {');

    _writeIntentTitle(buffer, info);
    _writeIntentDescription(buffer, info);

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

    _writeParameterSummary(buffer, info);
    _writeIntentParameters(buffer, info);

    buffer.writeln();
    _writePerformMethod(buffer, info);

    buffer.write('}');
  }
  // NOTE: the stable body never emits native Duration; a Duration parameter
  // here is always the `Measurement<UnitDuration>` fallback (nativeRichTypes
  // defaults to false), so the default and `#else` output compiles on the
  // released SDK.

  /// Generates the experimental WWDC26 intent struct.
  ///
  /// Conforms to `LongRunningIntent` and/or `CancellableIntent` as declared,
  /// emits `allowedExecutionTargets`, and wraps the background work in
  /// `performBackgroundTask` / `withIntentCancellationHandler`. The whole struct
  /// is gated at the minimum OS version the chosen APIs require (so we avoid the
  /// problem of conditionally conforming to a newer-OS protocol).
  void _generateExperimentalIntentBody(StringBuffer buffer, IntentInfo info) {
    final hasExecutionTargets =
        info.executionTargets != null && info.executionTargets!.isNotEmpty;
    final hasSchema = _usesExperimentalSchema(info);
    final nativeRichTypes = _usesExperimentalRichTypes(info);

    final conformances = <String>['AppIntent'];
    if (info.longRunning) conformances.add('LongRunningIntent');
    if (info.cancellable) conformances.add('CancellableIntent');

    // LongRunningIntent, IntentExecutionTargets, App Schema and native
    // `Duration` parameters are iOS 27+; CancellableIntent on its own is
    // iOS 26.4+.
    final minVersion =
        (info.longRunning ||
            hasExecutionTargets ||
            hasSchema ||
            nativeRichTypes)
        ? '27.0'
        : '26.4';

    buffer.writeln('@available(iOS $minVersion, *)');
    // The @AppIntent(schema:) macro adds the AppIntent conformance itself, but
    // the explicit ": AppIntent" is redundant-and-OK and keeps the stable/
    // experimental structs structurally identical.
    if (hasSchema) {
      buffer.writeln('@AppIntent(schema: .${info.schema})');
    }
    buffer.writeln('struct ${info.className}: ${conformances.join(', ')} {');

    _writeIntentTitle(buffer, info);
    _writeIntentDescription(buffer, info);

    if (hasExecutionTargets) {
      final members = info.executionTargets!
          .map(_executionTargetToSwift)
          .join(', ');
      buffer.writeln();
      buffer.writeln(
        '${_indent}static var allowedExecutionTargets: IntentExecutionTargets { [$members] }',
      );
    }

    _writeParameterSummary(buffer, info);
    _writeIntentParameters(buffer, info, nativeRichTypes: nativeRichTypes);

    buffer.writeln();
    _writeExperimentalPerformMethod(buffer, info, nativeRichTypes);

    buffer.write('}');
  }

  /// Writes the static `title` declaration.
  void _writeIntentTitle(StringBuffer buffer, IntentInfo info) {
    buffer.writeln(
      '$_indent'
      'static var title: LocalizedStringResource = "${info.title}"',
    );
  }

  /// Writes the static `description` declaration when present.
  void _writeIntentDescription(StringBuffer buffer, IntentInfo info) {
    if (info.description == null) return;
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

  /// Writes the `parameterSummary` declaration when present.
  void _writeParameterSummary(StringBuffer buffer, IntentInfo info) {
    if (info.parameterSummary == null) return;
    buffer.writeln();
    final summaryStr = _interpolateParameterSummary(info.parameterSummary!);
    buffer.writeln(
      '${_indent}static var parameterSummary: some ParameterSummary {',
    );
    buffer.writeln('$_indent${_indent}Summary("$summaryStr")');
    buffer.writeln('$_indent}');
  }

  /// Writes the `@Parameter` declarations when present.
  void _writeIntentParameters(
    StringBuffer buffer,
    IntentInfo info, {
    bool nativeRichTypes = false,
  }) {
    if (info.parameters.isEmpty) return;
    buffer.writeln();
    for (final param in info.parameters) {
      _writeParameter(buffer, param, nativeRichTypes: nativeRichTypes);
    }
  }

  /// Maps an execution target to its Swift `IntentExecutionTargets` member.
  String _executionTargetToSwift(IntentExecutionTargetType target) {
    switch (target) {
      case IntentExecutionTargetType.main:
        return '.main';
      case IntentExecutionTargetType.appIntentsExtension:
        return '.appIntentsExtension';
      case IntentExecutionTargetType.widgetKitExtension:
        return '.widgetKitExtension';
    }
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
  ///
  /// When the `app-schema` experimental feature is enabled and a schema is set,
  /// emits the `@AppEnum(schema:)` form in `#if APP_INTENTS_WWDC26` and the
  /// stable form in `#else`.
  void _generateEnumBody(StringBuffer buffer, EnumInfo info) {
    if (experimental.isEnabled(ExperimentalFeature.appSchema) &&
        info.schema != null) {
      buffer.writeln('#if APP_INTENTS_WWDC26');
      _writeEnumStruct(
        buffer,
        info,
        availability: 'iOS 27.0',
        schemaMacro: '@AppEnum(schema: .${info.schema})',
      );
      buffer.writeln();
      buffer.writeln('#else');
      _writeEnumStruct(buffer, info, availability: 'iOS 17.0');
      buffer.writeln();
      buffer.write('#endif');
    } else {
      _writeEnumStruct(buffer, info, availability: 'iOS 17.0');
    }
  }

  /// Writes the enum declaration at the given availability, optionally prefixed
  /// with an App Schema macro.
  void _writeEnumStruct(
    StringBuffer buffer,
    EnumInfo info, {
    required String availability,
    String? schemaMacro,
  }) {
    buffer.writeln('@available($availability, *)');
    if (schemaMacro != null) {
      buffer.writeln(schemaMacro);
    }
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
