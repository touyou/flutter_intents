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

  /// Name of the concrete `AppFunctionService` KSP generates from the
  /// `@AppFunctionServiceEntryPoint` class. This is what AndroidManifest.xml
  /// declares.
  static const serviceName = 'GeneratedAppFunctionService';

  /// Name (without `.xml`) of the AppFunction XML KSP writes into the APK's
  /// `assets/`. AndroidManifest.xml points `android.app.appfunctions.v2` at it.
  static const appFunctionXmlFileName = 'generated_app_functions';

  /// Reserved params key carrying the execution id (#130/#131).
  ///
  /// Duplicated on purpose from the plugin's `intentExecutionIdKey` and
  /// `SwiftGenerator._executionIdKey`: this package cannot depend on the
  /// Flutter plugin. The Dart side strips it before the handler sees the
  /// params and uses it to route an `intentCancelled` notice.
  static const _executionIdKey = '_executionId';

  /// Dart `AppIntentErrorCode` names and the `androidx.appfunctions` exception
  /// the generated bridge raises for each (verified against 1.0.0-alpha13).
  ///
  /// The KSP-generated service passes an `AppFunctionException` through to the
  /// caller unchanged and turns any other exception into
  /// `AppFunctionAppUnknownException`, so this is what gives an AI agent a
  /// typed error category. The keys duplicate `AppIntentErrorCode.name` in the
  /// `app_intents` plugin on purpose — this package cannot depend on Flutter —
  /// so the two lists move together. Codes not listed here fall back to
  /// [fallbackAppFunctionException] with the code kept in the message.
  static const appFunctionExceptionByErrorCode = <String, String>{
    'invalidParameters': 'AppFunctionInvalidArgumentException',
    'notFound': 'AppFunctionElementNotFoundException',
    'alreadyExists': 'AppFunctionElementAlreadyExistsException',
    'denied': 'AppFunctionDeniedException',
    'permissionRequired': 'AppFunctionPermissionRequiredException',
    'notSupported': 'AppFunctionNotSupportedException',
    'disabled': 'AppFunctionDisabledException',
    'limitExceeded': 'AppFunctionLimitExceededException',
    // The function exists (KSP registered it); the app has not wired its Dart
    // handler. An app-side problem, not a function the agent mis-named.
    'handlerNotFound': 'AppFunctionAppUnknownException',
    // Same class the dispatcher uses for a cancellation by the caller.
    'userCancelled': 'AppFunctionCancelledException',
  };

  /// Exception raised for codes outside [appFunctionExceptionByErrorCode].
  static const fallbackAppFunctionException = 'AppFunctionAppUnknownException';

  /// Lowest Android API level that has AppFunctions (Android 16).
  ///
  /// `androidx.appfunctions.AppFunctionService` is `@RequiresApi(36)`, so the
  /// generated service carries the same gate. This keeps the host app's
  /// `minSdk` untouched: the service is simply never instantiated below it.
  static const appFunctionsMinApiLevel = 36;

  /// Name of the `bool` resource the `app_intents` plugin ships (`false` by
  /// default, `true` in `values-v36/`). The host's manifest entry for
  /// [serviceName] must set `android:enabled="@bool/<this>"` so the service is
  /// disabled on devices below [appFunctionsMinApiLevel]. The attribute is
  /// required: the service is exported, and below that level its bind
  /// permission is not platform-defined, so another app could bind it and
  /// crash the host on class load.
  static const serviceEnabledBoolResource =
      'app_intents_app_functions_service_enabled';

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

  /// Generates a Kotlin @AppFunctionDeclaration method from an [IntentInfo].
  String generateIntent(IntentInfo info) {
    final buffer = StringBuffer();

    buffer.writeln('import androidx.appfunctions.AppFunctionDeclaration');
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
      imports.add('import androidx.annotation.RequiresApi');
      imports.add('import androidx.appfunctions.AppFunctionDeclaration');
      imports.add('import androidx.appfunctions.AppFunctionService');
      imports.add('import androidx.appfunctions.AppFunctionServiceEntryPoint');
    }
    if (entities.isNotEmpty) {
      imports.add('import androidx.appfunctions.AppFunctionSerializable');
    }
    imports.add('import android.os.Handler');
    imports.add('import android.os.Looper');
    imports.add('import androidx.appfunctions.AppFunctionException');
    imports.add('import androidx.appfunctions.$fallbackAppFunctionException');
    for (final exception in appFunctionExceptionByErrorCode.values) {
      imports.add('import androidx.appfunctions.$exception');
    }
    imports.add('import io.flutter.plugin.common.MethodChannel');
    imports.add('import java.util.UUID');
    imports.add('import kotlinx.coroutines.Dispatchers');
    imports.add('import kotlinx.coroutines.TimeoutCancellationException');
    imports.add('import kotlinx.coroutines.suspendCancellableCoroutine');
    imports.add('import kotlinx.coroutines.withContext');
    imports.add('import kotlinx.coroutines.withTimeout');
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
  ///
  /// Since appfunctions 1.0.0-alpha10 every `@AppFunctionDeclaration` must live in an
  /// abstract `AppFunctionService` annotated with
  /// `@AppFunctionServiceEntryPoint`; KSP generates the concrete [serviceName]
  /// subclass (with `onExecuteFunction`) and the [appFunctionXmlFileName] XML.
  void _generateAppFunctionsClass(
    StringBuffer buffer,
    List<IntentInfo> intents,
  ) {
    buffer.writeln('/**');
    buffer.writeln(
      ' * Generated AppFunctions from Flutter Intents annotations.',
    );
    buffer.writeln(' * DO NOT MODIFY BY HAND.');
    buffer.writeln(' *');
    buffer.writeln(
      ' * AppFunctions exist on Android 16 (API $appFunctionsMinApiLevel) and later only; the host app',
    );
    buffer.writeln(
      ' * keeps its own minSdk. The AndroidManifest.xml entry for [$serviceName]',
    );
    buffer.writeln(
      ' * must set `android:enabled="@bool/$serviceEnabledBoolResource"`.',
    );
    buffer.writeln(
      ' * The attribute is required: without it the exported service stays enabled',
    );
    buffer.writeln(
      ' * below API $appFunctionsMinApiLevel, where another app could bind it and crash this app',
    );
    buffer.writeln(' * on class load.');
    buffer.writeln(' */');
    buffer.writeln('@RequiresApi($appFunctionsMinApiLevel)');
    buffer.writeln('@AppFunctionServiceEntryPoint(');
    buffer.writeln('${_indent}serviceName = "$serviceName",');
    buffer.writeln(
      '${_indent}appFunctionXmlFileName = "$appFunctionXmlFileName",',
    );
    buffer.writeln(')');
    buffer.writeln(
      'abstract class GeneratedAppFunctions : AppFunctionService() {',
    );
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

  /// Generates a single @AppFunctionDeclaration method.
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
    if (info.parameters.isNotEmpty) buffer.writeln('$prefix *');
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

    // @AppFunctionDeclaration annotation (renamed from @AppFunction in alpha13)
    buffer.writeln('$prefix@AppFunctionDeclaration(isDescribedByKDoc = true)');

    // Function signature
    // No AppFunctionContext parameter: it became @RestrictTo(LIBRARY_GROUP) in
    // appfunctions 1.0.0-alpha12, and functions declared inside an
    // @AppFunctionServiceEntryPoint are validated without it.
    final paramStrings = <String>[];
    for (final param in info.parameters) {
      final kotlinType = _kotlinParamType(param);
      if (param.isOptional || param.dartType.endsWith('?')) {
        paramStrings.add('${param.fieldName}: $kotlinType = null');
      } else {
        paramStrings.add('${param.fieldName}: $kotlinType');
      }
    }

    if (paramStrings.isEmpty) {
      buffer.writeln('${prefix}suspend fun $funcName(): String {');
    } else {
      buffer.writeln('${prefix}suspend fun $funcName(');
      for (var i = 0; i < paramStrings.length; i++) {
        final comma = i < paramStrings.length - 1 ? ',' : '';
        buffer.writeln('$prefix$_indent${paramStrings[i]}$comma');
      }
      buffer.writeln('$prefix): String {');
    }

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
    // A long-running intent (`@IntentSpec(longRunning: true)`) is exempt from
    // the bridge's opt-in per-call timeout: it declared that it needs the time.
    final longRunningArg = info.longRunning ? ', longRunning = true' : '';
    buffer.writeln(
      '$prefix${_indent}return bridge.executeIntent("${info.identifier}", params$longRunningArg)',
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
    buffer.writeln(' *');
    buffer.writeln(
      ' * Calls are unbounded unless [initialize] is given a timeout. Either way the',
    );
    buffer.writeln(
      ' * bridge tells Dart when a call is abandoned (timeout or caller cancellation),',
    );
    buffer.writeln(
      ' * so a handler can stop early through `AppIntentExecution.current`.',
    );
    buffer.writeln(' */');
    buffer.writeln('class AppFunctionsBridge private constructor(');
    buffer.writeln('${_indent}private val channel: MethodChannel,');
    buffer.writeln('${_indent}private val executionTimeoutMillis: Long?');
    buffer.writeln(') {');
    buffer.writeln();
    buffer.writeln('${_indent}companion object {');
    buffer.writeln(
      '$_indent${_indent}private var instance: AppFunctionsBridge? = null',
    );
    buffer.writeln();
    buffer.writeln('$_indent$_indent/**');
    buffer.writeln(
      '$_indent$_indent * [executionTimeoutMillis] optionally bounds each call (null, the default,',
    );
    buffer.writeln(
      '$_indent$_indent * means no bound). A handler that has not answered in time fails the call',
    );
    buffer.writeln(
      '$_indent$_indent * and is told to stop, but stopping is cooperative: it may still finish',
    );
    buffer.writeln(
      '$_indent$_indent * and commit its side effect, and the caller may retry. Make bounded',
    );
    buffer.writeln(
      '$_indent$_indent * handlers idempotent. Must be positive when set. Intents declared',
    );
    buffer.writeln('$_indent$_indent * `longRunning` are never bounded.');
    buffer.writeln('$_indent$_indent */');
    buffer.writeln('$_indent${_indent}fun initialize(');
    buffer.writeln('$_indent$_indent${_indent}channel: MethodChannel,');
    buffer.writeln(
      '$_indent$_indent${_indent}executionTimeoutMillis: Long? = null',
    );
    buffer.writeln('$_indent$_indent) {');
    buffer.writeln(
      '$_indent$_indent${_indent}require(executionTimeoutMillis == null || executionTimeoutMillis > 0) {',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent"executionTimeoutMillis must be positive, or null for no bound"',
    );
    buffer.writeln('$_indent$_indent$_indent}');
    buffer.writeln(
      '$_indent$_indent${_indent}instance = AppFunctionsBridge(channel, executionTimeoutMillis)',
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
    buffer.writeln('$_indent/**');
    buffer.writeln(
      '$_indent * Runs the Dart handler for [identifier]. Bounded only when [initialize]',
    );
    buffer.writeln(
      '$_indent * was given a timeout and [longRunning] is not set; the generated code sets',
    );
    buffer.writeln(
      '$_indent * it for intents declared `@IntentSpec(longRunning: true)`.',
    );
    buffer.writeln('$_indent */');
    buffer.writeln('${_indent}suspend fun executeIntent(');
    buffer.writeln('$_indent${_indent}identifier: String,');
    buffer.writeln('$_indent${_indent}params: Map<String, Any?>,');
    buffer.writeln('$_indent${_indent}longRunning: Boolean = false');
    buffer.writeln('$_indent): String = withContext(Dispatchers.Main) {');
    buffer.writeln(
      '$_indent${_indent}val executionId = UUID.randomUUID().toString()',
    );
    buffer.writeln('$_indent${_indent}val timeout = executionTimeoutMillis');
    buffer.writeln('$_indent${_indent}if (longRunning || timeout == null) {');
    buffer.writeln(
      '$_indent$_indent${_indent}awaitDartReply(identifier, params, executionId)',
    );
    buffer.writeln('$_indent$_indent} else {');
    buffer.writeln('$_indent$_indent${_indent}try {');
    buffer.writeln('$_indent$_indent$_indent${_indent}withTimeout(timeout) {');
    buffer.writeln(
      '$_indent$_indent$_indent$_indent${_indent}awaitDartReply(identifier, params, executionId)',
    );
    buffer.writeln('$_indent$_indent$_indent$_indent}');
    buffer.writeln(
      '$_indent$_indent$_indent} catch (e: TimeoutCancellationException) {',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent// Not left as a CancellationException: the AppFunctions dispatcher',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent// would report that as a cancellation by the caller, not a failure.',
    );
    buffer.writeln('$_indent$_indent$_indent${_indent}throw RuntimeException(');
    buffer.writeln(
      '$_indent$_indent$_indent$_indent$_indent"Intent \$identifier timed out after \${timeout}ms", e',
    );
    buffer.writeln('$_indent$_indent$_indent$_indent)');
    buffer.writeln('$_indent$_indent$_indent}');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.writeln();
    buffer.writeln('$_indent/**');
    buffer.writeln(
      '$_indent * One MethodChannel round trip. Opens a Dart execution scope under',
    );
    buffer.writeln(
      '$_indent * [executionId] so the handler is told when the call is abandoned.',
    );
    buffer.writeln('$_indent */');
    buffer.writeln('${_indent}private suspend fun awaitDartReply(');
    buffer.writeln('$_indent${_indent}identifier: String,');
    buffer.writeln('$_indent${_indent}params: Map<String, Any?>,');
    buffer.writeln('$_indent${_indent}executionId: String');
    buffer.writeln('$_indent): String = suspendCancellableCoroutine { cont ->');
    buffer.writeln('$_indent${_indent}cont.invokeOnCancellation { cause ->');
    buffer.writeln(
      '$_indent$_indent${_indent}notifyCancellation(executionId, cause)',
    );
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent${_indent}channel.invokeMethod(');
    buffer.writeln('$_indent$_indent$_indent"executeIntent",');
    buffer.writeln('$_indent$_indent${_indent}mapOf(');
    buffer.writeln(
      '$_indent$_indent$_indent$_indent"identifier" to identifier,',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent"params" to params + ("$_executionIdKey" to executionId)',
    );
    buffer.writeln('$_indent$_indent$_indent),');
    buffer.writeln('$_indent$_indent${_indent}object : MethodChannel.Result {');
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}override fun success(result: Any?) {',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent${_indent}cont.resume(result?.toString() ?: "{}")',
    );
    buffer.writeln('$_indent$_indent$_indent$_indent}');
    buffer.writeln();
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}override fun error(code: String, message: String?, details: Any?) {',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent${_indent}cont.resumeWithException(toAppFunctionException(code, message))',
    );
    buffer.writeln('$_indent$_indent$_indent$_indent}');
    buffer.writeln();
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}override fun notImplemented() {',
    );
    buffer.writeln(
      '$_indent$_indent$_indent$_indent${_indent}cont.resumeWithException($fallbackAppFunctionException("executeIntent is not implemented on the Dart side"))',
    );
    buffer.writeln('$_indent$_indent$_indent$_indent}');
    buffer.writeln('$_indent$_indent$_indent}');
    buffer.writeln('$_indent$_indent)');
    buffer.writeln('$_indent}');
    buffer.writeln();
    buffer.writeln('$_indent/**');
    buffer.writeln(
      '$_indent * Tells Dart the execution was abandoned so the handler can stop early.',
    );
    buffer.writeln(
      '$_indent * Cancellation handlers may run on any thread; the MethodChannel must be',
    );
    buffer.writeln(
      '$_indent * driven from the main one. A late reply from Dart is ignored by the',
    );
    buffer.writeln('$_indent * already-cancelled continuation.');
    buffer.writeln('$_indent */');
    buffer.writeln(
      '${_indent}private fun notifyCancellation(executionId: String, cause: Throwable?) {',
    );
    buffer.writeln(
      '$_indent${_indent}val reason = if (cause is TimeoutCancellationException) "timeout" else "cancelled"',
    );
    buffer.writeln('$_indent${_indent}Handler(Looper.getMainLooper()).post {');
    buffer.writeln('$_indent$_indent${_indent}channel.invokeMethod(');
    buffer.writeln('$_indent$_indent$_indent$_indent"intentCancelled",');
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}mapOf("executionId" to executionId, "reason" to reason)',
    );
    buffer.writeln('$_indent$_indent$_indent)');
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');
    buffer.writeln();
    _generateErrorMapping(buffer);
    buffer.writeln('}');
  }

  /// Generates `toAppFunctionException`, which turns a Dart `AppIntentError`
  /// code into the matching `androidx.appfunctions` exception (see
  /// [appFunctionExceptionByErrorCode]).
  void _generateErrorMapping(StringBuffer buffer) {
    buffer.writeln('$_indent/**');
    buffer.writeln(
      '$_indent * Maps a Dart `AppIntentError` code to the matching AppFunctions exception,',
    );
    buffer.writeln(
      '$_indent * so the caller receives a typed error category instead of a generic failure.',
    );
    buffer.writeln(
      '$_indent * Unknown codes become [$fallbackAppFunctionException] with the code kept in the message.',
    );
    buffer.writeln('$_indent */');
    buffer.writeln('${_indent}private fun toAppFunctionException(');
    buffer.writeln('$_indent${_indent}code: String,');
    buffer.writeln('$_indent${_indent}message: String?');
    buffer.writeln('$_indent): AppFunctionException = when (code) {');
    for (final entry in appFunctionExceptionByErrorCode.entries) {
      buffer.writeln(
        '$_indent$_indent"${entry.key}" -> ${entry.value}(message)',
      );
    }
    buffer.writeln(
      '$_indent${_indent}else -> $fallbackAppFunctionException("\$code: \$message")',
    );
    buffer.writeln('$_indent}');
  }

  /// Formats text for KDoc comments, handling multiline descriptions.
  String _formatKdocLines(String text, String prefix) {
    return text.split('\n').map((line) => '$prefix * $line').join('\n');
  }
}
