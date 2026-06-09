// ignore_for_file: deprecated_member_use, unnecessary_non_null_assertion
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../models/intent_info.dart';

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
    );
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

      parameters.add(
        IntentParamInfo(
          fieldName: field.name!,
          dartType: field.type.getDisplayString(),
          title: title,
          description: description,
          isOptional: isOptional,
          entityType: entityType,
          enumType: enumType,
          fileType: fileType,
          entityCollectionType: entityCollectionType,
        ),
      );
    }

    return parameters;
  }
}
