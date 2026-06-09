// ignore_for_file: deprecated_member_use, unnecessary_non_null_assertion
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../models/entity_info.dart';

/// Type checker for EntitySpec annotation.
const _entitySpecChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_spec.dart#EntitySpec',
);

/// Type checker for EntityId annotation.
const _entityIdChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_params.dart#EntityId',
);

/// Type checker for EntityTitle annotation.
const _entityTitleChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_params.dart#EntityTitle',
);

/// Type checker for EntitySubtitle annotation.
const _entitySubtitleChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_params.dart#EntitySubtitle',
);

/// Type checker for EntityImage annotation.
const _entityImageChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_params.dart#EntityImage',
);

/// Type checker for EntityDefaultQuery annotation.
const _entityDefaultQueryChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_params.dart#EntityDefaultQuery',
);

/// Type checker for EntityProperty annotation.
const _entityPropertyChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_params.dart#EntityProperty',
);

/// Type checker for EntitySpecBase base class.
const _entitySpecBaseChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/bases/entity_spec_base.dart#EntitySpecBase',
);

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
    final displayImageName = annotation
        .getField('displayImageName')
        ?.toStringValue();
    final indexed = annotation.getField('indexed')?.toBoolValue() ?? false;
    final enumerable =
        annotation.getField('enumerable')?.toBoolValue() ?? false;
    final persistedCacheKey = annotation
        .getField('persistedCacheKey')
        ?.toStringValue();
    final schema = annotation.getField('schema')?.toStringValue();
    final ownership = _parseOwnership(annotation.getField('ownership'));
    final valueQuery =
        annotation.getField('valueQuery')?.toBoolValue() ?? false;

    if (identifier == null) {
      throw InvalidGenerationSourceError(
        '@EntitySpec requires an "identifier" field.',
        element: element,
      );
    }
    if (title == null) {
      throw InvalidGenerationSourceError(
        '@EntitySpec requires a "title" field.',
        element: element,
      );
    }
    if (pluralTitle == null) {
      throw InvalidGenerationSourceError(
        '@EntitySpec requires a "pluralTitle" field.',
        element: element,
      );
    }

    final modelType = _extractModelType(element);
    final properties = _extractProperties(element);

    return EntityInfo(
      className: element.name!,
      identifier: identifier,
      title: title,
      pluralTitle: pluralTitle,
      description: description,
      modelType: modelType,
      properties: properties,
      displayImageName: displayImageName,
      indexed: indexed,
      enumerable: enumerable,
      persistedCacheKey: persistedCacheKey,
      schema: schema,
      ownership: ownership,
      valueQuery: valueQuery,
    );
  }

  /// Parses the `ownership` enum value (`EntityOwnershipState`) into the model
  /// type, or `null` when absent.
  EntityOwnershipType? _parseOwnership(DartObject? field) {
    if (field == null || field.isNull) return null;
    final index = field.getField('index')?.toIntValue();
    switch (index) {
      case 0:
        return EntityOwnershipType.unknown;
      case 1:
        return EntityOwnershipType.shared;
      case 2:
        return EntityOwnershipType.public;
      default:
        return null;
    }
  }

  String? _extractModelType(ClassElement element) {
    for (final supertype in element.allSupertypes) {
      if (_entitySpecBaseChecker.isExactlyType(supertype)) {
        final typeArgs = supertype.typeArguments;
        if (typeArgs.isNotEmpty) {
          return typeArgs[0].getDisplayString();
        }
      }
    }
    return null;
  }

  List<EntityPropertyInfo> _extractProperties(ClassElement element) {
    final properties = <EntityPropertyInfo>[];

    for (final field in element.fields) {
      final role = _determinePropertyRole(field);
      final propAnnotation = _entityPropertyChecker.firstAnnotationOfExact(
        field,
      );
      final exposeAsProperty = propAnnotation != null;

      // Include role-annotated fields and @EntityProperty fields; skip the rest.
      if (role == EntityPropertyRole.none && !exposeAsProperty) continue;

      properties.add(
        EntityPropertyInfo(
          fieldName: field.name!,
          dartType: field.type.getDisplayString(),
          role: role,
          exposeAsProperty: exposeAsProperty,
          propertyTitle: propAnnotation?.getField('title')?.toStringValue(),
          indexingKey: propAnnotation?.getField('indexingKey')?.toStringValue(),
        ),
      );
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
