import '../models/entity_info.dart';
import '../models/enum_info.dart';
import '../models/intent_info.dart';

/// Generates Kotlin code for Android AppFunctions from analyzed Dart specifications.
///
/// This generator produces Kotlin code that can be used in Android 16+ applications
/// to integrate with the AppFunctions framework (Jetpack `androidx.appfunctions`).
class KotlinGenerator {
  /// Mapping of Dart types to Kotlin types.
  static const _typeMapping = <String, String>{
    'String': 'String',
    'int': 'Int',
    'double': 'Double',
    'bool': 'Boolean',
    'DateTime': 'String', // ISO8601 string
    'IntentFile': 'String', // File URI/path — KSP doesn't support IntentFile
  };

  /// Indentation used for generated Kotlin code.
  static const _indent = '    ';

  /// Converts a Dart type to its Kotlin equivalent.
  ///
  /// Handles nullable types by preserving the `?` suffix.
  /// Unknown types are returned as-is.
  String dartTypeToKotlinType(String dartType) {
    final isNullable = dartType.endsWith('?');
    final baseType = isNullable
        ? dartType.substring(0, dartType.length - 1)
        : dartType;
    final kotlinBaseType = _typeMapping[baseType] ?? baseType;
    return isNullable ? '$kotlinBaseType?' : kotlinBaseType;
  }

  /// Derives a function name from an intent identifier.
  ///
  /// e.g., 'com.example.taskapp.createTask' -> 'createTask'
  String _functionName(String identifier) {
    final parts = identifier.split('.');
    return parts.last;
  }

  /// Converts a camelCase name to UPPER_SNAKE_CASE for Kotlin.
  String _toUpperSnakeCase(String name) {
    return name
        .replaceAllMapped(
          RegExp(r'(?<=[a-z0-9])([A-Z])'),
          (match) => '_${match.group(1)}',
        )
        .toUpperCase();
  }

  /// Generates a Kotlin @AppFunction method from an [IntentInfo].
  String generateIntent(IntentInfo info) {
    final buffer = StringBuffer();

    buffer.writeln('import androidx.appfunctions.service.AppFunction');
    buffer.writeln('import androidx.appfunctions.AppFunctionContext');
    buffer.writeln();

    _generateIntentMethod(buffer, info);

    return buffer.toString();
  }

  /// Generates a Kotlin @AppFunctionSerializable data class from an [EntityInfo].
  String generateEntity(EntityInfo info) {
    final buffer = StringBuffer();

    buffer.writeln('import androidx.appfunctions.AppFunctionSerializable');
    buffer.writeln();

    _generateEntityBody(buffer, info);

    return buffer.toString();
  }

  /// Generates a Kotlin enum class from an [EnumInfo].
  String generateEnum(EnumInfo info) {
    final buffer = StringBuffer();
    _generateEnumBody(buffer, info);
    return buffer.toString();
  }

  /// Generates the AppFunctionsBridge class.
  String generateBridge() {
    final buffer = StringBuffer();
    _generateBridgeBody(buffer);
    return buffer.toString();
  }

  /// Generates a complete Kotlin file containing all intents, entities, enums,
  /// and the bridge class.
  String generateAll({
    required String packageName,
    List<IntentInfo> intents = const [],
    List<EntityInfo> entities = const [],
    List<EnumInfo> enums = const [],
  }) {
    final buffer = StringBuffer();

    // Package declaration
    buffer.writeln('package $packageName');
    buffer.writeln();

    // Imports
    final imports = <String>{};
    if (intents.isNotEmpty) {
      imports.add('import androidx.appfunctions.service.AppFunction');
      imports.add('import androidx.appfunctions.AppFunctionContext');
    }
    if (entities.isNotEmpty) {
      imports.add('import androidx.appfunctions.AppFunctionSerializable');
    }
    imports.add('import io.flutter.plugin.common.MethodChannel');
    imports.add('import kotlinx.coroutines.Dispatchers');
    imports.add('import kotlinx.coroutines.suspendCancellableCoroutine');
    imports.add('import kotlinx.coroutines.withContext');
    imports.add('import kotlin.coroutines.resume');
    imports.add('import kotlin.coroutines.resumeWithException');

    for (final imp in imports.toList()..sort()) {
      buffer.writeln(imp);
    }
    buffer.writeln();

    // Generate enums (before intents, since intents may reference them)
    for (final enumInfo in enums) {
      _generateEnumBody(buffer, enumInfo);
      buffer.writeln();
      buffer.writeln();
    }

    // Generate entities
    for (final entity in entities) {
      _generateEntityBody(buffer, entity);
      buffer.writeln();
      buffer.writeln();
    }

    // Generate bridge class
    _generateBridgeBody(buffer);
    buffer.writeln();
    buffer.writeln();

    // Generate AppFunctions class with all intent methods
    if (intents.isNotEmpty) {
      _generateAppFunctionsClass(buffer, intents);
    }

    return buffer.toString();
  }

  /// Generates the AppFunctions class containing all intent methods.
  void _generateAppFunctionsClass(
    StringBuffer buffer,
    List<IntentInfo> intents,
  ) {
    buffer.writeln('/**');
    buffer.writeln(
      ' * Generated AppFunctions from Flutter Intents annotations.',
    );
    buffer.writeln(' * DO NOT MODIFY BY HAND.');
    buffer.writeln(' */');
    buffer.writeln('class GeneratedAppFunctions {');
    buffer.writeln('${_indent}private val bridge: AppFunctionsBridge');
    buffer.writeln(
      '$_indent${_indent}get() = AppFunctionsBridge.getInstance()',
    );

    for (var i = 0; i < intents.length; i++) {
      buffer.writeln();
      _generateIntentMethod(buffer, intents[i], indentLevel: 1);
    }

    buffer.writeln('}');
  }

  /// Generates a single @AppFunction method.
  void _generateIntentMethod(
    StringBuffer buffer,
    IntentInfo info, {
    int indentLevel = 0,
  }) {
    final prefix = _indent * indentLevel;
    final funcName = _functionName(info.identifier);

    // KDoc comment
    buffer.writeln('$prefix/**');
    final descText = info.description ?? info.title;
    buffer.writeln(_formatKdocLines(descText, prefix));
    buffer.writeln('$prefix *');
    buffer.writeln(
      '$prefix * @param appFunctionContext The context for this app function execution.',
    );
    for (final param in info.parameters) {
      final optionalTag = param.isOptional ? ' (optional)' : '';
      if (param.description != null) {
        buffer.writeln(
          '$prefix * @param ${param.fieldName} ${param.description}$optionalTag',
        );
      } else {
        buffer.writeln(
          '$prefix * @param ${param.fieldName} ${param.title}$optionalTag',
        );
      }
    }
    buffer.writeln('$prefix */');

    // @AppFunction annotation
    buffer.writeln('$prefix@AppFunction(isDescribedByKDoc = true)');

    // Function signature
    final paramStrings = <String>['appFunctionContext: AppFunctionContext'];
    for (final param in info.parameters) {
      final kotlinType = _kotlinParamType(param);
      if (param.isOptional || param.dartType.endsWith('?')) {
        paramStrings.add('${param.fieldName}: $kotlinType = null');
      } else {
        paramStrings.add('${param.fieldName}: $kotlinType');
      }
    }

    buffer.writeln('${prefix}suspend fun $funcName(');
    for (var i = 0; i < paramStrings.length; i++) {
      final comma = i < paramStrings.length - 1 ? ',' : '';
      buffer.writeln('$prefix$_indent${paramStrings[i]}$comma');
    }
    buffer.writeln('$prefix): String {');

    // Function body: build params map and delegate to bridge
    buffer.writeln(
      '$prefix${_indent}val params = mutableMapOf<String, Any?>()',
    );
    for (final param in info.parameters) {
      final value = _paramValueExpression(param);
      if (param.isOptional || param.dartType.endsWith('?')) {
        buffer.writeln(
          '$prefix${_indent}if (${param.fieldName} != null) params["${param.fieldName}"] = $value',
        );
      } else {
        buffer.writeln(
          '$prefix${_indent}params["${param.fieldName}"] = $value',
        );
      }
    }
    buffer.writeln(
      '$prefix${_indent}return bridge.executeIntent("${info.identifier}", params)',
    );
    buffer.writeln('$prefix}');
  }

  /// Returns the Kotlin type for a parameter, considering entity/enum types.
  String _kotlinParamType(IntentParamInfo param) {
    // For entity and enum types on Android, use String (the raw value)
    // since AppFunctions alpha doesn't have picker UI
    return dartTypeToKotlinType(param.dartType);
  }

  /// Returns the Kotlin expression for a parameter value in the params map.
  ///
  /// File parameters (fileType != null) are wrapped in a map with path,
  /// mimeType, and filename so the Dart side can reconstruct IntentFile
  /// via IntentFile.fromMap().
  String _paramValueExpression(IntentParamInfo param) {
    if (param.fileType != null) {
      final f = param.fieldName;
      return 'mapOf("path" to $f, '
          '"mimeType" to java.net.URLConnection.guessContentTypeFromName($f), '
          '"filename" to java.io.File($f).name)';
    }
    return param.fieldName;
  }

  /// Generates a @AppFunctionSerializable data class body.
  void _generateEntityBody(StringBuffer buffer, EntityInfo info) {
    // KDoc comment
    buffer.writeln('/**');
    final descText = info.description ?? info.title;
    buffer.writeln(_formatKdocLines(descText, ''));
    buffer.writeln(' *');

    // Filter to properties that map to data class fields
    final dataProps = info.properties
        .where(
          (p) =>
              p.role == EntityPropertyRole.id ||
              p.role == EntityPropertyRole.title ||
              p.role == EntityPropertyRole.subtitle,
        )
        .toList();

    for (final prop in dataProps) {
      buffer.writeln(
        ' * @param ${prop.fieldName} ${_propertyDescription(prop)}',
      );
    }
    buffer.writeln(' */');

    // Annotation
    buffer.writeln('@AppFunctionSerializable(isDescribedByKDoc = true)');

    // Data class
    buffer.writeln('data class ${info.className}(');
    for (var i = 0; i < dataProps.length; i++) {
      final prop = dataProps[i];
      final kotlinType = dartTypeToKotlinType(prop.dartType);
      final comma = i < dataProps.length - 1 ? ',' : '';
      if (prop.dartType.endsWith('?')) {
        buffer.writeln(
          '${_indent}val ${prop.fieldName}: $kotlinType = null$comma',
        );
      } else {
        buffer.writeln('${_indent}val ${prop.fieldName}: $kotlinType$comma');
      }
    }
    buffer.write(')');
  }

  /// Returns a human-readable description for an entity property based on its role.
  String _propertyDescription(EntityPropertyInfo prop) {
    switch (prop.role) {
      case EntityPropertyRole.id:
        return 'The unique identifier.';
      case EntityPropertyRole.title:
        return 'The display title.';
      case EntityPropertyRole.subtitle:
        return 'The subtitle or description.';
      case EntityPropertyRole.image:
        return 'The image name.';
      case EntityPropertyRole.defaultQuery:
        return 'The default query.';
      case EntityPropertyRole.none:
        return 'Property ${prop.fieldName}.';
    }
  }

  /// Generates a Kotlin enum class body.
  void _generateEnumBody(StringBuffer buffer, EnumInfo info) {
    // KDoc comment
    buffer.writeln('/**');
    buffer.writeln(' * ${info.title}');
    buffer.writeln(' */');

    buffer.writeln('enum class ${info.className}(val value: String) {');

    for (var i = 0; i < info.cases.length; i++) {
      final c = info.cases[i];
      final separator = i < info.cases.length - 1 ? ',' : ';';
      final kotlinName = _toUpperSnakeCase(c.name);
      buffer.writeln('$_indent/** ${c.displayTitle} */');
      buffer.writeln('$_indent$kotlinName("${c.name}")$separator');
    }
    buffer.writeln();
    buffer.writeln('${_indent}companion object {');
    buffer.writeln(
      '$_indent${_indent}fun fromValue(value: String): ${info.className}? =',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}entries.find { it.value == value }',
    );
    buffer.writeln('$_indent}');

    buffer.write('}');
  }

  /// Generates the AppFunctionsBridge class body.
  void _generateBridgeBody(StringBuffer buffer) {
    buffer.writeln('/**');
    buffer.writeln(
      ' * Bridge between Android AppFunctions and Flutter MethodChannel.',
    );
    buffer.writeln(
      ' * Call [initialize] with the MethodChannel from AppIntentsPlugin',
    );
    buffer.writeln(' * before any AppFunction methods are invoked.');
    buffer.writeln(' */');
    buffer.writeln(
      'class AppFunctionsBridge private constructor(private val channel: MethodChannel) {',
    );
    buffer.writeln();
    buffer.writeln('${_indent}companion object {');
    buffer.writeln(
      '$_indent${_indent}private var instance: AppFunctionsBridge? = null',
    );
    buffer.writeln();
    buffer.writeln(
      '$_indent${_indent}fun initialize(channel: MethodChannel) {',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}instance = AppFunctionsBridge(channel)',
    );
    buffer.writeln('$_indent$_indent}');
    buffer.writeln();
    buffer.writeln('$_indent${_indent}fun getInstance(): AppFunctionsBridge =');
    buffer.writeln(
      '$_indent$_indent${_indent}instance ?: throw IllegalStateException(',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent"AppFunctionsBridge not initialized. Call initialize() first."',
    );
    buffer.writeln('$_indent$_indent$_indent)');
    buffer.writeln('$_indent}');
    buffer.writeln();
    buffer.writeln('${_indent}suspend fun executeIntent(');
    buffer.writeln('$_indent${_indent}identifier: String,');
    buffer.writeln('$_indent${_indent}params: Map<String, Any?>');
    buffer.writeln('$_indent): String = withContext(Dispatchers.Main) {');
    buffer.writeln('$_indent${_indent}suspendCancellableCoroutine { cont ->');
    buffer.writeln('$_indent$_indent${_indent}channel.invokeMethod(');
    buffer.writeln('$_indent$_indent$_indent$_indent"executeIntent",');
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}mapOf("identifier" to identifier, "params" to params),',
    );
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}object : MethodChannel.Result {',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent${_indent}override fun success(result: Any?) {',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent$_indent${_indent}cont.resume(result?.toString() ?: "{}")',
    );
    buffer.writeln('$_indent$_indent$_indent$_indent$_indent}');
    buffer.writeln();
    buffer.writeln(
      '$_indent$_indent$_indent$_indent${_indent}override fun error(code: String, message: String?, details: Any?) {',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent$_indent${_indent}cont.resumeWithException(RuntimeException("\$code: \$message"))',
    );
    buffer.writeln('$_indent$_indent$_indent$_indent$_indent}');
    buffer.writeln();
    buffer.writeln(
      '$_indent$_indent$_indent$_indent${_indent}override fun notImplemented() {',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent$_indent${_indent}cont.resumeWithException(RuntimeException("Not implemented"))',
    );
    buffer.writeln('$_indent$_indent$_indent$_indent$_indent}');
    buffer.writeln('$_indent$_indent$_indent$_indent}');
    buffer.writeln('$_indent$_indent$_indent)');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
  }

  /// Formats text for KDoc comments, handling multiline descriptions.
  String _formatKdocLines(String text, String prefix) {
    return text.split('\n').map((line) => '$prefix * $line').join('\n');
  }
}
