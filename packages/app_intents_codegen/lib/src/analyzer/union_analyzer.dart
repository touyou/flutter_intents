// ignore_for_file: deprecated_member_use, unnecessary_non_null_assertion
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../models/union_info.dart';

/// Type checker for the UnionValueSpec annotation.
const _unionValueSpecChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/union_value.dart#UnionValueSpec',
);

/// Type checker for the UnionCase annotation.
const _unionCaseChecker = TypeChecker.fromUrl(
  'package:app_intents_annotations/src/annotations/union_value.dart#UnionCase',
);

/// Analyzer for extracting union-value information (#53) from an annotated
/// `sealed` class and its `@UnionCase` subclasses.
class UnionAnalyzer {
  /// Creates a new [UnionAnalyzer].
  const UnionAnalyzer();

  /// Whether [element] has a `@UnionValueSpec` annotation.
  bool hasUnionValueSpecAnnotation(ClassElement element) =>
      _unionValueSpecChecker.hasAnnotationOfExact(element);

  /// Analyzes the `@UnionValueSpec` [element] (the sealed base class).
  ///
  /// Returns `null` if the element is not annotated. Throws if required fields
  /// are missing or no `@UnionCase` subclasses are found.
  UnionInfo? analyze(ClassElement element) {
    final annotation = _unionValueSpecChecker.firstAnnotationOfExact(element);
    if (annotation == null) return null;

    final identifier = annotation.getField('identifier')?.toStringValue();
    final title = annotation.getField('title')?.toStringValue();

    if (identifier == null) {
      throw InvalidGenerationSourceError(
        '@UnionValueSpec requires an "identifier" field.',
        element: element,
      );
    }

    final cases = _extractCases(element);
    if (cases.isEmpty) {
      throw InvalidGenerationSourceError(
        '@UnionValueSpec "${element.name}" has no @UnionCase subclasses '
        'in the same library.',
        element: element,
      );
    }

    return UnionInfo(
      className: element.name!,
      identifier: identifier,
      title: title,
      cases: cases,
    );
  }

  List<UnionCaseInfo> _extractCases(ClassElement union) {
    final cases = <UnionCaseInfo>[];
    for (final cls in union.library.classes) {
      if (cls == union) continue;
      // Only direct subclasses of the union base.
      if (cls.supertype?.element != union) continue;

      final caseAnnotation = _unionCaseChecker.firstAnnotationOfExact(cls);
      if (caseAnnotation == null) continue;

      final entityType = caseAnnotation.getField('entityType')?.toStringValue();
      if (entityType == null) {
        throw InvalidGenerationSourceError(
          '@UnionCase requires an "entityType" field.',
          element: cls,
        );
      }

      cases.add(
        UnionCaseInfo(dartClassName: cls.name!, entityType: entityType),
      );
    }
    return cases;
  }
}
