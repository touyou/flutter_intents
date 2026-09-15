import 'package:source_gen/source_gen.dart';

import '../experimental/experimental_features.dart';
import '../models/entity_info.dart';
import '../models/enum_info.dart';
import '../models/intent_info.dart';
import '../models/union_info.dart';
import 'placeholders.dart';

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

  /// Suffix appended to an entity identifier to form the value-query identifier
  /// an `importing:` closure calls (#129).
  ///
  /// Import reuses #51's value-query bridge instead of adding a second
  /// round-trip shape, so the two have to be told apart by identifier. This
  /// literal is **mirrored in Dart** by
  /// `AppIntents.registerValueImportHandler` — changing it means changing both.
  static const _importQuerySuffix = '#import';

  /// Reserved params key carrying the execution id to Dart (#130, #131).
  ///
  /// Mirrored by `intentExecutionIdKey` in the plugin, which strips it before
  /// the handler sees the params — changing it means changing both.
  static const _executionIdKey = '_executionId';

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
    // `.result(view:)` comes from the _AppIntents_SwiftUI overlay, and the
    // snippet view has to be emitted alongside the intent that constructs it —
    // otherwise this single-intent output references an undefined type.
    if (info.snippet != null) {
      buffer.writeln('import SwiftUI');
    }
    buffer.writeln();

    if (info.snippet != null) {
      _writeSnippetView(buffer, info);
      buffer.writeln();
      buffer.writeln();
    }
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
    if (_isEntityCollectionParam(param)) {
      // Native EntityCollection<Entity> (iOS 27) vs. a plain [Entity] array
      // fallback. Both yield the same `[String]` identifier wire.
      final entity = param.entityCollectionType!;
      final base = nativeRichTypes ? 'EntityCollection<$entity>' : '[$entity]';
      return nullable ? '$base?' : base;
    }
    if (_isUnionParam(param)) {
      // Native @UnionValue enum (iOS 27) vs. a lossy fallback to the first
      // case's entity type (no stable union-parameter representation exists).
      final union = param.unionInfo!;
      final base = nativeRichTypes
          ? union.className
          : union.cases.first.entityType;
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

  /// Whether [param] is an entity-collection parameter (#53).
  bool _isEntityCollectionParam(IntentParamInfo param) =>
      param.entityCollectionType != null;

  /// Whether [param] is a union-value parameter (#53).
  bool _isUnionParam(IntentParamInfo param) => param.unionInfo != null;

  /// Whether [param] is a WWDC26 "rich" parameter type (#53).
  bool _isRichTypeParam(IntentParamInfo param) =>
      _isDurationParam(param) ||
      _isPersonNameParam(param) ||
      _isEntityCollectionParam(param) ||
      _isUnionParam(param);

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

    // Entity-collection types: use pre-serialized identifier list (see
    // [_writeEntityCollectionSerializations]).
    if (_isEntityCollectionParam(param)) {
      return '${param.fieldName}Ids';
    }

    // Union types: use pre-serialized tagged map (see
    // [_writeUnionSerializations]).
    if (_isUnionParam(param)) {
      return '${param.fieldName}Union';
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

  /// Returns the Swift return type for a perform() method based on what the
  /// result carries: a dialog, a snippet view, both, or neither.
  String _performReturnType(IntentInfo info) {
    final parts = <String>['some IntentResult'];
    if (info.resultDialogTemplate != null) parts.add('ProvidesDialog');
    if (info.snippet != null) parts.add('ShowsSnippetView');
    return parts.join(' & ');
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

  /// Writes `<field>State` locals for params declared with
  /// `@IntentParam(useValueState: true)`. The state is read from the iOS 18.2+
  /// `$<field>.valueState` projection at runtime; on older OS versions the
  /// local stays `nil` (the Dart handler treats absent state as best-effort
  /// optional, matching pre-18.2 behavior).
  ///
  /// Wire format: `"unset"` (caller didn't specify), `"set"` (caller provided a
  /// value), `"cleared"` (caller explicitly cleared an optional). Both `"set"`
  /// and `"cleared"` map to `.set(...)` in the SDK; we split them by inspecting
  /// `Optional.some` / `Optional.none` so update intents can distinguish "leave
  /// it alone" from "set this field to null".
  void _writeValueStateSerializations(StringBuffer buffer, IntentInfo info) {
    final indent2 = '$_indent$_indent';
    for (final param in info.parameters) {
      if (!param.useValueState) continue;
      buffer.writeln('${indent2}var ${param.fieldName}State: String?');
      buffer.writeln('${indent2}if #available(iOS 18.2, *) {');
      buffer.writeln(
        '$indent2$_indent'
        r'switch $'
        '${param.fieldName}.valueState {',
      );
      buffer.writeln(
        '$indent2$_indent'
        'case .unset:',
      );
      buffer.writeln(
        '$indent2$_indent$_indent${param.fieldName}State = "unset"',
      );
      buffer.writeln(
        '$indent2$_indent'
        'case .set(.some):',
      );
      buffer.writeln('$indent2$_indent$_indent${param.fieldName}State = "set"');
      buffer.writeln(
        '$indent2$_indent'
        'case .set(.none):',
      );
      buffer.writeln(
        '$indent2$_indent$_indent${param.fieldName}State = "cleared"',
      );
      // `IntentParameter.ValueState` is marked non-frozen, so Swift 6 turns
      // exhaustive switches into errors. Future-proof with @unknown default.
      buffer.writeln(
        '$indent2$_indent'
        '@unknown default:',
      );
      buffer.writeln('$indent2$_indent$_indent${param.fieldName}State = nil');
      buffer.writeln('$indent2$_indent}');
      buffer.writeln('$indent2}');
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

  /// Writes `<field>Ids` locals converting entity-collection parameters to a
  /// `[String]` of identifiers.
  ///
  /// Native `EntityCollection` (`#if`) exposes `.identifiers`; the `[Entity]`
  /// array fallback maps `.id`. Both reduce to the same `[String]` so the params
  /// dictionary stays branch-agnostic (Dart handler receives a `List<String>`).
  void _writeEntityCollectionSerializations(
    StringBuffer buffer,
    IntentInfo info,
    bool nativeRichTypes,
  ) {
    final indent2 = '$_indent$_indent';
    for (final param in info.parameters) {
      if (!_isEntityCollectionParam(param)) continue;
      final name = param.fieldName;
      final isNullable = param.isOptional || param.dartType.endsWith('?');
      final access = nativeRichTypes ? '.identifiers' : '.map { \$0.id }';
      if (isNullable) {
        buffer.writeln('${indent2}let ${name}Ids: [String]? = $name?$access');
      } else {
        buffer.writeln('${indent2}let ${name}Ids: [String] = $name$access');
      }
    }
  }

  /// Writes `<field>Union` locals converting union parameters to a tagged
  /// `["_type": <case>, "id": <entityId>]` map.
  ///
  /// Native (`#if`) switches over the `@UnionValue enum` cases. The fallback
  /// (`#else` / default) is **lossy**: the parameter is the first case's entity
  /// type, so it always tags as the first case. Both shapes feed the same Dart
  /// `<Union>FromMap` factory.
  void _writeUnionSerializations(
    StringBuffer buffer,
    IntentInfo info,
    bool nativeRichTypes,
  ) {
    final indent2 = '$_indent$_indent';
    final indent3 = '$_indent$_indent$_indent';
    for (final param in info.parameters) {
      if (!_isUnionParam(param)) continue;
      final name = param.fieldName;
      final union = param.unionInfo!;
      final isNullable = param.isOptional || param.dartType.endsWith('?');

      if (!nativeRichTypes) {
        final first = union.cases.first.dartClassName;
        if (isNullable) {
          buffer.writeln(
            '${indent2}let ${name}Union: [String: String]? = '
            '$name.map { ["_type": "$first", "id": \$0.id] }',
          );
        } else {
          buffer.writeln(
            '${indent2}let ${name}Union: [String: String] = '
            '["_type": "$first", "id": $name.id]',
          );
        }
        continue;
      }

      // Native: switch over the enum cases.
      if (isNullable) {
        buffer.writeln('${indent2}var ${name}Union: [String: String]? = nil');
        buffer.writeln('${indent2}if let $name {');
        buffer.writeln('${indent3}switch $name {');
        for (final c in union.cases) {
          buffer.writeln(
            '${indent3}case .${c.swiftCaseName}(let e): '
            '${name}Union = ["_type": "${c.dartClassName}", "id": e.id]',
          );
        }
        buffer.writeln('$indent3}');
        buffer.writeln('$indent2}');
      } else {
        buffer.writeln('${indent2}let ${name}Union: [String: String]');
        buffer.writeln('${indent2}switch $name {');
        for (final c in union.cases) {
          buffer.writeln(
            '${indent2}case .${c.swiftCaseName}(let e): '
            '${name}Union = ["_type": "${c.dartClassName}", "id": e.id]',
          );
        }
        buffer.writeln('$indent2}');
      }
    }
  }

  /// Writes the return statement (with optional dialog).
  ///
  /// A plain `resultDialogTemplate` becomes `.init("…")`. Adding
  /// `resultDialogSupportingTemplate` switches to `IntentDialog(full:supporting:)`
  /// — the spoken line and the on-screen line, so a voice-only answer can carry
  /// context a reader already has on screen. `resultDialogSystemImageName` adds
  /// the symbol, but those initializers are iOS 17.2+ while generated intents
  /// target iOS 17.0, so the symbol form is built behind `if #available` with
  /// the symbol-less dialog as the fallback.
  void _writeReturnResult(StringBuffer buffer, IntentInfo info, String indent) {
    final view = info.snippet == null ? null : _snippetViewExpression(info);

    if (info.resultDialogTemplate == null) {
      buffer.writeln(
        view == null
            ? '${indent}return .result()'
            : '${indent}return .result(view: $view)',
      );
      return;
    }

    final full = _interpolateDialogTemplate(
      info.resultDialogTemplate!,
      info.parameters,
      info: info,
    );
    final supporting = info.resultDialogSupportingTemplate == null
        ? null
        : _interpolateDialogTemplate(
            info.resultDialogSupportingTemplate!,
            info.parameters,
            info: info,
          );
    final symbol = info.resultDialogSystemImageName;

    if (symbol == null) {
      final expression = supporting == null
          ? '.init("$full")'
          : 'IntentDialog(full: "$full", supporting: "$supporting")';
      buffer.writeln(
        view == null
            ? '${indent}return .result(dialog: $expression)'
            : '${indent}return .result(dialog: $expression, view: $view)',
      );
      return;
    }

    final withSymbol = supporting == null
        ? 'IntentDialog(full: "$full", systemImageName: "$symbol")'
        : 'IntentDialog(full: "$full", supporting: "$supporting", '
              'systemImageName: "$symbol")';
    final withoutSymbol = supporting == null
        ? 'IntentDialog("$full")'
        : 'IntentDialog(full: "$full", supporting: "$supporting")';

    buffer.writeln('${indent}let dialog: IntentDialog');
    buffer.writeln('${indent}if #available(iOS 17.2, *) {');
    buffer.writeln('$indent${_indent}dialog = $withSymbol');
    buffer.writeln('$indent} else {');
    buffer.writeln('$indent${_indent}dialog = $withoutSymbol');
    buffer.writeln('$indent}');
    buffer.writeln(
      view == null
          ? '${indent}return .result(dialog: dialog)'
          : '${indent}return .result(dialog: dialog, view: $view)',
    );
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
    _writeEntityCollectionSerializations(buffer, info, nativeRichTypes);
    _writeUnionSerializations(buffer, info, nativeRichTypes);
    _writeValueStateSerializations(buffer, info);

    final indent2 = '$_indent$_indent';

    // #131: a requestable parameter needs an execution scope even here — the
    // API is iOS 16 and nothing about it is experimental.
    final withScope = _needsExecutionScope(info, experimental: false);
    if (withScope) {
      _writeExecutionScope(buffer, info, withProgress: false);
    }

    _writeFlutterBridgeInvoke(
      buffer,
      info,
      indent2,
      withExecutionId: withScope,
    );

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
    String baseIndent, {
    String? invokePrefix,
    bool writeResultLocals = true,
    bool withExecutionId = false,
  }) {
    final hasValueState = info.parameters.any((p) => p.useValueState);
    if (hasValueState) {
      // When any param opts into IntentParameter.ValueState (#52), build the
      // dict imperatively so the optional `<field>State` local can be omitted
      // when nil (iOS < 18.2). This matches the cache-mode wire shape — the
      // Dart handler can distinguish "no state info" (absent key) from a
      // present state, instead of having to disambiguate `NSNull` from a
      // legitimately-cleared value.
      buffer.writeln('${baseIndent}var params: [String: Any] = [');
      for (var i = 0; i < info.parameters.length; i++) {
        final param = info.parameters[i];
        final comma = i < info.parameters.length - 1 ? ',' : '';
        final valueExpr = _paramValueExpression(param);
        buffer.writeln(
          '$baseIndent$_indent"${param.fieldName}": $valueExpr$comma',
        );
      }
      buffer.writeln('$baseIndent]');
      if (withExecutionId) {
        buffer.writeln('${baseIndent}params["$_executionIdKey"] = executionId');
      }
      for (final param in info.parameters) {
        if (!param.useValueState) continue;
        buffer.writeln(
          '${baseIndent}if let ${param.fieldName}StateValue = ${param.fieldName}State {',
        );
        buffer.writeln(
          '$baseIndent${_indent}params["${param.fieldName}State"] = ${param.fieldName}StateValue',
        );
        buffer.writeln('$baseIndent}');
      }
      buffer.writeln(
        '$baseIndent${invokePrefix ?? _invokeBinding(info)} '
        'try await FlutterBridge.shared.invoke(',
      );
      buffer.writeln('$baseIndent${_indent}intent: "${info.identifier}",');
      buffer.writeln('$baseIndent${_indent}params: params');
      buffer.writeln('$baseIndent)');
      if (writeResultLocals) {
        _writeSnippetResultLocals(buffer, info, baseIndent);
      }
      return;
    }

    // Fast path: no ValueState opt-in → emit the dict literal inline as before.
    buffer.writeln(
      '$baseIndent${invokePrefix ?? _invokeBinding(info)} '
      'try await FlutterBridge.shared.invoke(',
    );
    // The bridge key must be the @IntentSpec identifier: that is what the
    // generated Dart `registerIntentHandler` registers under, and the plugin
    // looks the handler up by the string it is handed. Cache mode already used
    // the identifier; this path used the Swift struct name, so no FlutterBridge
    // intent could ever find its handler.
    buffer.writeln('$baseIndent${_indent}intent: "${info.identifier}",');
    if (info.parameters.isEmpty && !withExecutionId) {
      buffer.writeln('$baseIndent${_indent}params: [:]');
    } else {
      buffer.writeln('$baseIndent${_indent}params: [');
      for (var i = 0; i < info.parameters.length; i++) {
        final param = info.parameters[i];
        final last = i == info.parameters.length - 1 && !withExecutionId;
        final comma = last ? '' : ',';
        final valueExpr = _paramValueExpression(param);
        buffer.writeln(
          '$baseIndent$_indent$_indent"${param.fieldName}": $valueExpr$comma',
        );
      }
      if (withExecutionId) {
        buffer.writeln(
          '$baseIndent$_indent$_indent"$_executionIdKey": executionId',
        );
      }
      buffer.writeln('$baseIndent$_indent]');
    }
    buffer.writeln('$baseIndent)');
    if (writeResultLocals) {
      _writeSnippetResultLocals(buffer, info, baseIndent);
    }
  }

  /// Whether this intent's `perform()` opens a native execution scope
  /// (#130 progress/cancellation, #131 value requests).
  ///
  /// A requestable parameter needs one in every branch — `requestValue` is iOS
  /// 16, nothing about it is experimental. Progress and cancellation only exist
  /// in the WWDC26 branch, so the stable `#else` deliberately opens no scope:
  /// `AppIntentExecution.current` is then null and a handler's
  /// `execution?.reportProgress(…)` degrades to a no-op instead of throwing on
  /// a build that could never have reported progress anyway.
  bool _needsExecutionScope(IntentInfo info, {required bool experimental}) {
    if (info.parameters.any((p) => p.requestValue)) return true;
    return experimental && (info.longRunning || info.cancellable);
  }

  /// Writes the execution-scope setup: an id, the sinks the bridge routes to,
  /// and the `defer` that closes the scope.
  ///
  /// [withProgress] is only ever true inside the WWDC26 branch, where the
  /// intent conforms to `LongRunningIntent` and therefore has `progress`.
  void _writeExecutionScope(
    StringBuffer buffer,
    IntentInfo info, {
    required bool withProgress,
  }) {
    final indent2 = _indent * 2;
    final indent3 = _indent * 3;
    final requestable = info.parameters.where((p) => p.requestValue).toList();

    buffer.writeln('${indent2}let executionId = UUID().uuidString');
    if (withProgress) {
      // `progress` is a Foundation `Progress`, which is not Sendable but is
      // documented as safe to use from multiple threads; the bridge calls the
      // sink from its own actor. nonisolated(unsafe) states that explicitly
      // instead of leaving a Sendable warning in every generated project.
      buffer.writeln(
        '${indent2}nonisolated(unsafe) let progressRef = progress',
      );
    }
    buffer.writeln('${indent2}await FlutterBridge.shared.beginExecution(');
    buffer.writeln(
      '${indent3}executionId'
      '${_scopeArgComma(withProgress, requestable.isNotEmpty)}',
    );
    if (withProgress) {
      buffer.writeln('${indent3}progress: { completed, total in');
      buffer.writeln('$indent3${_indent}progressRef.totalUnitCount = total');
      buffer.writeln(
        '$indent3${_indent}progressRef.completedUnitCount = completed',
      );
      buffer.writeln('$indent3}${requestable.isNotEmpty ? ',' : ''}');
    }
    if (requestable.isNotEmpty) {
      // `self` is the running intent; AppIntent refines Sendable and
      // IntentParameter is @unchecked Sendable, so capturing it in a @Sendable
      // closure is allowed. It has to be the same instance: requestValue()
      // resumes the perform() that is suspended right now.
      buffer.writeln('${indent3}valueRequester: { [self] parameter in');
      buffer.writeln('$indent3${_indent}switch parameter {');
      for (final param in requestable) {
        buffer.writeln('$indent3${_indent}case "${param.fieldName}":');
        buffer.writeln(
          '$indent3$_indent$_indent'
          'return ${_requestValueExpression(param)}',
        );
      }
      buffer.writeln('$indent3${_indent}default:');
      buffer.writeln('$indent3$_indent${_indent}return nil');
      buffer.writeln('$indent3$_indent}');
      buffer.writeln('$indent3}');
    }
    buffer.writeln('$indent2)');
    // A `defer` body cannot await, so the scope is closed from a Task. The
    // bridge only drops dictionary entries, so ordering against the next
    // execution does not matter.
    buffer.writeln(
      '${indent2}defer { Task { await FlutterBridge.shared.endExecution(executionId) } }',
    );
  }

  /// Trailing comma after the positional execution id in `beginExecution(…)`.
  String _scopeArgComma(bool withProgress, bool withRequester) =>
      withProgress || withRequester ? ',' : '';

  /// The expression yielding one requested parameter value, converted to
  /// something the MethodChannel can carry.
  String _requestValueExpression(IntentParamInfo param) {
    final isDate =
        param.dartType == 'DateTime' || param.dartType == 'DateTime?';
    final call = 'try await \$${param.fieldName}.requestValue()';
    return isDate ? 'ISO8601DateFormatter().string(from: $call)' : call;
  }

  /// What precedes a `FlutterBridge.shared.invoke` call — a binding, or
  /// `return` when the call is the value of a wrapper closure.
  ///
  /// The result is discarded unless a snippet template reads `{result.…}` from
  /// it — binding it unconditionally would produce an unused-variable warning
  /// in every generated intent.
  String _invokeBinding(IntentInfo info) =>
      _snippetResultKeys(info).isEmpty ? 'let _ =' : 'let snippetResult =';

  /// Writes one `let` per `{result.key}` a snippet reads, so the template can
  /// interpolate a plain `String` instead of an `Any?` subscript.
  void _writeSnippetResultLocals(
    StringBuffer buffer,
    IntentInfo info,
    String indent,
  ) {
    final keys = _snippetResultKeys(info);
    if (keys.isEmpty) return;
    buffer.writeln(
      '${indent}let snippetValues = snippetResult as? [String: Any] ?? [:]',
    );
    for (final key in keys) {
      buffer.writeln(
        '${indent}let ${_snippetResultLocal(key)} = '
        'snippetValues["$key"].map { String(describing: \$0) } ?? ""',
      );
    }
  }

  /// The distinct `{result.key}` keys this intent reads, in first-use order.
  ///
  /// Covers the snippet templates *and* the dialog templates — the dialog and
  /// the card describe the same result, so it would be strange for one to be
  /// able to name a handler value and the other not.
  List<String> _snippetResultKeys(IntentInfo info) =>
      handlerResultKeys(resultTemplatesOf(info));

  /// Escapes a string for embedding in a Swift string literal.
  ///
  /// An unescaped `"` breaks the build and a bare `\(` is silently
  /// reinterpreted as interpolation, so author-supplied text never goes into
  /// a literal directly.
  String _swiftLiteral(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');

  /// The Swift name of an intent's generated snippet view.
  String _snippetViewName(IntentInfo info) => '${info.className}SnippetView';

  /// Builds the snippet view construction used in `.result(view:)`.
  String _snippetViewExpression(IntentInfo info) {
    final snippet = info.snippet!;
    final args = <String>[
      'snippetTitle: "${_interpolateSnippetTemplate(snippet.title, info)}"',
      if (snippet.subtitle != null)
        'snippetSubtitle: '
            '"${_interpolateSnippetTemplate(snippet.subtitle!, info)}"',
      for (var i = 0; i < snippet.rows.length; i++)
        'rowValue$i: '
            '"${_interpolateSnippetTemplate(snippet.rows[i].value, info)}"',
    ];
    return '${_snippetViewName(info)}(${args.join(', ')})';
  }

  /// Converts a snippet template into a Swift string-literal body.
  ///
  /// `{paramName}` becomes `\(paramName)` like a dialog template;
  /// `{result.key}` becomes the local written by [_writeSnippetResultLocals].
  String _interpolateSnippetTemplate(String template, IntentInfo info) {
    // Escape the author's text FIRST, then insert interpolations — running it
    // the other way round would escape the backslash of the `\(` we just
    // added and emit it as literal text.
    var result = _swiftLiteral(template);
    for (final key in _snippetResultKeys(info)) {
      result = substitutePlaceholder(
        result,
        '$resultPlaceholderPrefix$key',
        '\\(${_snippetResultLocal(key)})',
      );
    }
    for (final param in info.parameters) {
      result = substitutePlaceholder(
        result,
        param.fieldName,
        '\\(${param.fieldName})',
      );
    }
    return result;
  }

  /// Writes the SwiftUI view backing an intent's snippet card.
  ///
  /// The layout is fixed (optional symbol, title, optional subtitle, labelled
  /// rows) and the dynamic parts arrive as stored `String` properties, so no
  /// shared runtime type is needed and each intent's view is self-contained.
  /// Row labels stay literal so they localize through the String Catalog.
  void _writeSnippetView(StringBuffer buffer, IntentInfo info) {
    final snippet = info.snippet!;
    final name = _snippetViewName(info);

    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('struct $name: View {');
    buffer.writeln('${_indent}let snippetTitle: String');
    if (snippet.subtitle != null) {
      buffer.writeln('${_indent}let snippetSubtitle: String');
    }
    for (var i = 0; i < snippet.rows.length; i++) {
      buffer.writeln('${_indent}let rowValue$i: String');
    }
    buffer.writeln();
    buffer.writeln('${_indent}var body: some View {');

    final i2 = '$_indent$_indent';
    final i3 = '$i2$_indent';
    final i4 = '$i3$_indent';
    final i5 = '$i4$_indent';

    buffer.writeln('${i2}VStack(alignment: .leading, spacing: 8) {');
    buffer.writeln('${i3}HStack(spacing: 8) {');
    if (snippet.systemImageName != null) {
      buffer.writeln(
        '${i4}Image(systemName: "${_swiftLiteral(snippet.systemImageName!)}")',
      );
      buffer.writeln('$i4$_indent.font(.title2)');
    }
    buffer.writeln('${i4}VStack(alignment: .leading, spacing: 2) {');
    buffer.writeln('${i5}Text(snippetTitle)');
    buffer.writeln('$i5$_indent.font(.headline)');
    if (snippet.subtitle != null) {
      buffer.writeln('${i5}Text(snippetSubtitle)');
      buffer.writeln('$i5$_indent.font(.subheadline)');
      buffer.writeln('$i5$_indent.foregroundStyle(.secondary)');
    }
    buffer.writeln('$i4}');
    buffer.writeln('$i3}');
    for (var i = 0; i < snippet.rows.length; i++) {
      buffer.writeln(
        '${i3}LabeledContent("${_swiftLiteral(snippet.rows[i].label)}") {',
      );
      buffer.writeln('${i4}Text(rowValue$i)');
      buffer.writeln('$i3}');
    }
    buffer.writeln('$i2}');
    buffer.writeln('$i2.padding()');
    buffer.writeln('$_indent}');
    buffer.write('}');
  }

  /// The Swift local holding the string form of `{result.<key>}`.
  String _snippetResultLocal(String key) {
    final sanitized = key.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return 'snippetValue_$sanitized';
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
    _writeEntityCollectionSerializations(buffer, info, nativeRichTypes);
    _writeUnionSerializations(buffer, info, nativeRichTypes);
    _writeValueStateSerializations(buffer, info);

    final indent2 = '$_indent$_indent';
    final indent3 = '$_indent$_indent$_indent';

    // #130/#131: the scope has to be opened before the wrapper closure, so the
    // id is in scope for both the invoke inside it and the onCancel handler.
    final withScope = _needsExecutionScope(info, experimental: true);
    if (withScope) {
      _writeExecutionScope(buffer, info, withProgress: info.longRunning);
    }

    // Long-running work uses performBackgroundTask; cancellable-only work uses
    // the cancellation handler. Both take the operation as a trailing closure.
    // When the intent is both long-running and cancellable, the combined
    // performBackgroundTask(operation:onCancel:) overload (which requires
    // CancellableIntent conformance) is used.
    final wrapper = info.longRunning
        ? 'performBackgroundTask'
        : 'withIntentCancellationHandler';

    // Both wrappers return the closure's value, so when a dialog or snippet
    // reads `{result.…}` the payload is bound OUTSIDE the closure. Binding it
    // inside would put the interpolation locals out of scope by the time the
    // return statement (emitted after the closure) references them.
    final needsResult = _snippetResultKeys(info).isNotEmpty;
    buffer.writeln(
      needsResult
          ? '${indent2}let snippetResult = try await $wrapper {'
          : '${indent2}try await $wrapper {',
    );
    _writeFlutterBridgeInvoke(
      buffer,
      info,
      indent3,
      invokePrefix: needsResult ? 'return' : null,
      writeResultLocals: false,
      withExecutionId: withScope,
    );
    if (info.cancellable) {
      buffer.writeln('$indent2} onCancel: { reason in');
      if (withScope) {
        // Wrapped in a Task so this compiles whether or not the SDK declares
        // onCancel as async, and so a cancellation the system does not wait for
        // still gets its best-effort hop to Dart. The handler observes it as
        // `AppIntentExecution.current.isCancelled`.
        buffer.writeln('${indent3}Task {');
        buffer.writeln(
          '$indent3${_indent}await FlutterBridge.shared.reportCancellation(',
        );
        buffer.writeln('$indent3$_indent${_indent}executionId: executionId,');
        buffer.writeln(
          '$indent3$_indent${_indent}reason: String(describing: reason)',
        );
        buffer.writeln('$indent3$_indent)');
        buffer.writeln('$indent3}');
      } else {
        buffer.writeln(
          '$indent3// The system cancelled this intent; `reason` explains why.',
        );
        buffer.writeln('$indent3// Perform best-effort cleanup here.');
      }
      buffer.writeln('$indent2}');
    } else {
      buffer.writeln('$indent2}');
    }

    _writeSnippetResultLocals(buffer, info, indent2);

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
    _writeEntityCollectionSerializations(buffer, info, nativeRichTypes);
    _writeUnionSerializations(buffer, info, nativeRichTypes);
    _writeValueStateSerializations(buffer, info);

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
      if (param.useValueState) {
        // Add the state discriminator (always present on iOS 18.2+; nil-skipped
        // on older OS versions where the pre-serialized local stays nil).
        buffer.writeln(
          '${indent2}if let ${param.fieldName}StateValue = ${param.fieldName}State {',
        );
        buffer.writeln(
          '$indent2${_indent}params["${param.fieldName}State"] = ${param.fieldName}StateValue',
        );
        buffer.writeln('$indent2}');
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
      _writeEntityCollectionSerializations(buffer, info, nativeRichTypes);
      _writeUnionSerializations(buffer, info, nativeRichTypes);
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

    // Entity-collection types: comma-join the pre-serialized identifier list.
    if (_isEntityCollectionParam(param)) {
      final name = param.fieldName;
      final joined = '${name}Ids.joined(separator: ",")';
      if (isNullable) {
        buffer.writeln('$_indent${_indent}if let ${name}Ids {');
        buffer.writeln(
          '$_indent$_indent${_indent}queryItems.append(URLQueryItem(name: "$name", value: $joined))',
        );
        buffer.writeln('$_indent$_indent}');
      } else {
        buffer.writeln(
          '$_indent${_indent}queryItems.append(URLQueryItem(name: "$name", value: $joined))',
        );
      }
      return;
    }

    // Union types: encode the tagged map as `<_type>|<id>` (a single URL query
    // value can't carry a Map; Dart splits on the first `|`).
    if (_isUnionParam(param)) {
      final name = param.fieldName;
      final indent3 = '$_indent$_indent$_indent';
      final value =
          '(${name}Union["_type"] ?? "") + "|" + (${name}Union["id"] ?? "")';
      if (isNullable) {
        buffer.writeln('$_indent${_indent}if let ${name}Union {');
        buffer.writeln(
          '${indent3}queryItems.append(URLQueryItem(name: "$name", value: $value))',
        );
        buffer.writeln('$_indent$_indent}');
      } else {
        buffer.writeln(
          '$_indent${_indent}queryItems.append(URLQueryItem(name: "$name", value: $value))',
        );
      }
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
    // A structured export throws AppIntentError when the entity has nothing to
    // offer for that flavor (#128). `generateAll` already imports the bridge
    // whenever any entity is present.
    if (experimental.isEnabled(ExperimentalFeature.valueRepresentation) &&
        info.exportAs != null &&
        info.exportAs != EntityExportKind.person) {
      buffer.writeln('import AppIntentsBridge');
    }
    buffer.writeln();

    // Entity body
    _generateEntityBody(buffer, info);

    return buffer.toString();
  }

  void _generateEntityBody(StringBuffer buffer, EntityInfo info) {
    _validateIdPropertyName(info);
    final dualId = _usesDualIdentifier(info);
    if (_usesExperimentalEntitySchema(info) || dualId) {
      // App Schema (#49) is iOS 27+: the entity, its query and extensions all
      // move to iOS 27 in the experimental branch. The #else branch keeps the
      // stable form so released-SDK builds without the flag still compile.
      buffer.writeln('#if APP_INTENTS_WWDC26');
      _writeEntityAndQuery(
        buffer,
        info,
        availability: 'iOS 27.0',
        indexedAvailability: 'iOS 27.0',
        schemaMacro: _usesExperimentalEntitySchema(info)
            ? '@AppEntity(schema: .${info.schema})'
            : null,
        dualId: dualId,
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

    // #51 IntentValueQuery: an additive query type. `IntentValueQuery` exists
    // in the stable SDK at iOS 26.0, so this is NOT experimental — it is emitted
    // whenever the entity opts in, guarded by plain `@available`. See ADR 0001.
    if (info.valueQuery) {
      buffer.writeln();
      buffer.writeln();
      _writeValueQueryStruct(buffer, info);
    }

    // #54 cross-app sharing (export): an additive iOS 27 Transferable
    // conformance, in its own #if block (no #else — without the flag the entity
    // simply isn't exportable). See ADR 0002.
    if (experimental.isEnabled(ExperimentalFeature.valueRepresentation) &&
        info.exportAs != null) {
      buffer.writeln();
      buffer.writeln();
      _writeValueRepresentationExtension(buffer, info);
    }

    // #55 SyncableEntity (stable-id case): an additive iOS 27 conformance, in
    // its own #if block (no #else — without the flag the entity just isn't
    // syncable). Only valid when the entity's id is already stable. See ADR 0003.
    if (experimental.isEnabled(ExperimentalFeature.donation) && info.syncable) {
      buffer.writeln();
      buffer.writeln();
      _writeSyncableEntityExtension(buffer, info);
    }

    // #133 IndexedEntityQuery: additive iOS 27 conformance letting the system
    // ask for a re-index, in its own #if block (no #else).
    if (experimental.isEnabled(ExperimentalFeature.reindexing) &&
        info.indexed) {
      buffer.writeln();
      buffer.writeln();
      _writeIndexedEntityQueryExtension(buffer, info);
    }

    // #55 RelevantEntities donator: an additive iOS 27 reverse-executor
    // registration, in its own #if block (no #else). See ADR 0003.
    if (experimental.isEnabled(ExperimentalFeature.donation) &&
        info.relevantEntities) {
      buffer.writeln();
      buffer.writeln();
      _writeRelevantEntitiesDonator(buffer, info);
    }
  }

  /// Writes the `IndexedEntityQuery` conformance (#133).
  ///
  /// The protocol is how the system asks the app to refresh Spotlight's copy of
  /// an entity. Both methods re-read through the existing query path — which is
  /// what already reaches Dart — and hand the result to
  /// `CSSearchableIndex.indexAppEntities`, so the app's own data stays the
  /// single source and no new bridge call is needed.
  void _writeIndexedEntityQueryExtension(StringBuffer buffer, EntityInfo info) {
    final dualId = _usesDualIdentifier(info);
    buffer.writeln('#if APP_INTENTS_WWDC26');
    buffer.writeln('@available(iOS 27.0, *)');
    buffer.writeln('extension ${info.className}Query: IndexedEntityQuery {');
    buffer.writeln('${_indent}func reindexEntities(');
    buffer.writeln(
      '$_indent${_indent}for identifiers: [${_entityIdSwiftType(dualId)}],',
    );
    buffer.writeln(
      '$_indent${_indent}indexDescription: CSSearchableIndexDescription',
    );
    buffer.writeln('$_indent) async throws {');
    buffer.writeln(
      '$_indent${_indent}let refreshed = try await entities(for: identifiers)',
    );
    buffer.writeln(
      '$_indent${_indent}try await CSSearchableIndex.default().indexAppEntities(refreshed)',
    );
    buffer.writeln('$_indent}');
    buffer.writeln();
    // suggestedEntities() is the complete source here, not a subset: an
    // indexed entity always has a cache key, the cache holds the full entity
    // list Dart projects, and suggestedEntities() returns it whenever it is
    // non-empty. Only an empty cache falls through to the Dart handler.
    buffer.writeln('${_indent}func reindexAllEntities(');
    buffer.writeln(
      '$_indent${_indent}indexDescription: CSSearchableIndexDescription',
    );
    buffer.writeln('$_indent) async throws {');
    buffer.writeln(
      '$_indent${_indent}let refreshed = try await suggestedEntities()',
    );
    buffer.writeln(
      '$_indent${_indent}try await CSSearchableIndex.default().indexAppEntities(refreshed)',
    );
    buffer.writeln('$_indent}');
    buffer.writeln('}');
    buffer.write('#endif');
  }

  /// Writes the experimental `SyncableEntity` conformance for the
  /// already-stable-id case (#55). No members are needed when the entity's id
  /// is already consistent across devices. Gated by `#if APP_INTENTS_WWDC26`
  /// with no `#else` (additive).
  void _writeSyncableEntityExtension(StringBuffer buffer, EntityInfo info) {
    buffer.writeln('#if APP_INTENTS_WWDC26');
    buffer.writeln('@available(iOS 27.0, *)');
    buffer.writeln(
      '/// The id is already stable across devices, so no extra members are needed.',
    );
    buffer.writeln('extension ${info.className}: SyncableEntity {}');
    buffer.write('#endif');
  }

  /// Writes the experimental `RelevantEntities` donator registration (#55).
  ///
  /// Emits a `register<Entity>RelevantEntitiesDonator()` function (call it once
  /// at startup) that registers a closure with `FlutterBridge`. When Dart calls
  /// `donateRelevantEntities`, the closure builds concrete entities from the
  /// dictionaries and calls `RelevantEntities.shared.updateEntities(_:for:)`
  /// (a stateful overwrite for the context). Gated by `#if APP_INTENTS_WWDC26`
  /// with no `#else` (additive). The iOS-27 symbols (`RelevantEntities`,
  /// `AppEntityContext`) appear only inside this gated closure.
  void _writeRelevantEntitiesDonator(StringBuffer buffer, EntityInfo info) {
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
    final fnName = 'register${info.className}RelevantEntitiesDonator';

    buffer.writeln('#if APP_INTENTS_WWDC26');
    buffer.writeln('@available(iOS 27.0, *)');
    buffer.writeln(
      '/// Registers the RelevantEntities donator for ${info.className}.',
    );
    buffer.writeln('/// Call this once at startup (e.g. in AppDelegate).');
    buffer.writeln('func $fnName() {');
    buffer.writeln('${_indent}Task {');
    buffer.writeln(
      '$_indent${_indent}await FlutterBridge.shared.registerRelevantEntitiesDonator(',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}entityIdentifier: "${info.identifier}"',
    );
    buffer.writeln('$_indent$_indent) { operation, dicts, context in');
    buffer.writeln(
      '$_indent$_indent${_indent}let entities: [${info.className}] = dicts.compactMap { dict in',
    );
    _writeEntityDictMapping(
      buffer,
      info,
      idProp,
      titleProp,
      subtitleProp,
      imageProp,
      dualId: _usesDualIdentifier(info),
    );
    buffer.writeln('$_indent$_indent$_indent}');
    final i3 = _indent * 3;
    final i4 = _indent * 4;
    final i5 = _indent * 5;
    buffer.writeln(
      '${i3}let entityContext = ${info.className}._relevantContext(context)',
    );
    // #133: `RelevantEntities` gained explicit removal in the Xcode 27 SDK.
    // Removing used to mean "update with an empty list", which can scope a
    // clear to one context but cannot clear every context at once.
    buffer.writeln('${i3}switch operation {');
    buffer.writeln('${i3}case "remove":');
    buffer.writeln('${i4}if context == nil {');
    buffer.writeln(
      '${i5}try await RelevantEntities.shared.removeEntities(entities)',
    );
    buffer.writeln('$i4} else {');
    buffer.writeln(
      '${i5}try await RelevantEntities.shared.removeEntities(entities, from: entityContext)',
    );
    buffer.writeln('$i4}');
    buffer.writeln('${i3}case "removeAll":');
    buffer.writeln('${i4}if context == nil {');
    buffer.writeln(
      '${i5}try await RelevantEntities.shared.removeAllEntities()',
    );
    buffer.writeln('$i4} else {');
    buffer.writeln(
      '${i5}try await RelevantEntities.shared.removeAllEntities(for: entityContext)',
    );
    buffer.writeln('$i4}');
    buffer.writeln('${i3}default:');
    buffer.writeln(
      '${i4}try await RelevantEntities.shared.updateEntities(entities, for: entityContext)',
    );
    buffer.writeln('$i3}');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('@available(iOS 27.0, *)');
    buffer.writeln('extension ${info.className} {');
    buffer.writeln(
      '$_indent/// Maps an opaque context token from Dart to an AppEntityContext.',
    );
    buffer.writeln(
      '${_indent}static func _relevantContext(_ token: String?) -> AppEntityContext {',
    );
    buffer.writeln('$_indent${_indent}switch token {');
    buffer.writeln(
      '$_indent$_indent case "audio.nowPlaying": return .audio(.nowPlaying)',
    );
    // MVP: only `audio.nowPlaying` is mapped. An unknown/nil token falls back to
    // it rather than erroring; expand this switch as the context catalog grows.
    buffer.writeln(
      '$_indent$_indent // Unknown/nil tokens fall back to now-playing (only context in the MVP).',
    );
    buffer.writeln('$_indent$_indent default: return .audio(.nowPlaying)');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
    buffer.write('#endif');
  }

  /// Writes the experimental intent donator registration (#55).
  ///
  /// Emits a `register<Intent>Donator()` function (call once at startup) that
  /// registers a closure with `FlutterBridge`. When Dart calls
  /// `donateIntent`, the closure reconstructs the concrete `AppIntent` from the
  /// param dict and calls `intent.donate()` (`@discardableResult`, stable iOS
  /// 16+). Gated by `#if APP_INTENTS_WWDC26` with no `#else` (additive). MVP
  /// only supports primitive parameters; the analyzer rejects others.
  void _writeIntentDonator(StringBuffer buffer, IntentInfo info) {
    final fnName = 'register${info.className}Donator';
    buffer.writeln('#if APP_INTENTS_WWDC26');
    buffer.writeln('@available(iOS 17.0, *)');
    buffer.writeln('/// Registers the intent donator for ${info.className}.');
    buffer.writeln('/// Call this once at startup (e.g. in AppDelegate).');
    buffer.writeln('func $fnName() {');
    buffer.writeln('${_indent}Task {');
    buffer.writeln(
      '$_indent${_indent}await FlutterBridge.shared.registerIntentDonator(',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}intentIdentifier: "${info.identifier}"',
    );
    buffer.writeln('$_indent$_indent) { params in');
    buffer.writeln(
      '$_indent$_indent${_indent}var intent = ${info.className}()',
    );
    for (final param in info.parameters) {
      _writeIntentDonatorParamAssignment(buffer, param);
    }
    buffer.writeln('$_indent$_indent${_indent}_ = await intent.donate()');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
    buffer.write('#endif');
  }

  /// Writes a single `if let v = params["field"] as? T { intent.field = v }`
  /// (or DateTime variant) line for a donatable intent parameter. The analyzer
  /// guarantees [param] is a primitive at this point.
  void _writeIntentDonatorParamAssignment(
    StringBuffer buffer,
    IntentParamInfo param,
  ) {
    final indent3 = '$_indent$_indent$_indent';
    final isDate =
        param.dartType == 'DateTime' || param.dartType == 'DateTime?';
    if (isDate) {
      // Wire format is an ISO8601 string (see _paramValueExpression). Round-
      // trip via ISO8601DateFormatter; silently skip on parse failure.
      buffer.writeln(
        '${indent3}if let s = params["${param.fieldName}"] as? String,',
      );
      buffer.writeln(
        '$indent3${_indent}let d = ISO8601DateFormatter().date(from: s) {',
      );
      buffer.writeln('$indent3${_indent}intent.${param.fieldName} = d');
      buffer.writeln('$indent3}');
      return;
    }
    final swiftType = dartTypeToSwiftType(
      param.dartType.endsWith('?')
          ? param.dartType.substring(0, param.dartType.length - 1)
          : param.dartType,
    );
    buffer.writeln(
      '${indent3}if let v = params["${param.fieldName}"] as? $swiftType {',
    );
    buffer.writeln('$indent3${_indent}intent.${param.fieldName} = v');
    buffer.writeln('$indent3}');
  }

  /// Writes the experimental `Transferable` + `ValueRepresentation` conformance
  /// for cross-app entity sharing (#54; catalog extended in #128, `importing:`
  /// added in #129).
  ///
  /// Gated by `#if APP_INTENTS_WWDC26` with no `#else`: the conformance is
  /// purely additive, so released-SDK builds without the flag just omit it. The
  /// `CoreTransferable` (and, for a place, `GeoToolbox`/`CoreLocation`) imports
  /// are emitted inside the `#if` so they do not become unused imports when the
  /// flag is off.
  void _writeValueRepresentationExtension(
    StringBuffer buffer,
    EntityInfo info,
  ) {
    final kind = info.exportAs!;
    final systemType = _exportSystemType(kind);

    buffer.writeln('#if APP_INTENTS_WWDC26');
    buffer.writeln('import CoreTransferable');
    if (kind == EntityExportKind.place) {
      // PlaceDescriptor lives in GeoToolbox (the AppIntents type of the same
      // name is the deprecated iOS 16 one); CoreLocation supplies
      // CLLocationCoordinate2D for the coordinate representation.
      buffer.writeln('import CoreLocation');
      buffer.writeln('import GeoToolbox');
    }
    buffer.writeln();
    buffer.writeln('@available(iOS 27.0, *)');
    buffer.writeln('extension ${info.className}: Transferable {');
    buffer.writeln(
      '${_indent}static var transferRepresentation: some TransferRepresentation {',
    );

    final i2 = _indent * 2;
    if (!info.importable) {
      buffer.writeln(
        '${i2}ValueRepresentation(exporting: '
        '{ (entity: ${info.className}) -> $systemType in',
      );
      _writeExportBody(buffer, info, _indent * 3);
      buffer.writeln('$i2})');
    } else {
      final i3 = _indent * 3;
      buffer.writeln('${i2}ValueRepresentation(');
      buffer.writeln(
        '${i3}exporting: { (entity: ${info.className}) -> $systemType in',
      );
      _writeExportBody(buffer, info, _indent * 4);
      buffer.writeln('$i3},');
      buffer.writeln(
        '${i3}importing: { (value: $systemType) -> ${info.className} in',
      );
      _writeImportBody(buffer, info, _indent * 4);
      buffer.writeln('$i3}');
      buffer.writeln('$i2)');
    }

    buffer.writeln('$_indent}');
    buffer.writeln('}');
    buffer.write('#endif');
  }

  /// The Swift system type an [EntityExportKind] maps to.
  String _exportSystemType(EntityExportKind kind) => switch (kind) {
    EntityExportKind.person => 'IntentPerson',
    EntityExportKind.place => 'PlaceDescriptor',
  };

  /// Writes the statements of an export closure — everything between
  /// `{ (entity: X) -> T in` and the closing brace.
  void _writeExportBody(StringBuffer buffer, EntityInfo info, String indent) {
    switch (info.exportAs!) {
      case EntityExportKind.person:
        _writePersonExportBody(buffer, info, indent);
      case EntityExportKind.place:
        _writePlaceExportBody(buffer, info, indent);
    }
  }

  /// The entity's title field name, used as the human-readable half of every
  /// structured export.
  String _titleFieldName(EntityInfo info) =>
      info.properties
          .where((p) => p.role == EntityPropertyRole.title)
          .firstOrNull
          ?.fieldName ??
      'title';

  /// `IntentPerson` export: built from the id and title roles alone.
  void _writePersonExportBody(
    StringBuffer buffer,
    EntityInfo info,
    String indent,
  ) {
    buffer.writeln('${indent}return IntentPerson(');
    // The Swift stored property is always `id` (AppEntity refines Identifiable),
    // but a dual identifier (#132) is a struct, so it is rendered through
    // EntityIdentifierConvertible.
    buffer.writeln(
      '$indent${_indent}identifier: .applicationDefined('
      '${_entityIdString('entity', _usesDualIdentifier(info))}),',
    );
    buffer.writeln(
      '$indent${_indent}name: .displayName(entity.${_titleFieldName(info)}),',
    );
    // `handle` has no default in the SDK initializer
    // (init(identifier:name:handle:aliases:isMe:image:)), so it must be
    // passed explicitly even when nil.
    buffer.writeln('$indent${_indent}handle: nil');
    buffer.writeln('$indent)');
  }

  /// `GeoToolbox.PlaceDescriptor` export (#128).
  ///
  /// Both representations are optional at runtime even when the Dart fields are
  /// not: an entity rebuilt from a cached dictionary may be missing them. The
  /// closure therefore normalizes each field to an optional local and throws
  /// when nothing is left to export — the documented way for a `Transferable`
  /// to decline a flavor, which makes the system simply not offer it rather
  /// than hand another app an empty place.
  void _writePlaceExportBody(
    StringBuffer buffer,
    EntityInfo info,
    String indent,
  ) {
    final lat = info.exportField(EntityExportRoleKind.latitude);
    final lng = info.exportField(EntityExportRoleKind.longitude);
    final address = info.exportField(EntityExportRoleKind.address);

    buffer.writeln(
      '${indent}var representations: [PlaceDescriptor.PlaceRepresentation] = []',
    );
    if (lat != null && lng != null) {
      buffer.writeln('$indent${_optionalDoubleLocal('latitude', lat)}');
      buffer.writeln('$indent${_optionalDoubleLocal('longitude', lng)}');
      buffer.writeln(
        '${indent}if let latitude = latitudeValue, let longitude = longitudeValue {',
      );
      buffer.writeln('$indent${_indent}representations.append(');
      buffer.writeln(
        '$indent$_indent$_indent'
        '.coordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))',
      );
      buffer.writeln('$indent$_indent)');
      buffer.writeln('$indent}');
    }
    if (address != null) {
      buffer.writeln(
        '${indent}let addressValue: String? = entity.${address.fieldName}',
      );
      buffer.writeln(
        '${indent}if let address = addressValue, !address.isEmpty {',
      );
      buffer.writeln(
        '$indent${_indent}representations.append(.address(address))',
      );
      buffer.writeln('$indent}');
    }
    buffer.writeln('${indent}guard !representations.isEmpty else {');
    _writeExportUnavailableThrow(
      buffer,
      '$indent$_indent',
      '${info.className} has no location to export as a place',
    );
    buffer.writeln('$indent}');
    buffer.writeln('${indent}return PlaceDescriptor(');
    buffer.writeln('$indent${_indent}representations: representations,');
    buffer.writeln(
      '$indent${_indent}commonName: entity.${_titleFieldName(info)}',
    );
    buffer.writeln('$indent)');
  }

  /// The `throw` an export closure uses to decline a flavor it cannot build.
  void _writeExportUnavailableThrow(
    StringBuffer buffer,
    String indent,
    String message,
  ) {
    buffer.writeln('${indent}throw AppIntentError.custom(');
    buffer.writeln('$indent${_indent}code: "EXPORT_UNAVAILABLE",');
    buffer.writeln('$indent${_indent}message: "$message"');
    buffer.writeln('$indent)');
  }

  /// Writes the statements of an `importing:` closure (#129).
  ///
  /// Import is the one direction that needs Dart: deciding whether a person or
  /// place handed over by another app matches existing content — or should
  /// create some — depends on the app's data. It reuses #51's value-query
  /// bridge rather than adding a second round-trip shape; the query identifier
  /// is the entity identifier with an `#import` suffix, which is what
  /// `registerValueImportHandler` registers under.
  void _writeImportBody(StringBuffer buffer, EntityInfo info, String indent) {
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

    switch (info.exportAs!) {
      case EntityExportKind.person:
        _writePersonImportInput(buffer, indent);
      case EntityExportKind.place:
        _writePlaceImportInput(buffer, indent);
    }

    buffer.writeln(
      '${indent}let results = try await FlutterBridge.shared.queryValues(',
    );
    buffer.writeln(
      '$indent${_indent}queryIdentifier: "${info.identifier}$_importQuerySuffix",',
    );
    buffer.writeln('$indent${_indent}input: input');
    buffer.writeln('$indent)');
    buffer.writeln(
      '${indent}let matches: [${info.className}] = results.compactMap { dict in',
    );
    _writeEntityDictMapping(
      buffer,
      info,
      idProp,
      titleProp,
      subtitleProp,
      imageProp,
      depth: indent.length ~/ _indent.length + 1,
      dualId: _usesDualIdentifier(info),
    );
    buffer.writeln('$indent}');
    buffer.writeln('${indent}guard let match = matches.first else {');
    buffer.writeln('$indent${_indent}throw AppIntentError.custom(');
    buffer.writeln('$indent$_indent${_indent}code: "IMPORT_FAILED",');
    buffer.writeln(
      '$indent$_indent$_indent'
      'message: "No ${info.className} matches the imported value"',
    );
    buffer.writeln('$indent$_indent)');
    buffer.writeln('$indent}');
    buffer.writeln('${indent}return match');
  }

  /// Serializes an `IntentPerson` into the value-query input dictionary.
  ///
  /// `@unknown default` on every switch: these are library-evolution enums, so
  /// a future SDK can add a case and Swift 6 turns the missing branch into an
  /// error.
  void _writePersonImportInput(StringBuffer buffer, String indent) {
    final i2 = '$indent$_indent';
    buffer.writeln('${indent}var input: [String: Any] = ["kind": "person"]');
    buffer.writeln('${indent}switch value.identifier {');
    buffer.writeln('${indent}case .contact(let identifier):');
    buffer.writeln('${i2}input["identifierKind"] = "contact"');
    buffer.writeln('${i2}input["identifier"] = identifier');
    buffer.writeln('${indent}case .applicationDefined(let identifier):');
    buffer.writeln('${i2}input["identifierKind"] = "applicationDefined"');
    buffer.writeln('${i2}input["identifier"] = identifier');
    buffer.writeln('${indent}case .unknown:');
    buffer.writeln('${i2}input["identifierKind"] = "unknown"');
    buffer.writeln('$indent@unknown default:');
    buffer.writeln('${i2}input["identifierKind"] = "unknown"');
    buffer.writeln('$indent}');
    buffer.writeln('${indent}switch value.name {');
    buffer.writeln('${indent}case .displayName(let displayName):');
    buffer.writeln('${i2}input["displayName"] = displayName');
    buffer.writeln('${indent}case .components(let components):');
    buffer.writeln('${i2}var nameParts: [String: String] = [:]');
    for (final entry in const {
      'givenName': 'givenName',
      'familyName': 'familyName',
      'middleName': 'middleName',
      'namePrefix': 'namePrefix',
      'nameSuffix': 'nameSuffix',
      'nickname': 'nickname',
    }.entries) {
      buffer.writeln('${i2}if let part = components.${entry.value} {');
      buffer.writeln('$i2${_indent}nameParts["${entry.key}"] = part');
      buffer.writeln('$i2}');
    }
    buffer.writeln('${i2}input["nameComponents"] = nameParts');
    buffer.writeln('${indent}case .unknown:');
    buffer.writeln('${i2}break');
    buffer.writeln('$indent@unknown default:');
    buffer.writeln('${i2}break');
    buffer.writeln('$indent}');
    buffer.writeln('${indent}if let handle = value.handle {');
    buffer.writeln('${i2}switch handle.value {');
    buffer.writeln('${i2}case .phoneNumber(let handleValue):');
    buffer.writeln('$i2${_indent}input["handleKind"] = "phoneNumber"');
    buffer.writeln('$i2${_indent}input["handle"] = handleValue');
    buffer.writeln('${i2}case .emailAddress(let handleValue):');
    buffer.writeln('$i2${_indent}input["handleKind"] = "emailAddress"');
    buffer.writeln('$i2${_indent}input["handle"] = handleValue');
    buffer.writeln('${i2}case .applicationDefined(let handleValue):');
    buffer.writeln('$i2${_indent}input["handleKind"] = "applicationDefined"');
    buffer.writeln('$i2${_indent}input["handle"] = handleValue');
    buffer.writeln('$i2@unknown default:');
    buffer.writeln('$i2${_indent}break');
    buffer.writeln('$i2}');
    buffer.writeln('$indent}');
  }

  /// Serializes a `PlaceDescriptor` into the value-query input dictionary.
  void _writePlaceImportInput(StringBuffer buffer, String indent) {
    final i2 = '$indent$_indent';
    buffer.writeln('${indent}var input: [String: Any] = ["kind": "place"]');
    buffer.writeln('${indent}if let commonName = value.commonName {');
    buffer.writeln('${i2}input["commonName"] = commonName');
    buffer.writeln('$indent}');
    // `address` / `coordinate` are GeoToolbox's convenience accessors over the
    // representations array (iOS 26.0), so the cases do not have to be matched
    // by hand here.
    buffer.writeln('${indent}if let address = value.address {');
    buffer.writeln('${i2}input["address"] = address');
    buffer.writeln('$indent}');
    buffer.writeln('${indent}if let coordinate = value.coordinate {');
    buffer.writeln('${i2}input["latitude"] = coordinate.latitude');
    buffer.writeln('${i2}input["longitude"] = coordinate.longitude');
    buffer.writeln('$indent}');
  }

  /// A `let <name>Value: Double? = …` local normalizing an export field to an
  /// optional Double, whatever its declared Dart type.
  ///
  /// Assigning a non-optional to an `Double?` local is free in Swift, so one
  /// shape covers `double`, `double?`, `int` and `int?` and the export closure
  /// does not have to branch on optionality.
  String _optionalDoubleLocal(String name, EntityPropertyInfo prop) {
    final isInt = prop.dartType == 'int' || prop.dartType == 'int?';
    final isOptional = prop.dartType.endsWith('?');
    final expr = switch ((isInt, isOptional)) {
      (false, _) => 'entity.${prop.fieldName}',
      (true, false) => 'Double(entity.${prop.fieldName})',
      (true, true) => 'entity.${prop.fieldName}.map(Double.init)',
    };
    return 'let ${name}Value: Double? = $expr';
  }

  /// Writes the `IntentValueQuery` conforming struct (#51).
  ///
  /// Receives a serializable text search input from the system and delegates to
  /// a Dart handler via `FlutterBridge.shared.queryValues`.
  ///
  /// This is **not** experimental: `IntentValueQuery` is declared at iOS 26.0 in
  /// the released SDK (verified against the iOS 26.5 and iOS 27.0 SDKs), so a
  /// plain `@available` is a sufficient guard and no `#if` is needed. The one
  /// exception is an entity that opts into App Schema (#49): there the entity
  /// type itself only exists at iOS 27 inside the `#if` branch, so the query has
  /// to follow it into both branches or it would reference a type newer than
  /// itself.
  void _writeValueQueryStruct(StringBuffer buffer, EntityInfo info) {
    // A dual identifier (#132) changes the entity type the same way a schema
    // does, so the query has to follow it into both branches.
    if (_usesExperimentalEntitySchema(info) || _usesDualIdentifier(info)) {
      buffer.writeln('#if APP_INTENTS_WWDC26');
      _writeValueQueryStructBody(
        buffer,
        info,
        availability: 'iOS 27.0',
        dualId: _usesDualIdentifier(info),
      );
      buffer.writeln();
      buffer.writeln('#else');
      _writeValueQueryStructBody(buffer, info, availability: 'iOS 26.0');
      buffer.writeln();
      buffer.write('#endif');
    } else {
      _writeValueQueryStructBody(buffer, info, availability: 'iOS 26.0');
    }
  }

  /// Writes the `IntentValueQuery` struct at a single availability.
  void _writeValueQueryStructBody(
    StringBuffer buffer,
    EntityInfo info, {
    required String availability,
    bool dualId = false,
  }) {
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

    buffer.writeln('@available($availability, *)');
    buffer.writeln('struct ${info.className}ValueQuery: IntentValueQuery {');
    buffer.writeln(
      '${_indent}func values(for input: String) async throws -> [${info.className}] {',
    );
    buffer.writeln(
      '$_indent${_indent}let results = try await FlutterBridge.shared.queryValues(',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}queryIdentifier: "${info.identifier}",',
    );
    buffer.writeln('$_indent$_indent${_indent}input: ["query": input]');
    buffer.writeln('$_indent$_indent)');
    buffer.writeln('$_indent${_indent}return results.compactMap { dict in');
    _writeEntityDictMapping(
      buffer,
      info,
      idProp,
      titleProp,
      subtitleProp,
      imageProp,
      dualId: dualId,
    );
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.write('}');
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

  /// Whether [info]'s Swift `id` is a dual `SyncableEntityIdentifier` (#132).
  ///
  /// Like the App Schema macro, this changes the entity type itself, so the
  /// whole entity + query dual-branches: `SyncableEntityIdentifier` is iOS 27
  /// only, and the `#else` keeps the scalar id so a released-SDK build still
  /// compiles (with the stable id as an ordinary property).
  bool _usesDualIdentifier(EntityInfo info) =>
      experimental.isEnabled(ExperimentalFeature.donation) &&
      info.usesDualIdentifier;

  /// The Swift type of the entity's `id` property in the given branch.
  String _entityIdSwiftType(bool dualId) =>
      dualId ? 'SyncableEntityIdentifier<String, String>' : 'String';

  /// An expression yielding the entity identifier as a plain `String`.
  String _entityIdString(String receiver, bool dualId) =>
      dualId ? '$receiver.id.entityIdentifierString' : '$receiver.id';

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
    bool dualId = false,
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

    _writeEntityProperties(buffer, info, dualId);

    // The @Property wrapper has no init(wrappedValue:), so an entity that
    // exposes properties needs an explicit initializer; non-role properties get
    // defaults so the role-only construction in the query keeps compiling.
    if (info.needsExplicitInit) {
      buffer.writeln();
      _writeEntityInit(buffer, info, dualId);
    }

    buffer.writeln();
    _writeDisplayRepresentation(buffer, info);

    buffer.writeln('}');
    buffer.writeln();

    _writeQueryStruct(buffer, info, availability, dualId);

    if (info.enumerable) {
      _writeEnumerableQueryExtension(buffer, info, availability);
    }

    if (info.indexed) {
      _writeIndexedEntityExtension(buffer, info, indexedAvailability);
    }
  }

  /// The Swift stored-property name for [prop].
  ///
  /// `AppEntity` refines `Identifiable`, which requires a property literally
  /// named `id`; the Dart field backing `@EntityId` may be called anything
  /// (`teamId`, `uuid`, ...). So the identifier property is always emitted as
  /// `id` and the Dart field name survives only as the cache/dictionary key
  /// (see [_writeEntityDictMapping]). Every other property keeps its Dart name.
  String _swiftPropertyName(EntityPropertyInfo prop) =>
      prop.role == EntityPropertyRole.id ? 'id' : prop.fieldName;

  /// Rejects the one case [_swiftPropertyName] cannot normalize: the `@EntityId`
  /// field is named something other than `id`, while a *different* property is
  /// literally named `id`. Normalizing would emit two `var id` declarations.
  void _validateIdPropertyName(EntityInfo info) {
    final idProp = info.properties
        .where((p) => p.role == EntityPropertyRole.id)
        .firstOrNull;
    if (idProp == null || idProp.fieldName == 'id') return;
    final collides = info.properties.any(
      (p) => p.role != EntityPropertyRole.id && p.fieldName == 'id',
    );
    if (!collides) return;
    throw InvalidGenerationSourceError(
      'Entity `${info.className}` marks `${idProp.fieldName}` with @EntityId '
      'but also declares a separate field named `id`. The generated Swift '
      'entity must expose its identifier as `id` (AppEntity refines '
      'Identifiable), so both fields would collide. Rename the non-identifier '
      '`id` field, or move @EntityId onto it.',
    );
  }

  /// Writes the entity's stored properties, using `@Property(...)` for fields
  /// marked with `@EntityProperty`.
  void _writeEntityProperties(
    StringBuffer buffer,
    EntityInfo info, [
    bool dualId = false,
  ]) {
    for (final prop in info.properties) {
      final swiftType = prop.role == EntityPropertyRole.id
          ? _entityIdSwiftType(dualId)
          : dartTypeToSwiftType(prop.dartType);
      if (prop.exposeAsProperty) {
        buffer.writeln('$_indent${_propertyAttribute(prop)}');
      }
      buffer.writeln('${_indent}var ${_swiftPropertyName(prop)}: $swiftType');
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
  void _writeEntityInit(
    StringBuffer buffer,
    EntityInfo info, [
    bool dualId = false,
  ]) {
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
          final swiftType = prop.role == EntityPropertyRole.id
              ? _entityIdSwiftType(dualId)
              : dartTypeToSwiftType(prop.dartType);
          final name = _swiftPropertyName(prop);
          // Every non-role property (exposed @Property or @EntityExportField)
          // gets a default so the role-only construction in the generated
          // queries keeps compiling.
          if (prop.role == EntityPropertyRole.none) {
            return '$name: $swiftType = '
                '${_defaultForSwiftType(swiftType, prop.fieldName)}';
          }
          return '$name: $swiftType';
        })
        .join(', ');
    buffer.writeln('${_indent}init($params) {');
    for (final prop in ordered) {
      final name = _swiftPropertyName(prop);
      buffer.writeln('$_indent${_indent}self.$name = $name');
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
    // `_extractProperties` keeps only role-annotated, exposed or export-role
    // fields, so every remaining (role == none) property is an
    // @EntityProperty/@EntityExportField one and is given a default below —
    // the call site may safely omit it.
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
    bool dualId = false,
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
      '${_indent}func entities(for identifiers: [${_entityIdSwiftType(dualId)}]) '
      'async throws -> [${info.className}] {',
    );
    if (dualId) {
      // The bridge speaks plain strings, and Dart may key its data on either
      // half — the local id it assigned or the stable one the server did. Both
      // halves are sent so the handler can match whichever it stores.
      buffer.writeln(
        '$_indent${_indent}let identifierStrings = identifiers.flatMap { pair in',
      );
      buffer.writeln(
        '$_indent$_indent$_indent[pair.local, pair.stable].compactMap { \$0 }',
      );
      buffer.writeln('$_indent$_indent}');
    }
    final identifierList = dualId ? 'identifierStrings' : 'identifiers';
    if (cacheKey != null) {
      // Filtering reads the Swift stored property, which is always `id`.
      buffer.writeln(
        '$_indent${_indent}if let cached = Self._readCachedEntities() {',
      );
      final predicate = dualId
          ? 'identifierStrings.contains(\$0.id.local ?? "") '
                '|| identifierStrings.contains(\$0.id.stable ?? "")'
          : 'identifiers.contains(\$0.id)';
      buffer.writeln(
        '$_indent$_indent${_indent}let filtered = cached.filter { $predicate }',
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
    buffer.writeln('$_indent$_indent${_indent}identifiers: $identifierList');
    buffer.writeln('$_indent$_indent)');
    buffer.writeln('$_indent${_indent}return results.compactMap { dict in');
    _writeEntityDictMapping(
      buffer,
      info,
      idProp,
      titleProp,
      subtitleProp,
      imageProp,
      dualId: dualId,
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
      dualId: dualId,
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
        dualId: dualId,
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
    EntityPropertyInfo? imageProp, {
    bool dualId = false,
  }) {
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
      dualId: dualId,
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
    EntityPropertyInfo? imageProp, {
    int depth = 3,
    bool dualId = false,
  }) {
    // The dictionary key is the Dart field name (that is what the Dart cache
    // projection writes); the Swift local and initializer label are normalized
    // to `id` to match the stored property (see [_swiftPropertyName]).
    final idKey = idProp?.fieldName ?? 'id';
    const id = 'id';
    final title = titleProp?.fieldName ?? 'title';
    // Callers embed this block at different nesting levels (a query's
    // `compactMap` closure vs. an import closure inside a Transferable
    // extension), so the leading indent is a parameter rather than a literal.
    final indent = _indent * depth;
    final nested = '$indent$_indent';

    buffer.writeln('${indent}guard let $id = dict["$idKey"] as? String,');
    buffer.writeln('${nested}let $title = dict["$title"] as? String else {');
    buffer.writeln('${nested}return nil');
    buffer.writeln('$indent}');

    if (subtitleProp != null) {
      final subtitle = subtitleProp.fieldName;
      buffer.writeln('${indent}let $subtitle = dict["$subtitle"] as? String');
    }

    if (imageProp != null) {
      final image = imageProp.fieldName;
      buffer.writeln('${indent}let $image = dict["$image"] as? String');
    }

    // Non-role fields (exposed @Property and @EntityExportField) are read from
    // the dict so semantic content and export values are populated. A type with
    // no dict representation (e.g. Date) is skipped and keeps the initializer's
    // default — omitting a defaulted argument is legal as long as the ones that
    // remain stay in declaration order, which [_initOrderedProperties] fixes.
    final extraProps = info.properties
        .where(
          (p) =>
              p.role == EntityPropertyRole.none &&
              _dictReadCast(p.dartType) != null,
        )
        .toList();
    for (final prop in extraProps) {
      buffer.writeln(
        '${indent}let ${prop.fieldName} = '
        'dict["${prop.fieldName}"] as? ${_dictReadCast(prop.dartType)}',
      );
    }

    // Build initializer. With a dual identifier the local id is paired with
    // the stable one; an entity dictionary that predates the stable field (or
    // has not been re-projected yet) falls back to the local id on both halves
    // rather than dropping the row.
    final stableField = info.stableIdProperty?.fieldName;
    final idArgument = dualId && stableField != null
        ? 'SyncableEntityIdentifier(local: $id, stable: $stableField ?? $id)'
        : id;
    final initParts = <String>['$id: $idArgument', '$title: $title'];
    // subtitle/image are read from the dict as `String?`; coalesce to a
    // non-optional value when the entity field is declared non-optional (the
    // local read is always optional, but the struct field type follows the Dart
    // type). Mirrors the exposed-property handling below.
    if (subtitleProp != null) {
      final value = subtitleProp.dartType.endsWith('?')
          ? subtitleProp.fieldName
          : '${subtitleProp.fieldName} ?? ""';
      initParts.add('${subtitleProp.fieldName}: $value');
    }
    if (imageProp != null) {
      final value = imageProp.dartType.endsWith('?')
          ? imageProp.fieldName
          : '${imageProp.fieldName} ?? ""';
      initParts.add('${imageProp.fieldName}: $value');
    }
    for (final prop in extraProps) {
      final swiftType = dartTypeToSwiftType(prop.dartType);
      final value = prop.dartType.endsWith('?')
          ? prop.fieldName
          : '${prop.fieldName} ?? '
                '${_defaultForSwiftType(swiftType, prop.fieldName)}';
      initParts.add('${prop.fieldName}: $value');
    }
    buffer.writeln(
      '${indent}return ${info.className}(${initParts.join(', ')})',
    );
  }

  /// The Swift type a non-role entity field is read back as from an entity
  /// dictionary, or `null` when the type has no dictionary representation (the
  /// field then keeps its initializer default).
  ///
  /// Numbers cross the MethodChannel — and come out of JSON — as `NSNumber`,
  /// which conditionally casts to whichever Swift numeric type is asked for, so
  /// an `int` written from Dart still reads back into a `Double` latitude.
  String? _dictReadCast(String dartType) {
    switch (dartType) {
      case 'String':
      case 'String?':
        return 'String';
      case 'double':
      case 'double?':
        return 'Double';
      case 'int':
      case 'int?':
        return 'Int';
      case 'bool':
      case 'bool?':
        return 'Bool';
      default:
        return null;
    }
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
    List<UnionInfo> unions = const [],
    String? appIntentsPackage,
    List<String> includedPackages = const [],
  }) {
    _validateDualIdentifierUsage(intents, entities);

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
    // `.result(view:)` lives in the _AppIntents_SwiftUI overlay, which is only
    // pulled in by importing SwiftUI alongside AppIntents.
    if (intents.any((i) => i.snippet != null)) {
      buffer.writeln('import SwiftUI');
    }
    for (final module in _includedPackageModules(includedPackages)) {
      buffer.writeln('import $module');
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

    // Generate @UnionValue enums (before intents that reference them). Only
    // emitted when the rich-types feature is on — `@UnionValue`/`AppUnionValue`
    // is iOS 27+, so on the stable `#else` the union type doesn't exist and a
    // union parameter falls back to its first case's entity type instead.
    final allUnions = _collectUnions(intents, unions);
    final decodedUnionEntities = <String>{};
    for (final union in allUnions) {
      _generateUnionEnum(buffer, union);
      buffer.writeln();
      buffer.writeln();
      // #133: a union-returning IntentValueQuery — one query answering with
      // several entity types, which is the shape free-text and visual search
      // need (the system allows a single query per input type).
      if (union.valueQuery) {
        _writeUnionValueQuery(buffer, union, entities, decodedUnionEntities);
        buffer.writeln();
        buffer.writeln();
      }
    }

    // Generate intents (without individual imports)
    for (final intent in intents) {
      // The snippet view comes first: `perform()` constructs it, so keeping
      // them adjacent makes the generated file readable top to bottom.
      if (intent.snippet != null) {
        _writeSnippetView(buffer, intent);
        buffer.writeln();
        buffer.writeln();
      }
      _generateIntentBody(buffer, intent);
      // #55 intent donation: additive reverse executor, in its own #if block
      // (no #else — without the flag the intent simply isn't donatable). The
      // `donate()` symbol is stable iOS 16+ but we gate behind the donation
      // feature for consistency. See ADR 0003.
      if (experimental.isEnabled(ExperimentalFeature.donation) &&
          intent.donatable) {
        buffer.writeln();
        buffer.writeln();
        _writeIntentDonator(buffer, intent);
      }
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

    if (appIntentsPackage != null) {
      buffer.writeln();
      _writeAppIntentsPackage(buffer, appIntentsPackage, includedPackages);
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Rejects the one combination a dual identifier (#132) cannot serve: an
  /// entity whose id is a `SyncableEntityIdentifier` used as an intent
  /// parameter.
  ///
  /// An entity parameter is serialized to Dart as `<param>.id`, which for a
  /// dual identifier is a struct the MethodChannel cannot carry. Rendering it
  /// through `entityIdentifierString` instead would hand the Dart handler a
  /// composite string none of its own records are keyed by — a silent
  /// mismatch. Failing generation says so out loud instead.
  void _validateDualIdentifierUsage(
    List<IntentInfo> intents,
    List<EntityInfo> entities,
  ) {
    final dualIdClasses = entities
        .where(_usesDualIdentifier)
        .map((e) => e.className)
        .toSet();
    if (dualIdClasses.isEmpty) return;
    for (final intent in intents) {
      for (final param in intent.parameters) {
        // A union case serializes as `["_type": …, "id": e.id]` too, so it
        // hits the same wall as a direct entity parameter.
        final used = <String?>[
          param.entityType,
          param.entityCollectionType,
          ...?param.unionInfo?.cases.map((c) => c.entityType),
        ].whereType<String>().where(dualIdClasses.contains).firstOrNull;
        if (used == null) continue;
        throw InvalidGenerationSourceError(
          'Intent `${intent.className}` takes `$used` as the parameter '
          '"${param.fieldName}", but that entity declares an @EntityStableId '
          '(dual SyncableEntityIdentifier). A dual identifier has no single '
          'string form the Dart handler could match, so entity parameters of '
          'such an entity are not supported yet. Drop @EntityStableId, or '
          'pass the identifier as a plain String parameter.',
        );
      }
    }
  }

  /// Writes an `AppIntentsPackage` conformance.
  ///
  /// Worth knowing before reaching for this: whether a target sees another
  /// module's intents is decided by **how it links**, not by this declaration.
  /// Xcode's SPM links statically by default, and a statically linked
  /// dependency's extracted metadata is merged into the consumer with no
  /// declaration at all. Apple's own guidance is conditional — use an App
  /// Intents Package "when referencing code not compiled into a static
  /// library". So this exists for the dynamic-linking case (and as the
  /// documented belt-and-braces form); it is not a fix for "my intent does not
  /// show up", which is a target-membership or link-form problem.
  void _writeAppIntentsPackage(
    StringBuffer buffer,
    String name,
    List<String> includedPackages,
  ) {
    buffer.writeln('@available(iOS 17.0, *)');
    if (includedPackages.isEmpty) {
      buffer.writeln('struct $name: AppIntentsPackage {}');
      return;
    }
    final types = includedPackages.map(_packageTypeReference).join(', ');
    buffer.writeln('struct $name: AppIntentsPackage {');
    buffer.writeln('${_indent}static var includedPackages:');
    buffer.writeln('$_indent$_indent[any AppIntentsPackage.Type] {');
    buffer.writeln('$_indent$_indent$_indent[$types]');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('}');
  }

  /// The modules an `includedPackages` list needs imported, from the module
  /// prefix of each fully qualified type name.
  Set<String> _includedPackageModules(List<String> includedPackages) => {
    for (final qualified in includedPackages)
      if (qualified.contains('.')) qualified.split('.').first,
  };

  /// The Swift expression naming a package type from its qualified name.
  ///
  /// Only the **module** prefix is dropped: importing `SharedIntents` makes
  /// `Groups.SharedPackage` reachable, not `SharedPackage`, so the rest of the
  /// path has to survive.
  String _packageTypeReference(String qualified) {
    final segments = qualified.split('.');
    final path = segments.length > 1 ? segments.skip(1).join('.') : qualified;
    return '$path.self';
  }

  /// Generates intent body without import statement.
  ///
  /// When experimental execution control is enabled for this intent, emits two
  /// variants guarded by a compilation condition: the WWDC26 form inside
  /// `#if APP_INTENTS_WWDC26` and the stable form inside `#else`, so projects
  /// that build against a released SDK (without the `APP_INTENTS_WWDC26` flag)
  /// still compile.
  /// The distinct unions referenced by [intents]' parameters, or empty when the
  /// rich-types feature is off (in which case union parameters fall back to
  /// their first case's entity type and no `@UnionValue enum` is needed).
  List<UnionInfo> _distinctUnions(List<IntentInfo> intents) {
    if (!experimental.isEnabled(ExperimentalFeature.richTypes)) {
      return const [];
    }
    final seen = <String>{};
    final unions = <UnionInfo>[];
    for (final intent in intents) {
      for (final param in intent.parameters) {
        final union = param.unionInfo;
        if (union != null && seen.add(union.className)) {
          unions.add(union);
        }
      }
    }
    return unions;
  }

  /// Every union to emit: those reached through an intent parameter, plus any
  /// declared standalone (a union that only exists to be returned by a value
  /// query is referenced by no parameter at all).
  List<UnionInfo> _collectUnions(
    List<IntentInfo> intents,
    List<UnionInfo> declared,
  ) {
    if (!experimental.isEnabled(ExperimentalFeature.richTypes)) {
      return const [];
    }
    final byName = <String, UnionInfo>{};
    for (final union in _distinctUnions(intents)) {
      byName[union.className] = union;
    }
    // A declared union wins: it carries the flags from the annotation, while
    // the parameter-derived copy is the same analysis of the same class.
    for (final union in declared) {
      byName[union.className] = union;
    }
    return byName.values.toList();
  }

  /// Writes an `IntentValueQuery` returning a `@UnionValue` (#133).
  ///
  /// Each result dictionary carries a `_type` naming the union case, so one
  /// Dart handler can answer with a mix of entity types. Building each case's
  /// entity reuses the same dictionary mapping the entity's own query uses,
  /// emitted here as a `fileprivate` helper per case entity.
  void _writeUnionValueQuery(
    StringBuffer buffer,
    UnionInfo union,
    List<EntityInfo> entities,
    Set<String> decodedUnionEntities,
  ) {
    final byClassName = {for (final e in entities) e.className: e};
    for (final c in union.cases) {
      if (byClassName.containsKey(c.entityType)) continue;
      throw InvalidGenerationSourceError(
        'Union `${union.className}` declares a value query, but its case '
        '`${c.dartClassName}` names the entity `${c.entityType}`, which has no '
        '@EntitySpec in this generation run. The query has to build that '
        'entity from the handler\'s result, so the entity must be generated '
        'alongside the union.',
      );
    }

    buffer.writeln('#if APP_INTENTS_WWDC26');
    // One decoding helper per case entity, so the switch below stays readable
    // and the mapping is not duplicated inline per case.
    for (final c in union.cases) {
      // One helper per entity type across the whole file: two cases (or two
      // unions) naming the same entity would otherwise redeclare it.
      if (!decodedUnionEntities.add(c.entityType)) continue;
      final entity = byClassName[c.entityType]!;
      _writeUnionCaseDecoder(buffer, entity);
      buffer.writeln();
    }
    buffer.writeln('@available(iOS 27.0, *)');
    buffer.writeln('struct ${union.className}ValueQuery: IntentValueQuery {');
    buffer.writeln(
      '${_indent}func values(for input: String) async throws -> [${union.className}] {',
    );
    buffer.writeln(
      '$_indent${_indent}let results = try await FlutterBridge.shared.queryValues(',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}queryIdentifier: "${union.identifier}",',
    );
    buffer.writeln('$_indent$_indent${_indent}input: ["query": input]');
    buffer.writeln('$_indent$_indent)');
    buffer.writeln(
      '$_indent${_indent}return results.compactMap { dict -> ${union.className}? in',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}switch dict["_type"] as? String {',
    );
    for (final c in union.cases) {
      buffer.writeln('$_indent$_indent${_indent}case "${c.dartClassName}":');
      buffer.writeln(
        '$_indent$_indent$_indent${_indent}return ${c.entityType}._fromUnionDictionary(dict)',
      );
      buffer.writeln(
        '$_indent$_indent$_indent$_indent$_indent.map(${union.className}.${c.swiftCaseName})',
      );
    }
    buffer.writeln('$_indent$_indent${_indent}default:');
    buffer.writeln('$_indent$_indent$_indent${_indent}return nil');
    buffer.writeln('$_indent$_indent$_indent}');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
    buffer.write('#endif');
  }

  /// Writes the `fileprivate static func _fromUnionDictionary` helper a
  /// union-returning value query uses to rebuild one case's entity.
  void _writeUnionCaseDecoder(StringBuffer buffer, EntityInfo info) {
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

    buffer.writeln('@available(iOS 27.0, *)');
    buffer.writeln('extension ${info.className} {');
    buffer.writeln(
      '$_indent'
      'fileprivate static func _fromUnionDictionary(_ dict: [String: Any]) '
      '-> ${info.className}? {',
    );
    _writeEntityDictMapping(
      buffer,
      info,
      idProp,
      titleProp,
      subtitleProp,
      imageProp,
      depth: 2,
      dualId: _usesDualIdentifier(info),
    );
    buffer.writeln('$_indent}');
    buffer.writeln('}');
  }

  /// Writes a `@UnionValue enum`, gated by `#if APP_INTENTS_WWDC26` (no `#else`:
  /// the type can't exist on the stable SDK).
  void _generateUnionEnum(StringBuffer buffer, UnionInfo union) {
    buffer.writeln('#if APP_INTENTS_WWDC26');
    buffer.writeln('@available(iOS 27.0, *)');
    buffer.writeln('@UnionValue');
    buffer.writeln('enum ${union.className} {');
    for (final c in union.cases) {
      buffer.writeln('${_indent}case ${c.swiftCaseName}(${c.entityType})');
    }
    buffer.writeln('}');
    buffer.write('#endif');
  }

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
    List<IntentParamInfo> params, {
    IntentInfo? info,
  }) {
    var result = template;
    // Escape double quotes for Swift string literals
    result = result.replaceAll('"', '\\"');
    // `{result.key}` reads the handler's return value, via the same local the
    // snippet uses. Without this the placeholder would reach Siri verbatim.
    if (info != null) {
      for (final key in _snippetResultKeys(info)) {
        result = substitutePlaceholder(
          result,
          '$resultPlaceholderPrefix$key',
          '\\(${_snippetResultLocal(key)})',
        );
      }
    }
    for (final param in params) {
      result = substitutePlaceholder(
        result,
        param.fieldName,
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
