// ignore_for_file: deprecated_member_use, unnecessary_non_null_assertion
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../models/intent_info.dart';
import '../models/union_info.dart';
import 'union_analyzer.dart';

/// Type checker for IntentSpec annotation.
const _intentSpecChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/intent_spec.dart#IntentSpec',
);

/// Type checker for IntentParam annotation.
const _intentParamChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/intent_param.dart#IntentParam',
);

/// Analyzer for extracting intent information from annotated classes.
class IntentAnalyzer {
  /// Creates a new [IntentAnalyzer].
  const IntentAnalyzer();

  /// Checks if the given [element] has an @IntentSpec annotation.
  bool hasIntentSpecAnnotation(ClassElement element) {
    return _intentSpecChecker.hasAnnotationOfExact(element);
  }

  /// Analyzes the given [element] and extracts intent information.
  ///
  /// Returns `null` if the element does not have an @IntentSpec annotation.
  IntentInfo? analyze(ClassElement element) {
    final annotation = _intentSpecChecker.firstAnnotationOfExact(element);
    if (annotation == null) {
      return null;
    }

    final identifier = annotation.getField('identifier')?.toStringValue();
    final title = annotation.getField('title')?.toStringValue();
    final description = annotation.getField('description')?.toStringValue();
    final implementationField = annotation.getField('implementation');
    final implementation = _parseImplementation(implementationField);
    final urlScheme = annotation.getField('urlScheme')?.toStringValue();
    final urlAction = annotation.getField('urlAction')?.toStringValue();
    final resultDialogTemplate = annotation
        .getField('resultDialogTemplate')
        ?.toStringValue();
    final parameterSummary = annotation
        .getField('parameterSummary')
        ?.toStringValue();
    final supportedModes = _parseSupportedModes(
      annotation.getField('supportedModes'),
    );
    final longRunning =
        annotation.getField('longRunning')?.toBoolValue() ?? false;
    final cancellable =
        annotation.getField('cancellable')?.toBoolValue() ?? false;
    final executionTargets = _parseExecutionTargets(
      annotation.getField('executionTargets'),
    );
    final schema = annotation.getField('schema')?.toStringValue();
    final donatable = annotation.getField('donatable')?.toBoolValue() ?? false;

    if (identifier == null) {
      throw InvalidGenerationSourceError(
        '@IntentSpec requires an "identifier" field.',
        element: element,
      );
    }
    if (title == null) {
      throw InvalidGenerationSourceError(
        '@IntentSpec requires a "title" field.',
        element: element,
      );
    }

    // Long-running / cancellable intents are inherently background work; they
    // cannot also open the app via URL scheme or foreground mode.
    if ((longRunning || cancellable) &&
        (urlScheme != null || supportedModes == IntentModeType.foreground)) {
      throw InvalidGenerationSourceError(
        '@IntentSpec "longRunning"/"cancellable" require background execution '
        'and cannot be combined with "urlScheme" or '
        'supportedModes: IntentMode.foreground.',
        element: element,
      );
    }

    final parameters = _extractParameters(element);

    if (donatable) {
      _validateDonatableParameters(element, parameters);
    }

    return IntentInfo(
      className: element.name!,
      identifier: identifier,
      title: title,
      description: description,
      implementation: implementation,
      parameters: parameters,
      urlScheme: urlScheme,
      urlAction: urlAction,
      resultDialogTemplate: resultDialogTemplate,
      parameterSummary: parameterSummary,
      supportedModes: supportedModes,
      longRunning: longRunning,
      cancellable: cancellable,
      executionTargets: executionTargets,
      schema: schema,
      donatable: donatable,
    );
  }

  /// MVP: `@IntentSpec(donatable: true)` requires all parameters to be
  /// primitive types. Reconstructing an intent from a `[String: Any]` dict in
  /// the generated reverse executor is only tractable for primitives today;
  /// richer types (entities, files, enums, unions, collections) need follow-up
  /// codegen.
  void _validateDonatableParameters(
    ClassElement element,
    List<IntentParamInfo> parameters,
  ) {
    for (final param in parameters) {
      final blocker = <String>[];
      if (param.entityType != null) blocker.add('entityType');
      if (param.enumType != null) blocker.add('enumType');
      if (param.fileType != null) blocker.add('fileType (IntentFile)');
      if (param.entityCollectionType != null) {
        blocker.add('entityCollectionType');
      }
      if (param.unionInfo != null) blocker.add('@UnionValue sealed type');
      if (blocker.isEmpty && !_isDonatablePrimitive(param.dartType)) {
        blocker.add('non-primitive type "${param.dartType}"');
      }
      if (blocker.isNotEmpty) {
        throw InvalidGenerationSourceError(
          '@IntentSpec(donatable: true) currently only supports primitive '
          'parameters (String/int/double/bool/DateTime, optionals allowed). '
          'Parameter "${param.fieldName}" is incompatible: '
          '${blocker.join(', ')}. Remove the param or drop donatable: true '
          'until richer reconstruction lands.',
          element: element,
        );
      }
    }
  }

  static const _donatablePrimitiveBases = {
    'String',
    'int',
    'double',
    'bool',
    'DateTime',
  };

  bool _isDonatablePrimitive(String dartType) {
    final base = dartType.endsWith('?')
        ? dartType.substring(0, dartType.length - 1)
        : dartType;
    return _donatablePrimitiveBases.contains(base);
  }

  /// Parses the `executionTargets` list of `IntentExecutionTarget` enum values.
  ///
  /// Returns `null` when the field is absent/null, preserving the "not
  /// specified" distinction from an explicitly empty list.
  List<IntentExecutionTargetType>? _parseExecutionTargets(DartObject? field) {
    if (field == null || field.isNull) {
      return null;
    }
    final values = field.toListValue();
    if (values == null) {
      return null;
    }
    final result = <IntentExecutionTargetType>[];
    for (final element in values) {
      final index = element.getField('index')?.toIntValue();
      switch (index) {
        case 0:
          result.add(IntentExecutionTargetType.main);
        case 1:
          result.add(IntentExecutionTargetType.appIntentsExtension);
        case 2:
          result.add(IntentExecutionTargetType.widgetKitExtension);
      }
    }
    return result;
  }

  IntentModeType? _parseSupportedModes(DartObject? field) {
    if (field == null || field.isNull) {
      return null;
    }

    final enumValue = field.getField('index')?.toIntValue();
    if (enumValue == null) {
      return null;
    }

    switch (enumValue) {
      case 0:
        return IntentModeType.background;
      case 1:
        return IntentModeType.foreground;
      default:
        return null;
    }
  }

  IntentImplementationType _parseImplementation(DartObject? field) {
    if (field == null || field.isNull) {
      return IntentImplementationType.dart;
    }

    final enumValue = field.getField('index')?.toIntValue();
    if (enumValue == null) {
      return IntentImplementationType.dart;
    }

    switch (enumValue) {
      case 1:
        return IntentImplementationType.swift;
      case 2:
        return IntentImplementationType.kotlin;
      default:
        return IntentImplementationType.dart;
    }
  }

  List<IntentParamInfo> _extractParameters(ClassElement element) {
    final parameters = <IntentParamInfo>[];

    for (final field in element.fields) {
      final annotation = _intentParamChecker.firstAnnotationOfExact(field);
      if (annotation == null) continue;

      final title = annotation.getField('title')?.toStringValue();
      if (title == null) continue;

      final description = annotation.getField('description')?.toStringValue();
      final isOptional =
          annotation.getField('isOptional')?.toBoolValue() ?? false;
      final entityType = annotation.getField('entityType')?.toStringValue();
      final enumType = annotation.getField('enumType')?.toStringValue();
      final fileType = annotation.getField('fileType')?.toStringValue();
      final entityCollectionType = annotation
          .getField('entityCollectionType')
          ?.toStringValue();
      final unionInfo = _resolveUnion(field);
      final useValueState =
          annotation.getField('useValueState')?.toBoolValue() ?? false;
      final dartType = field.type.getDisplayString();

      if (useValueState && !dartType.endsWith('?')) {
        throw InvalidGenerationSourceError(
          '@IntentParam(useValueState: true) requires an optional parameter '
          '(nullable Dart type). Field "${field.name}" of type "$dartType" '
          'is non-nullable, so "unset" vs "set" cannot be distinguished. '
          'Make the field optional (e.g. "$dartType?") or drop useValueState.',
          element: field,
        );
      }

      parameters.add(
        IntentParamInfo(
          fieldName: field.name!,
          dartType: dartType,
          title: title,
          description: description,
          isOptional: isOptional,
          entityType: entityType,
          enumType: enumType,
          fileType: fileType,
          entityCollectionType: entityCollectionType,
          unionInfo: unionInfo,
          useValueState: useValueState,
        ),
      );
    }

    return parameters;
  }

  /// Resolves the union (#53) when [field]'s type is a `@UnionValueSpec`
  /// sealed class; returns `null` otherwise.
  UnionInfo? _resolveUnion(FieldElement field) {
    final typeElement = field.type.element;
    if (typeElement is! ClassElement) return null;
    const unionAnalyzer = UnionAnalyzer();
    if (!unionAnalyzer.hasUnionValueSpecAnnotation(typeElement)) return null;
    return unionAnalyzer.analyze(typeElement);
  }
}
