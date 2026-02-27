// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';
import 'package:source_gen/source_gen.dart';

import '../models/enum_info.dart';

/// Type checker for EnumSpec annotation.
const _enumSpecChecker = TypeChecker.fromRuntime(EnumSpec);

/// Type checker for EnumCaseDisplay annotation.
const _enumCaseDisplayChecker = TypeChecker.fromRuntime(EnumCaseDisplay);

/// Analyzer for extracting enum information from annotated enums.
class EnumAnalyzer {
  /// Creates a new [EnumAnalyzer].
  const EnumAnalyzer();

  /// Checks if the given [element] has an @EnumSpec annotation.
  bool hasEnumSpecAnnotation(EnumElement element) {
    return _enumSpecChecker.hasAnnotationOfExact(element);
  }

  /// Analyzes the given [element] and extracts enum information.
  ///
  /// Returns `null` if the element does not have an @EnumSpec annotation.
  EnumInfo? analyze(EnumElement element) {
    final annotation = _enumSpecChecker.firstAnnotationOfExact(element);
    if (annotation == null) return null;

    final identifier = annotation.getField('identifier')?.toStringValue();
    final title = annotation.getField('title')?.toStringValue();

    if (identifier == null || title == null) return null;

    final cases = _extractCases(element);

    return EnumInfo(
      className: element.name,
      identifier: identifier,
      title: title,
      cases: cases,
    );
  }

  List<EnumCaseInfo> _extractCases(EnumElement element) {
    final cases = <EnumCaseInfo>[];

    for (final field in element.fields) {
      if (!field.isEnumConstant) continue;

      final displayAnnotation =
          _enumCaseDisplayChecker.firstAnnotationOfExact(field);
      final displayTitle =
          displayAnnotation?.getField('title')?.toStringValue() ??
              _toDisplayTitle(field.name);

      cases.add(EnumCaseInfo(
        name: field.name,
        displayTitle: displayTitle,
      ));
    }

    return cases;
  }

  /// Converts camelCase to capitalized display title.
  String _toDisplayTitle(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }
}
