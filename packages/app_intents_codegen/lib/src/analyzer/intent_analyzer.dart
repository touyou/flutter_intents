// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';
import 'package:source_gen/source_gen.dart';

import '../models/intent_info.dart';

/// Type checker for IntentSpec annotation.
const _intentSpecChecker = TypeChecker.fromRuntime(IntentSpec);

/// Type checker for IntentParam annotation.
const _intentParamChecker = TypeChecker.fromRuntime(IntentParam);

/// Type checker for IntentSpecBase base class.
const _intentSpecBaseChecker = TypeChecker.fromRuntime(IntentSpecBase);

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

    if (identifier == null || title == null) {
      return null;
    }

    final typeArgs = _extractTypeArguments(element);
    final parameters = _extractParameters(element);

    return IntentInfo(
      className: element.name,
      identifier: identifier,
      title: title,
      description: description,
      implementation: implementation,
      parameters: parameters,
      inputType: typeArgs.$1,
      outputType: typeArgs.$2,
    );
  }

  IntentImplementationType _parseImplementation(DartObject? field) {
    if (field == null || field.isNull) {
      return IntentImplementationType.dart;
    }

    final enumValue = field.getField('index')?.toIntValue();
    if (enumValue == null) {
      return IntentImplementationType.dart;
    }

    return enumValue == 1
        ? IntentImplementationType.swift
        : IntentImplementationType.dart;
  }

  (String?, String?) _extractTypeArguments(ClassElement element) {
    for (final supertype in element.allSupertypes) {
      if (_intentSpecBaseChecker.isExactlyType(supertype)) {
        final typeArgs = supertype.typeArguments;
        if (typeArgs.length == 2) {
          return (
            _formatType(typeArgs[0]),
            _formatType(typeArgs[1]),
          );
        }
      }
    }
    return (null, null);
  }

  String _formatType(DartType type) {
    return type.getDisplayString();
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

      parameters.add(IntentParamInfo(
        fieldName: field.name,
        dartType: field.type.getDisplayString(),
        title: title,
        description: description,
        isOptional: isOptional,
      ));
    }

    return parameters;
  }
}
