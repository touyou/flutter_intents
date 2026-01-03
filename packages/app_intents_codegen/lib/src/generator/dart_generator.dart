import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

import '../models/entity_info.dart';
import '../models/intent_info.dart';

/// Generator for Dart code that registers intent and entity handlers.
///
/// This generator produces code that:
/// - Registers intent handlers with AppIntents
/// - Registers entity query handlers
/// - Registers suggested entities handlers (when @EntityDefaultQuery exists)
class DartGenerator {
  /// Creates a new [DartGenerator].
  const DartGenerator();

  /// Generates Dart code for registering intent and entity handlers.
  ///
  /// Returns `null` if there are no dart implementation intents and no entities.
  ///
  /// The [baseName] parameter is used to create unique function names to avoid
  /// conflicts when multiple files generate code. If not provided, generic
  /// names are used.
  String? generate(
    List<IntentInfo> intents,
    List<EntityInfo> entities, {
    String? baseName,
  }) {
    // Filter to only dart implementation intents
    final dartIntents = intents
        .where((i) => i.implementation == IntentImplementationType.dart)
        .toList();

    if (dartIntents.isEmpty && entities.isEmpty) {
      return null;
    }

    // Generate unique function name suffix based on baseName
    final suffix = baseName != null ? _toPascalCase(baseName) : '';
    final initFuncName = baseName != null
        ? 'initialize${suffix}AppIntents'
        : 'initializeAppIntents';
    final intentFuncName = baseName != null
        ? '_register${suffix}IntentHandlers'
        : '_registerIntentHandlers';
    final entityFuncName = baseName != null
        ? '_register${suffix}EntityHandlers'
        : '_registerEntityHandlers';

    final library = Library((b) => b
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND')
      ..body.addAll([
        _buildInitializeFunction(
          initFuncName,
          dartIntents.isNotEmpty ? intentFuncName : null,
          entities.isNotEmpty ? entityFuncName : null,
        ),
        if (dartIntents.isNotEmpty)
          _buildRegisterIntentHandlersFunction(dartIntents, intentFuncName),
        if (entities.isNotEmpty)
          _buildRegisterEntityHandlersFunction(entities, entityFuncName),
      ]));

    final emitter = DartEmitter(useNullSafetySyntax: true);
    final code = library.accept(emitter).toString();

    try {
      return DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      ).format(code);
    } catch (_) {
      // If formatting fails, return unformatted code
      return code;
    }
  }

  /// Builds the initialize function with dynamic name.
  Method _buildInitializeFunction(
    String funcName,
    String? intentFuncName,
    String? entityFuncName,
  ) {
    final statements = <Code>[];

    if (intentFuncName != null) {
      statements.add(Code('$intentFuncName();'));
    }

    if (entityFuncName != null) {
      statements.add(Code('$entityFuncName();'));
    }

    return Method((b) => b
      ..name = funcName
      ..returns = refer('void')
      ..docs.add('/// Initialize all App Intents handlers.')
      ..body = Block.of(statements));
  }

  /// Builds the _registerIntentHandlers() function.
  Method _buildRegisterIntentHandlersFunction(
    List<IntentInfo> intents,
    String funcName,
  ) {
    final statements = <Code>[];

    for (final intent in intents) {
      statements.add(_buildIntentHandlerRegistration(intent));
    }

    return Method((b) => b
      ..name = funcName
      ..returns = refer('void')
      ..body = Block.of(statements));
  }

  /// Builds a single intent handler registration.
  Code _buildIntentHandlerRegistration(IntentInfo intent) {
    final cleanName = _cleanClassName(intent.className);
    final handlerName = '${_toCamelCase(cleanName)}Handler';
    final paramExtractions = StringBuffer();
    final handlerArgs = StringBuffer();

    for (final param in intent.parameters) {
      final extraction = _buildParameterExtraction(param);
      paramExtractions.writeln(extraction);

      if (handlerArgs.isNotEmpty) {
        handlerArgs.write(', ');
      }
      handlerArgs.write('${param.fieldName}: ${param.fieldName}');
    }

    final hasOutput = intent.outputType != null && intent.outputType != 'void';
    final isNullableOutput = intent.outputType?.endsWith('?') ?? false;

    String returnStatement;
    if (!hasOutput) {
      returnStatement = 'return <String, dynamic>{};';
    } else if (isNullableOutput) {
      returnStatement = 'return result?.toJson() ?? <String, dynamic>{};';
    } else {
      returnStatement = 'return result.toJson();';
    }

    final handlerBody = '''
${paramExtractions}final result = await $handlerName(${intent.parameters.isNotEmpty ? handlerArgs.toString() : ''});
$returnStatement
''';

    return Code('''
AppIntents().registerIntentHandler(
  '${intent.identifier}',
  (params) async {
    $handlerBody
  },
);
''');
  }

  /// Builds parameter extraction code for an intent parameter.
  String _buildParameterExtraction(IntentParamInfo param) {
    final isNullable =
        param.dartType.endsWith('?') || param.isOptional;
    final baseType = param.dartType.replaceAll('?', '');

    if (baseType == 'DateTime') {
      if (isNullable) {
        return "final ${param.fieldName}Raw = params['${param.fieldName}'] as String?;\n"
            'final ${param.fieldName} = ${param.fieldName}Raw != null ? DateTime.parse(${param.fieldName}Raw) : null;';
      } else {
        return "final ${param.fieldName} = DateTime.parse(params['${param.fieldName}'] as String);";
      }
    }

    return "final ${param.fieldName} = params['${param.fieldName}'] as ${param.dartType};";
  }

  /// Builds the _registerEntityHandlers() function.
  Method _buildRegisterEntityHandlersFunction(
    List<EntityInfo> entities,
    String funcName,
  ) {
    final statements = <Code>[];

    for (final entity in entities) {
      statements.add(_buildEntityQueryHandlerRegistration(entity));

      // Check if entity has a defaultQuery property
      final hasDefaultQuery = entity.properties
          .any((p) => p.role == EntityPropertyRole.defaultQuery);

      if (hasDefaultQuery) {
        statements.add(_buildSuggestedEntitiesHandlerRegistration(entity));
      }
    }

    return Method((b) => b
      ..name = funcName
      ..returns = refer('void')
      ..body = Block.of(statements));
  }

  /// Builds an entity query handler registration.
  Code _buildEntityQueryHandlerRegistration(EntityInfo entity) {
    final cleanName = _cleanClassName(entity.className);
    final queryHandlerName = '${_toCamelCase(cleanName)}Query';

    return Code('''
AppIntents().registerEntityQueryHandler(
  '${entity.identifier}',
  (identifiers) async {
    final entities = await $queryHandlerName(identifiers);
    return entities.map((e) => e.toJson()).toList();
  },
);
''');
  }

  /// Builds a suggested entities handler registration.
  Code _buildSuggestedEntitiesHandlerRegistration(EntityInfo entity) {
    final cleanName = _cleanClassName(entity.className);
    final suggestedHandlerName =
        '${_toCamelCase(cleanName)}SuggestedEntities';

    return Code('''
AppIntents().registerSuggestedEntitiesHandler(
  '${entity.identifier}',
  () async {
    final entities = await $suggestedHandlerName();
    return entities.map((e) => e.toJson()).toList();
  },
);
''');
  }

  /// Converts a PascalCase string to camelCase.
  String _toCamelCase(String pascalCase) {
    if (pascalCase.isEmpty) return pascalCase;
    return pascalCase[0].toLowerCase() + pascalCase.substring(1);
  }

  /// Converts a camelCase or snake_case string to PascalCase.
  String _toPascalCase(String name) {
    if (name.isEmpty) return name;
    // Handle snake_case
    if (name.contains('_')) {
      return name
          .split('_')
          .map((part) =>
              part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1))
          .join();
    }
    // Handle camelCase - just capitalize first letter
    return name[0].toUpperCase() + name.substring(1);
  }

  /// Removes common suffixes from class names for cleaner handler names.
  String _cleanClassName(String className) {
    final suffixes = ['Spec', 'Intent', 'Entity'];
    var result = className;
    for (final suffix in suffixes) {
      if (result.endsWith(suffix) && result.length > suffix.length) {
        result = result.substring(0, result.length - suffix.length);
      }
    }
    // Re-add Intent/Entity for clarity
    if (className.contains('Intent')) {
      result = '${result}Intent';
    } else if (className.contains('Entity')) {
      result = '${result}Entity';
    }
    return result;
  }
}
