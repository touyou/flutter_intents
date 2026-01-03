// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';
import 'package:source_gen/source_gen.dart';

import '../models/entity_info.dart';

/// Type checker for EntitySpec annotation.
const _entitySpecChecker = TypeChecker.fromRuntime(EntitySpec);

/// Type checker for EntityId annotation.
const _entityIdChecker = TypeChecker.fromRuntime(EntityId);

/// Type checker for EntityTitle annotation.
const _entityTitleChecker = TypeChecker.fromRuntime(EntityTitle);

/// Type checker for EntitySubtitle annotation.
const _entitySubtitleChecker = TypeChecker.fromRuntime(EntitySubtitle);

/// Type checker for EntityImage annotation.
const _entityImageChecker = TypeChecker.fromRuntime(EntityImage);

/// Type checker for EntityDefaultQuery annotation.
const _entityDefaultQueryChecker = TypeChecker.fromRuntime(EntityDefaultQuery);

/// Type checker for EntitySpecBase base class.
const _entitySpecBaseChecker = TypeChecker.fromRuntime(EntitySpecBase);

/// Analyzer for extracting entity information from annotated classes.
class EntityAnalyzer {
  /// Creates a new [EntityAnalyzer].
  const EntityAnalyzer();

  /// Checks if the given [element] has an @EntitySpec annotation.
  bool hasEntitySpecAnnotation(ClassElement element) {
    return _entitySpecChecker.hasAnnotationOfExact(element);
  }

  /// Analyzes the given [element] and extracts entity information.
  ///
  /// Returns `null` if the element does not have an @EntitySpec annotation.
  EntityInfo? analyze(ClassElement element) {
    final annotation = _entitySpecChecker.firstAnnotationOfExact(element);
    if (annotation == null) {
      return null;
    }

    final identifier = annotation.getField('identifier')?.toStringValue();
    final title = annotation.getField('title')?.toStringValue();
    final pluralTitle = annotation.getField('pluralTitle')?.toStringValue();
    final description = annotation.getField('description')?.toStringValue();

    if (identifier == null || title == null || pluralTitle == null) {
      return null;
    }

    final modelType = _extractModelType(element);
    final properties = _extractProperties(element);

    return EntityInfo(
      className: element.name,
      identifier: identifier,
      title: title,
      pluralTitle: pluralTitle,
      description: description,
      modelType: modelType,
      properties: properties,
    );
  }

  String? _extractModelType(ClassElement element) {
    for (final supertype in element.allSupertypes) {
      if (_entitySpecBaseChecker.isExactlyType(supertype)) {
        final typeArgs = supertype.typeArguments;
        if (typeArgs.isNotEmpty) {
          return _formatType(typeArgs[0]);
        }
      }
    }
    return null;
  }

  String _formatType(DartType type) {
    return type.getDisplayString();
  }

  List<EntityPropertyInfo> _extractProperties(ClassElement element) {
    final properties = <EntityPropertyInfo>[];

    for (final field in element.fields) {
      final role = _determinePropertyRole(field);
      if (role == EntityPropertyRole.none) continue;

      properties.add(EntityPropertyInfo(
        fieldName: field.name,
        dartType: field.type.getDisplayString(),
        role: role,
      ));
    }

    return properties;
  }

  EntityPropertyRole _determinePropertyRole(FieldElement field) {
    if (_entityIdChecker.hasAnnotationOfExact(field)) {
      return EntityPropertyRole.id;
    }
    if (_entityTitleChecker.hasAnnotationOfExact(field)) {
      return EntityPropertyRole.title;
    }
    if (_entitySubtitleChecker.hasAnnotationOfExact(field)) {
      return EntityPropertyRole.subtitle;
    }
    if (_entityImageChecker.hasAnnotationOfExact(field)) {
      return EntityPropertyRole.image;
    }
    if (_entityDefaultQueryChecker.hasAnnotationOfExact(field)) {
      return EntityPropertyRole.defaultQuery;
    }
    return EntityPropertyRole.none;
  }
}
