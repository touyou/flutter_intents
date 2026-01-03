import '../models/entity_info.dart';
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
/// This generator produces Swift code that can be used in iOS 16+ applications
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
  /// - `@available(iOS 16.0, *)` availability attribute
  /// - Static title and optional description
  /// - `@Parameter` properties for each intent parameter
  /// - A `perform()` method that calls FlutterBridge
  String generateIntent(IntentInfo info) {
    final buffer = StringBuffer();

    // Import statement
    buffer.writeln('import AppIntents');
    buffer.writeln();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 16.0, *)');
    buffer.writeln('struct ${info.className}: AppIntent {');

    // Title
    buffer.writeln('$_indent' 'static var title: LocalizedStringResource = "${info.title}"');

    // Description (if present)
    if (info.description != null) {
      buffer.writeln('$_indent' 'static var description: IntentDescription =');
      buffer.writeln('$_indent$_indent' 'IntentDescription("${info.description}")');
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

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Writes a parameter declaration to the buffer.
  void _writeParameter(StringBuffer buffer, IntentParamInfo param) {
    final swiftType = dartTypeToSwiftType(param.dartType);

    // Build @Parameter annotation
    final paramParts = <String>['title: "${param.title}"'];
    if (param.description != null) {
      paramParts.add('description: "${param.description}"');
    }
    buffer.writeln('$_indent@Parameter(${paramParts.join(', ')})');
    buffer.writeln('${_indent}var ${param.fieldName}: $swiftType');
  }

  /// Writes the perform method to the buffer.
  void _writePerformMethod(StringBuffer buffer, IntentInfo info) {
    buffer.writeln('$_indent@MainActor');
    buffer.writeln('${_indent}func perform() async throws -> some IntentResult {');

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
        buffer.writeln('$_indent$_indent$_indent$_indent"${param.fieldName}": ${param.fieldName}$comma');
      }
      buffer.writeln('$_indent$_indent$_indent]');
      buffer.writeln('$_indent$_indent)');
    }

    buffer.writeln('$_indent${_indent}return .result()');
    buffer.writeln('$_indent}');
  }

  /// Generates a Swift AppEntity struct from an [EntityInfo].
  ///
  /// The generated struct includes:
  /// - `@available(iOS 16.0, *)` availability attribute
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
    buffer.writeln('@available(iOS 16.0, *)');
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

    buffer.writeln('${_indent}var displayRepresentation: DisplayRepresentation {');

    if (titleProp == null) {
      // Fallback to id if no title property
      buffer.writeln('$_indent${_indent}DisplayRepresentation(title: "\\(id)")');
    } else if (subtitleProp == null) {
      buffer.writeln('$_indent${_indent}DisplayRepresentation(title: "\\(${titleProp.fieldName})")');
    } else {
      // Handle nullable subtitle
      final subtitleExpr = subtitleProp.dartType.endsWith('?')
          ? '${subtitleProp.fieldName} ?? ""'
          : subtitleProp.fieldName;
      buffer.writeln('$_indent${_indent}DisplayRepresentation(title: "\\(${titleProp.fieldName})", subtitle: "\\($subtitleExpr)")');
    }

    buffer.writeln('$_indent}');
  }

  /// Writes the entity query struct.
  void _writeQueryStruct(StringBuffer buffer, EntityInfo info) {
    buffer.writeln('@available(iOS 16.0, *)');
    buffer.writeln('struct ${info.className}Query: EntityQuery {');
    buffer.writeln('${_indent}func entities(for identifiers: [String]) async throws -> [${info.className}] {');
    buffer.writeln('$_indent$_indent// TODO: Implement entity fetching via FlutterBridge');
    buffer.writeln('$_indent${_indent}return []');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
  }

  /// Generates an AppShortcutsProvider struct from shortcut information.
  ///
  /// The generated struct includes:
  /// - `@available(iOS 16.0, *)` availability attribute
  /// - Static `appShortcuts` property with all configured shortcuts
  String generateAppShortcutsProvider(List<AppShortcutInfo> shortcuts) {
    final buffer = StringBuffer();

    // Import statement
    buffer.writeln('import AppIntents');
    buffer.writeln();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 16.0, *)');
    buffer.writeln('struct AppShortcuts: AppShortcutsProvider {');
    buffer.writeln('${_indent}static var appShortcuts: [AppShortcut] {');
    buffer.writeln('$_indent$_indent[');

    for (var i = 0; i < shortcuts.length; i++) {
      final shortcut = shortcuts[i];
      final comma = i < shortcuts.length - 1 ? ',' : '';

      buffer.writeln('$_indent$_indent${_indent}AppShortcut(');
      buffer.writeln('$_indent$_indent$_indent${_indent}intent: ${shortcut.intentClassName}(),');
      buffer.writeln('$_indent$_indent$_indent${_indent}phrases: [');
      for (var j = 0; j < shortcut.phrases.length; j++) {
        final phraseComma = j < shortcut.phrases.length - 1 ? ',' : '';
        buffer.writeln('$_indent$_indent$_indent$_indent$_indent"${shortcut.phrases[j]}"$phraseComma');
      }
      buffer.writeln('$_indent$_indent$_indent$_indent],');
      buffer.writeln('$_indent$_indent$_indent${_indent}shortTitle: "${shortcut.shortTitle}",');
      buffer.writeln('$_indent$_indent$_indent${_indent}systemImageName: "${shortcut.systemImageName}"');
      buffer.writeln('$_indent$_indent$_indent)$comma');
    }

    buffer.writeln('$_indent$_indent]');
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
  }) {
    final buffer = StringBuffer();

    // Single import at the top
    buffer.writeln('import AppIntents');
    buffer.writeln();

    // Generate intents (without individual imports)
    for (final intent in intents) {
      buffer.writeln(_generateIntentBody(intent));
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
  String _generateIntentBody(IntentInfo info) {
    final buffer = StringBuffer();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 16.0, *)');
    buffer.writeln('struct ${info.className}: AppIntent {');

    // Title
    buffer.writeln('$_indent' 'static var title: LocalizedStringResource = "${info.title}"');

    // Description (if present)
    if (info.description != null) {
      buffer.writeln('$_indent' 'static var description: IntentDescription =');
      buffer.writeln('$_indent$_indent' 'IntentDescription("${info.description}")');
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

    return buffer.toString();
  }

  /// Generates entity body without import statement.
  String _generateEntityBody(EntityInfo info) {
    final buffer = StringBuffer();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 16.0, *)');
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
    buffer.writeln('@available(iOS 16.0, *)');
    buffer.writeln('struct ${info.className}Query: EntityQuery {');
    buffer.writeln('${_indent}func entities(for identifiers: [String]) async throws -> [${info.className}] {');
    buffer.writeln('$_indent$_indent// TODO: Implement entity fetching via FlutterBridge');
    buffer.writeln('$_indent${_indent}return []');
    buffer.writeln('$_indent}');
    buffer.write('}');

    return buffer.toString();
  }

  /// Generates shortcuts provider body without import statement.
  String _generateShortcutsProviderBody(List<AppShortcutInfo> shortcuts) {
    final buffer = StringBuffer();

    // Availability and struct declaration
    buffer.writeln('@available(iOS 16.0, *)');
    buffer.writeln('struct AppShortcuts: AppShortcutsProvider {');
    buffer.writeln('${_indent}static var appShortcuts: [AppShortcut] {');
    buffer.writeln('$_indent$_indent[');

    for (var i = 0; i < shortcuts.length; i++) {
      final shortcut = shortcuts[i];
      final comma = i < shortcuts.length - 1 ? ',' : '';

      buffer.writeln('$_indent$_indent${_indent}AppShortcut(');
      buffer.writeln('$_indent$_indent$_indent${_indent}intent: ${shortcut.intentClassName}(),');
      buffer.writeln('$_indent$_indent$_indent${_indent}phrases: [');
      for (var j = 0; j < shortcut.phrases.length; j++) {
        final phraseComma = j < shortcut.phrases.length - 1 ? ',' : '';
        buffer.writeln('$_indent$_indent$_indent$_indent$_indent"${shortcut.phrases[j]}"$phraseComma');
      }
      buffer.writeln('$_indent$_indent$_indent$_indent],');
      buffer.writeln('$_indent$_indent$_indent${_indent}shortTitle: "${shortcut.shortTitle}",');
      buffer.writeln('$_indent$_indent$_indent${_indent}systemImageName: "${shortcut.systemImageName}"');
      buffer.writeln('$_indent$_indent$_indent)$comma');
    }

    buffer.writeln('$_indent$_indent]');
    buffer.writeln('$_indent}');
    buffer.write('}');

    return buffer.toString();
  }
}
