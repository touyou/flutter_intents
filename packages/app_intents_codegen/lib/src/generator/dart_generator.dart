import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

import '../models/entity_info.dart';
import '../models/intent_info.dart';
import '../models/union_info.dart';

/// Generator for Dart code that registers intent and entity handlers.
///
/// This generator produces code that:
/// - Generates type-safe Params classes for intents with parameters
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
    List<UnionInfo> unions = const [],
  }) {
    // Filter to only dart implementation intents
    final dartIntents = intents
        .where((i) => i.implementation == IntentImplementationType.dart)
        .toList();

    if (dartIntents.isEmpty && entities.isEmpty && unions.isEmpty) {
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

    final bodyElements = <Spec>[];

    // Generate `<Union>FromMap` factories (#53) for any union spec in this file.
    for (final union in unions) {
      bodyElements.add(_buildUnionFactory(union));
    }

    // Generate Params classes for intents with parameters
    for (final intent in dartIntents) {
      final paramsClass = _buildParamsClass(intent);
      if (paramsClass != null) {
        bodyElements.add(paramsClass);
      }
    }

    // Generate functions (skip the initialize/register machinery for a
    // union-only file — it would be empty).
    if (dartIntents.isNotEmpty || entities.isNotEmpty) {
      bodyElements.add(
        _buildInitializeFunction(
          initFuncName,
          dartIntents.isNotEmpty ? intentFuncName : null,
          entities.isNotEmpty ? entityFuncName : null,
        ),
      );
    }

    if (dartIntents.isNotEmpty) {
      bodyElements.add(
        _buildRegisterIntentHandlersFunction(dartIntents, intentFuncName),
      );
    }

    if (entities.isNotEmpty) {
      bodyElements.add(
        _buildRegisterEntityHandlersFunction(entities, entityFuncName),
      );
    }

    final library = Library(
      (b) => b
        ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND')
        ..body.addAll(bodyElements),
    );

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

  /// The Dart factory function name for [union] (e.g. `galleryContentFromMap`).
  static String unionFactoryName(UnionInfo union) =>
      '${_lowerFirst(union.className)}FromMap';

  static String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  /// Builds a `<Union>FromMap` factory that maps a tagged
  /// `{"_type": ..., "id": ...}` map to the matching `@UnionCase` subclass.
  ///
  /// Each case subclass is assumed to take a single positional `String id`.
  Method _buildUnionFactory(UnionInfo union) {
    final body = StringBuffer();
    body.writeln("switch (map['_type'] as String) {");
    for (final c in union.cases) {
      body.writeln("  case '${c.dartClassName}':");
      body.writeln("    return ${c.dartClassName}(map['id'] as String);");
    }
    body.writeln('  default:');
    body.writeln(
      "    throw ArgumentError('Unknown ${union.className} _type: "
      "\${map['_type']}');",
    );
    body.writeln('}');

    return Method(
      (b) => b
        ..name = unionFactoryName(union)
        ..returns = refer(union.className)
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'map'
              ..type = refer('Map<String, dynamic>'),
          ),
        )
        ..body = Code(body.toString()),
    );
  }

  /// Builds a type-safe Params class for the given intent.
  ///
  /// Returns `null` if the intent has no parameters.
  Code? _buildParamsClass(IntentInfo intent) {
    if (intent.parameters.isEmpty) return null;

    final cleanName = _cleanClassName(intent.className);
    final paramsClassName = '${cleanName}Params';

    final fields = StringBuffer();
    final constructorParams = StringBuffer();
    final fromMapParams = StringBuffer();
    final fromQueryParams = StringBuffer();

    var hasRequiredFileParam = false;

    for (final param in intent.parameters) {
      final isNullable = _isNullableParam(param);

      // Fields
      fields.writeln('  final ${param.dartType} ${param.fieldName};');

      // Constructor params
      if (isNullable) {
        constructorParams.writeln('    this.${param.fieldName},');
      } else {
        constructorParams.writeln('    required this.${param.fieldName},');
      }

      // fromMap extraction
      fromMapParams.writeln(
        '      ${param.fieldName}: ${_buildFromMapExtraction(param)},',
      );

      // Check for required IntentFile params
      if (param.fileType != null && !isNullable) {
        hasRequiredFileParam = true;
      }

      // fromQueryParameters extraction
      fromQueryParams.writeln(
        '      ${param.fieldName}: ${_buildFromQueryExtraction(param)},',
      );
    }

    final fromQueryMethod = hasRequiredFileParam
        ? ''
        : '''

  factory $paramsClassName.fromQueryParameters(Map<String, String> params) {
    return $paramsClassName(
$fromQueryParams    );
  }''';

    return Code('''
class $paramsClassName {
$fields
  const $paramsClassName({
$constructorParams  });

  factory $paramsClassName.fromMap(Map<String, dynamic> map) {
    return $paramsClassName(
$fromMapParams    );
  }$fromQueryMethod
}
''');
  }

  /// Builds extraction code for fromMap factory.
  String _buildFromMapExtraction(IntentParamInfo param) {
    final isNullable = _isNullableParam(param);
    final baseType = param.dartType.replaceAll('?', '');

    if (baseType == 'DateTime') {
      if (isNullable) {
        return "map['${param.fieldName}'] != null ? DateTime.parse(map['${param.fieldName}'] as String) : null";
      } else {
        return "DateTime.parse(map['${param.fieldName}'] as String)";
      }
    }

    if (param.fileType != null) {
      // MethodChannel returns Map<Object?, Object?>, not Map<String, dynamic>.
      // Use Map.from() for safe conversion.
      if (isNullable) {
        return "map['${param.fieldName}'] != null ? IntentFile.fromMap(Map<String, dynamic>.from(map['${param.fieldName}'] as Map)) : null";
      } else {
        return "IntentFile.fromMap(Map<String, dynamic>.from(map['${param.fieldName}'] as Map))";
      }
    }

    // Duration is serialized on the Swift side as an Int of microseconds (the
    // native `Duration` and the `Measurement<UnitDuration>` fallback both reduce
    // to the same value), so the Dart side is branch-agnostic.
    if (baseType == 'Duration') {
      if (isNullable) {
        return "map['${param.fieldName}'] != null ? Duration(microseconds: map['${param.fieldName}'] as int) : null";
      } else {
        return "Duration(microseconds: map['${param.fieldName}'] as int)";
      }
    }

    // PersonName arrives as a Map of name components (native PersonNameComponents
    // or the String fallback both reduce to this shape).
    if (baseType == 'PersonName') {
      if (isNullable) {
        return "map['${param.fieldName}'] != null ? PersonName.fromMap(Map<String, dynamic>.from(map['${param.fieldName}'] as Map)) : null";
      } else {
        return "PersonName.fromMap(Map<String, dynamic>.from(map['${param.fieldName}'] as Map))";
      }
    }

    // Entity-collection parameters arrive as a List of identifier strings
    // (EntityCollection.identifiers / [Entity].map { $0.id }).
    if (param.entityCollectionType != null) {
      if (isNullable) {
        return "map['${param.fieldName}'] != null ? (map['${param.fieldName}'] as List).cast<String>() : null";
      } else {
        return "(map['${param.fieldName}'] as List).cast<String>()";
      }
    }

    // Union parameters arrive as a tagged map; the generated factory picks the
    // case subclass.
    if (param.unionInfo != null) {
      final factory = unionFactoryName(param.unionInfo!);
      if (isNullable) {
        return "map['${param.fieldName}'] != null ? $factory(Map<String, dynamic>.from(map['${param.fieldName}'] as Map)) : null";
      } else {
        return "$factory(Map<String, dynamic>.from(map['${param.fieldName}'] as Map))";
      }
    }

    if (baseType == 'double') {
      if (isNullable) {
        return "(map['${param.fieldName}'] as num?)?.toDouble()";
      } else {
        return "(map['${param.fieldName}'] as num).toDouble()";
      }
    }

    return "map['${param.fieldName}'] as ${param.dartType}";
  }

  /// Builds extraction code for fromQueryParameters factory.
  String _buildFromQueryExtraction(IntentParamInfo param) {
    final isNullable = _isNullableParam(param);
    final baseType = param.dartType.replaceAll('?', '');

    // IntentFile can't be sent through URL scheme
    if (param.fileType != null) {
      return 'null';
    }

    if (baseType == 'DateTime') {
      if (isNullable) {
        return "params['${param.fieldName}'] != null ? DateTime.tryParse(params['${param.fieldName}']!) : null";
      } else {
        return "DateTime.parse(params['${param.fieldName}']!)";
      }
    }

    if (baseType == 'Duration') {
      if (isNullable) {
        return "params['${param.fieldName}'] != null ? Duration(microseconds: int.parse(params['${param.fieldName}']!)) : null";
      } else {
        return "Duration(microseconds: int.parse(params['${param.fieldName}']!))";
      }
    }

    // URL scheme carries only the given name (see SwiftGenerator); rebuild a
    // best-effort PersonName from it.
    if (baseType == 'PersonName') {
      if (isNullable) {
        return "params['${param.fieldName}'] != null ? PersonName(givenName: params['${param.fieldName}']) : null";
      } else {
        return "PersonName(givenName: params['${param.fieldName}']!)";
      }
    }

    // Entity-collection parameters arrive comma-joined in URL scheme.
    if (param.entityCollectionType != null) {
      if (isNullable) {
        return "params['${param.fieldName}'] != null ? params['${param.fieldName}']!.split(',') : null";
      } else {
        return "params['${param.fieldName}']!.split(',')";
      }
    }

    // Union parameters arrive as `<_type>|<id>` in URL scheme.
    if (param.unionInfo != null) {
      final factory = unionFactoryName(param.unionInfo!);
      final build =
          "$factory({'_type': params['${param.fieldName}']!.split('|').first, "
          "'id': params['${param.fieldName}']!.split('|').last})";
      if (isNullable) {
        return "params['${param.fieldName}'] != null ? $build : null";
      } else {
        return build;
      }
    }

    if (baseType == 'int') {
      if (isNullable) {
        return "params['${param.fieldName}'] != null ? int.tryParse(params['${param.fieldName}']!) : null";
      } else {
        return "int.parse(params['${param.fieldName}']!)";
      }
    }

    if (baseType == 'double') {
      if (isNullable) {
        return "params['${param.fieldName}'] != null ? double.tryParse(params['${param.fieldName}']!) : null";
      } else {
        return "double.parse(params['${param.fieldName}']!)";
      }
    }

    if (baseType == 'bool') {
      if (isNullable) {
        return "params['${param.fieldName}'] != null ? params['${param.fieldName}'] == 'true' : null";
      } else {
        return "params['${param.fieldName}'] == 'true'";
      }
    }

    // String (default)
    if (isNullable) {
      return "params['${param.fieldName}']";
    } else {
      return "params['${param.fieldName}']!";
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

    return Method(
      (b) => b
        ..name = funcName
        ..returns = refer('void')
        ..docs.add('/// Initialize all App Intents handlers.')
        ..body = Block.of(statements),
    );
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

    return Method(
      (b) => b
        ..name = funcName
        ..returns = refer('void')
        ..body = Block.of(statements),
    );
  }

  /// Builds a single intent handler registration.
  Code _buildIntentHandlerRegistration(IntentInfo intent) {
    final cleanName = _cleanClassName(intent.className);
    final handlerName = '${_toCamelCase(cleanName)}Handler';

    if (intent.parameters.isEmpty) {
      return Code('''
AppIntents().registerIntentHandler(
  '${intent.identifier}',
  (params) async {
    await $handlerName();
    return <String, dynamic>{};
  },
);
''');
    }

    final paramsClassName = '${cleanName}Params';
    final handlerArgs = intent.parameters
        .map((p) => '${p.fieldName}: p.${p.fieldName}')
        .join(', ');

    return Code('''
AppIntents().registerIntentHandler(
  '${intent.identifier}',
  (params) async {
    final p = $paramsClassName.fromMap(params);
    await $handlerName($handlerArgs);
    return <String, dynamic>{};
  },
);
''');
  }

  /// Builds the _registerEntityHandlers() function.
  Method _buildRegisterEntityHandlersFunction(
    List<EntityInfo> entities,
    String funcName,
  ) {
    final statements = <Code>[];

    for (final entity in entities) {
      statements.add(_buildEntityQueryHandlerRegistration(entity));
      statements.add(_buildSuggestedEntitiesHandlerRegistration(entity));
    }

    return Method(
      (b) => b
        ..name = funcName
        ..returns = refer('void')
        ..body = Block.of(statements),
    );
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
    final suggestedHandlerName = '${_toCamelCase(cleanName)}SuggestedEntities';

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

  /// Whether a parameter should be treated as nullable.
  bool _isNullableParam(IntentParamInfo param) =>
      param.dartType.endsWith('?') || param.isOptional;

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
          .map(
            (part) =>
                part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1),
          )
          .join();
    }
    // Handle camelCase - just capitalize first letter
    return name[0].toUpperCase() + name.substring(1);
  }

  /// Removes the `Spec` suffix from class names for cleaner handler names.
  ///
  /// e.g., `CreateTaskIntentSpec` → `CreateTaskIntent`,
  ///       `TaskEntitySpec` → `TaskEntity`.
  String _cleanClassName(String className) {
    if (className.endsWith('Spec') && className.length > 'Spec'.length) {
      return className.substring(0, className.length - 'Spec'.length);
    }
    return className;
  }
}
