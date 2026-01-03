// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';
import 'package:source_gen/source_gen.dart';

import '../generator/swift_generator.dart';

/// Type checker for AppShortcut annotation.
const _appShortcutChecker = TypeChecker.fromRuntime(AppShortcut);

/// Type checker for AppShortcutsProvider annotation.
const _appShortcutsProviderChecker = TypeChecker.fromRuntime(AppShortcutsProvider);

/// Analyzer for extracting shortcut information from annotated classes.
class ShortcutAnalyzer {
  /// Creates a new [ShortcutAnalyzer].
  const ShortcutAnalyzer();

  /// Checks if the given [element] has an @AppShortcutsProvider annotation.
  bool hasAppShortcutsProviderAnnotation(ClassElement element) {
    return _appShortcutsProviderChecker.hasAnnotationOfExact(element);
  }

  /// Analyzes the given provider [element] and extracts all shortcut information.
  ///
  /// Returns a list of [AppShortcutInfo] for each @AppShortcut annotated field.
  List<AppShortcutInfo> analyze(ClassElement element) {
    if (!hasAppShortcutsProviderAnnotation(element)) {
      return [];
    }

    final shortcuts = <AppShortcutInfo>[];

    for (final field in element.fields) {
      final annotation = _appShortcutChecker.firstAnnotationOfExact(field);
      if (annotation == null) continue;

      final intentIdentifier =
          annotation.getField('intentIdentifier')?.toStringValue();
      final phrasesField = annotation.getField('phrases');
      final shortTitle = annotation.getField('shortTitle')?.toStringValue();
      final systemImageName =
          annotation.getField('systemImageName')?.toStringValue();

      if (intentIdentifier == null || shortTitle == null) continue;

      final phrases = _extractPhrases(phrasesField);
      if (phrases.isEmpty) continue;

      shortcuts.add(AppShortcutInfo(
        intentClassName: intentIdentifier,
        phrases: phrases,
        shortTitle: shortTitle,
        systemImageName: systemImageName ?? 'star.fill',
      ));
    }

    return shortcuts;
  }

  List<String> _extractPhrases(dynamic phrasesField) {
    if (phrasesField == null) return [];

    final list = phrasesField.toListValue();
    if (list == null) return [];

    return list
        .map((e) => e?.toStringValue())
        .whereType<String>()
        .toList();
  }
}
