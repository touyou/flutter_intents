// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../models/widget_configuration_info.dart';

/// Type checker for the WidgetConfigurationSpec annotation.
const _widgetConfigurationSpecChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/widget_configuration_spec.dart#WidgetConfigurationSpec',
);

/// Type checker for the WidgetParameter annotation.
const _widgetParameterChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/widget_configuration_spec.dart#WidgetParameter',
);

/// Type checker for the EntitySpec annotation, used to recognize a parameter
/// whose declared type is an entity.
const _entitySpecChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_spec.dart#EntitySpec',
);

/// Analyzer for extracting `@WidgetConfigurationSpec` information (#98).
class WidgetConfigurationAnalyzer {
  /// Creates a new [WidgetConfigurationAnalyzer].
  const WidgetConfigurationAnalyzer();

  /// Whether [element] carries a `@WidgetConfigurationSpec` annotation.
  bool hasWidgetConfigurationSpecAnnotation(ClassElement element) {
    return _widgetConfigurationSpecChecker.hasAnnotationOfExact(element);
  }

  /// Analyzes [element] and extracts widget configuration information.
  ///
  /// Returns `null` when the element has no `@WidgetConfigurationSpec`
  /// annotation.
  WidgetConfigurationInfo? analyze(ClassElement element) {
    final annotation = _widgetConfigurationSpecChecker.firstAnnotationOfExact(
      element,
    );
    if (annotation == null) return null;

    final identifier = annotation.getField('identifier')?.toStringValue();
    final title = annotation.getField('title')?.toStringValue();

    if (identifier == null) {
      throw InvalidGenerationSourceError(
        '@WidgetConfigurationSpec requires an "identifier" field.',
        element: element,
      );
    }
    if (title == null) {
      throw InvalidGenerationSourceError(
        '@WidgetConfigurationSpec requires a "title" field.',
        element: element,
      );
    }

    return WidgetConfigurationInfo(
      className: element.name!,
      identifier: identifier,
      title: title,
      description: annotation.getField('description')?.toStringValue(),
      isDiscoverable:
          annotation.getField('isDiscoverable')?.toBoolValue() ?? false,
      generateDefaultResult:
          annotation.getField('generateDefaultResult')?.toBoolValue() ?? false,
      parameters: _extractParameters(element),
    );
  }

  List<WidgetParamInfo> _extractParameters(ClassElement element) {
    final parameters = <WidgetParamInfo>[];

    for (final field in element.fields) {
      final annotation = _widgetParameterChecker.firstAnnotationOfExact(field);
      if (annotation == null) continue;

      final title = annotation.getField('title')?.toStringValue();
      if (title == null) {
        throw InvalidGenerationSourceError(
          '@WidgetParameter requires a "title" field.',
          element: field,
        );
      }

      final dartType = field.type.getDisplayString();

      parameters.add(
        WidgetParamInfo(
          name: field.name!,
          dartType: dartType,
          title: title,
          description: annotation.getField('description')?.toStringValue(),
          // An explicit entityType wins; otherwise infer it from the declared
          // type when that type is itself an @EntitySpec class.
          entityType:
              annotation.getField('entityType')?.toStringValue() ??
              _entityTypeOf(field),
        ),
      );
    }

    return parameters;
  }

  /// The `@EntitySpec` class name of [field]'s declared type, or `null` when
  /// the type is not an entity.
  String? _entityTypeOf(FieldElement field) {
    final typeElement = field.type.element;
    if (typeElement is! ClassElement) return null;
    if (!_entitySpecChecker.hasAnnotationOfExact(typeElement)) return null;
    return typeElement.name;
  }
}
