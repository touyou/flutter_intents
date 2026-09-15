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

/// Type checker for EntityStableId annotation (#132).
const _entityStableIdChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_params.dart#EntityStableId',
);

/// Type checker for EntityExportField annotation (#128).
const _entityExportFieldChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/entity_params.dart#EntityExportField',
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
    final exportAs = _parseExportAs(annotation.getField('exportAs'));
    final importable =
        annotation.getField('importable')?.toBoolValue() ?? false;
    final syncable = annotation.getField('syncable')?.toBoolValue() ?? false;
    final relevantEntities =
        annotation.getField('relevantEntities')?.toBoolValue() ?? false;

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
    _validateExport(element, exportAs, properties);
    _validateStableId(element, syncable: syncable, properties: properties);
    if (importable && exportAs == null) {
      throw InvalidGenerationSourceError(
        '@EntitySpec(importable: true) on `${element.name}` has no exportAs. '
        'Import resolves a system value back into the entity, so there has to '
        'be a representation to import from.',
        element: element,
      );
    }

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
      exportAs: exportAs,
      importable: importable,
      syncable: syncable,
      relevantEntities: relevantEntities,
    );
  }

  /// Rejects `@EntityStableId` declarations that cannot mean anything (#132).
  void _validateStableId(
    ClassElement element, {
    required bool syncable,
    required List<EntityPropertyInfo> properties,
  }) {
    final stable = properties.where((p) => p.isStableId).toList();
    if (stable.isEmpty) return;
    if (stable.length > 1) {
      throw InvalidGenerationSourceError(
        'Entity `${element.name}` marks more than one field with '
        '@EntityStableId. An entity has exactly one stable identifier.',
        element: element,
      );
    }
    if (!syncable) {
      throw InvalidGenerationSourceError(
        '@EntityStableId on `${element.name}` has no effect without '
        '@EntitySpec(syncable: true) — the stable half of the identifier is '
        'only used by the SyncableEntity conformance.',
        element: element,
      );
    }
    final field = stable.single;
    if (field.role != EntityPropertyRole.none) {
      throw InvalidGenerationSourceError(
        'Entity `${element.name}` marks `${field.fieldName}` as both '
        '@EntityStableId and a display role. The stable identifier pairs with '
        '@EntityId; it cannot also be the title/subtitle/image.',
        element: element,
      );
    }
    if (field.dartType != 'String') {
      throw InvalidGenerationSourceError(
        'Entity `${element.name}` marks `${field.fieldName}` as '
        '@EntityStableId, which must be a non-nullable String (it becomes the '
        'stable half of SyncableEntityIdentifier<String, String>) but is '
        '`${field.dartType}`.',
        element: element,
      );
    }
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

  /// Parses the `exportAs` enum value (`EntityExportType`) into the model type,
  /// or `null` when absent.
  EntityExportKind? _parseExportAs(DartObject? field) {
    if (field == null || field.isNull) return null;
    final index = field.getField('index')?.toIntValue();
    switch (index) {
      case 0:
        return EntityExportKind.person;
      case 1:
        return EntityExportKind.place;
      default:
        return null;
    }
  }

  /// Parses an `@EntityExportField(role)` annotation into its model role.
  EntityExportRoleKind? _parseExportRole(DartObject? annotation) {
    if (annotation == null) return null;
    final index = annotation.getField('role')?.getField('index')?.toIntValue();
    if (index == null) return null;
    if (index < 0 || index >= EntityExportRoleKind.values.length) return null;
    return EntityExportRoleKind.values[index];
  }

  /// Rejects structured-export declarations that could only fail at runtime as
  /// an export the system silently never offers.
  ///
  /// Each check corresponds to a value the generated `ValueRepresentation`
  /// would have no way to build: a `PlaceDescriptor` with no representation, an
  /// `IntentCurrencyAmount` with no amount or no currency code, or a coordinate
  /// with only one of its two halves.
  void _validateExport(
    ClassElement element,
    EntityExportKind? exportAs,
    List<EntityPropertyInfo> properties,
  ) {
    EntityPropertyInfo? fieldFor(EntityExportRoleKind role) =>
        properties.where((p) => p.exportRole == role).firstOrNull;

    final declaredRoles = properties
        .where((p) => p.exportRole != null)
        .map((p) => p.exportRole!)
        .toSet();

    if (exportAs == null) {
      if (declaredRoles.isEmpty) return;
      throw InvalidGenerationSourceError(
        '@EntityExportField is declared on `${element.name}` but the entity has '
        'no @EntitySpec(exportAs:). The field would never be read. Set '
        'exportAs, or drop the annotation.',
        element: element,
      );
    }

    void requireType(
      EntityPropertyInfo prop,
      List<String> allowed,
      String what,
    ) {
      final bare = prop.dartType.endsWith('?')
          ? prop.dartType.substring(0, prop.dartType.length - 1)
          : prop.dartType;
      if (allowed.contains(bare)) return;
      throw InvalidGenerationSourceError(
        'Entity `${element.name}` marks `${prop.fieldName}` as $what, which '
        'must be ${allowed.join('/')} (or its nullable form) but is '
        '`${prop.dartType}`.',
        element: element,
      );
    }

    switch (exportAs) {
      case EntityExportKind.person:
        break;
      case EntityExportKind.place:
        final lat = fieldFor(EntityExportRoleKind.latitude);
        final lng = fieldFor(EntityExportRoleKind.longitude);
        final address = fieldFor(EntityExportRoleKind.address);
        if ((lat == null) != (lng == null)) {
          throw InvalidGenerationSourceError(
            'Entity `${element.name}` exports as PlaceDescriptor but declares '
            'only ${lat != null ? 'a latitude' : 'a longitude'} export field. '
            'A coordinate representation needs both.',
            element: element,
          );
        }
        if (lat == null && address == null) {
          throw InvalidGenerationSourceError(
            'Entity `${element.name}` exports as PlaceDescriptor but declares '
            'no location fields. Mark a latitude + longitude pair and/or an '
            'address with @EntityExportField.',
            element: element,
          );
        }
        if (lat != null) requireType(lat, ['double', 'int'], 'a latitude');
        if (lng != null) requireType(lng, ['double', 'int'], 'a longitude');
        if (address != null) requireType(address, ['String'], 'an address');
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
      final exportRole = _parseExportRole(
        _entityExportFieldChecker.firstAnnotationOfExact(field),
      );
      final isStableId = _entityStableIdChecker.hasAnnotationOfExact(field);

      // Include role-annotated, @EntityProperty, @EntityExportField and
      // @EntityStableId fields; skip the rest.
      if (role == EntityPropertyRole.none &&
          !exposeAsProperty &&
          exportRole == null &&
          !isStableId) {
        continue;
      }

      properties.add(
        EntityPropertyInfo(
          fieldName: field.name!,
          dartType: field.type.getDisplayString(),
          role: role,
          exposeAsProperty: exposeAsProperty,
          propertyTitle: propAnnotation?.getField('title')?.toStringValue(),
          indexingKey: propAnnotation?.getField('indexingKey')?.toStringValue(),
          exportRole: exportRole,
          isStableId: isStableId,
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
