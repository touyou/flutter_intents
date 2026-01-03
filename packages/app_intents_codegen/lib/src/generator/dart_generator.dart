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
  String? generate(List<IntentInfo> intents, List<EntityInfo> entities) {
    // Filter to only dart implementation intents
    final dartIntents = intents
        .where((i) => i.implementation == IntentImplementationType.dart)
        .toList();

    if (dartIntents.isEmpty && entities.isEmpty) {
      return null;
    }

    final library = Library((b) => b
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND')
      ..directives.add(Directive.import('package:app_intents/app_intents.dart'))
      ..body.addAll([
        _buildInitializeAppIntentsFunction(dartIntents, entities),
        if (dartIntents.isNotEmpty)
          _buildRegisterIntentHandlersFunction(dartIntents),
        if (entities.isNotEmpty) _buildRegisterEntityHandlersFunction(entities),
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

  /// Builds the initializeAppIntents() function.
  Method _buildInitializeAppIntentsFunction(
    List<IntentInfo> intents,
    List<EntityInfo> entities,
  ) {
    final statements = <Code>[];

    if (intents.isNotEmpty) {
      statements.add(const Code('_registerIntentHandlers();'));
    }

    if (entities.isNotEmpty) {
      statements.add(const Code('_registerEntityHandlers();'));
    }

    return Method((b) => b
      ..name = 'initializeAppIntents'
      ..returns = refer('void')
      ..docs.add('/// Initialize all App Intents handlers.')
      ..body = Block.of(statements));
  }

  /// Builds the _registerIntentHandlers() function.
  Method _buildRegisterIntentHandlersFunction(List<IntentInfo> intents) {
    final statements = <Code>[];

    for (final intent in intents) {
      statements.add(_buildIntentHandlerRegistration(intent));
    }

    return Method((b) => b
      ..name = '_registerIntentHandlers'
      ..returns = refer('void')
      ..body = Block.of(statements));
  }

  /// Builds a single intent handler registration.
  Code _buildIntentHandlerRegistration(IntentInfo intent) {
    final handlerName = '${_toCamelCase(intent.className)}Handler';
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

    final handlerBody = '''
${paramExtractions}final result = await $handlerName(${intent.parameters.isNotEmpty ? handlerArgs.toString() : ''});
return ${hasOutput ? 'result.toMap()' : '<String, dynamic>{}'};
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
  Method _buildRegisterEntityHandlersFunction(List<EntityInfo> entities) {
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
      ..name = '_registerEntityHandlers'
      ..returns = refer('void')
      ..body = Block.of(statements));
  }

  /// Builds an entity query handler registration.
  Code _buildEntityQueryHandlerRegistration(EntityInfo entity) {
    final queryHandlerName = '${_toCamelCase(entity.className)}Query';

    return Code('''
AppIntents().registerEntityQueryHandler(
  '${entity.identifier}',
  (identifiers) async {
    final entities = await $queryHandlerName(identifiers);
    return entities.map((e) => e.toMap()).toList();
  },
);
''');
  }

  /// Builds a suggested entities handler registration.
  Code _buildSuggestedEntitiesHandlerRegistration(EntityInfo entity) {
    final suggestedHandlerName =
        '${_toCamelCase(entity.className)}SuggestedEntities';

    return Code('''
AppIntents().registerSuggestedEntitiesHandler(
  '${entity.identifier}',
  () async {
    final entities = await $suggestedHandlerName();
    return entities.map((e) => e.toMap()).toList();
  },
);
''');
  }

  /// Converts a PascalCase string to camelCase.
  String _toCamelCase(String pascalCase) {
    if (pascalCase.isEmpty) return pascalCase;
    return pascalCase[0].toLowerCase() + pascalCase.substring(1);
  }
}
