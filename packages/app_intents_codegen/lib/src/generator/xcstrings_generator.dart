import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../cli/analyze_sources.dart';

/// Generates iOS String Catalog (.xcstrings) files from analyzed annotations.
///
/// Collects all localizable strings from IntentInfo, EntityInfo, EnumInfo,
/// and AppShortcutInfo, then produces a .xcstrings JSON file with optional
/// translations from a YAML file.
class XcstringsGenerator {
  /// The source language code for the String Catalog (e.g., "en").
  final String sourceLanguage;

  const XcstringsGenerator({this.sourceLanguage = 'en'});

  /// Collects all localizable strings from an [AnalyzeResult].
  ///
  /// Returns a set of unique strings that should appear in the String Catalog.
  Set<String> collectLocalizableStrings(AnalyzeResult result) {
    final strings = <String>{};

    for (final intent in result.intents) {
      strings.add(intent.title);
      if (intent.description != null) {
        strings.add(intent.description!);
      }
      if (intent.resultDialogTemplate != null) {
        strings.add(intent.resultDialogTemplate!);
      }
      if (intent.parameterSummary != null) {
        strings.add(intent.parameterSummary!);
      }
      for (final param in intent.parameters) {
        strings.add(param.title);
        if (param.description != null) {
          strings.add(param.description!);
        }
      }
    }

    for (final entity in result.entities) {
      strings.add(entity.title);
    }

    for (final enumInfo in result.enums) {
      strings.add(enumInfo.title);
      for (final enumCase in enumInfo.cases) {
        strings.add(enumCase.displayTitle);
      }
    }

    for (final shortcut in result.shortcuts) {
      strings.add(shortcut.shortTitle);
      strings.addAll(shortcut.phrases);
    }

    return strings;
  }

  /// Loads translations from a YAML file.
  ///
  /// The YAML format is:
  /// ```yaml
  /// ja:
  ///   "Create Task": "タスクを作成"
  ///   "Title": "タイトル"
  /// zh-Hans:
  ///   "Create Task": "创建任务"
  /// ```
  ///
  /// Returns a map of language code → (key → translation).
  Map<String, Map<String, String>> loadTranslations(String yamlPath) {
    final file = File(yamlPath);
    if (!file.existsSync()) {
      return {};
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content);

    if (yaml is! YamlMap) {
      return {};
    }

    final result = <String, Map<String, String>>{};
    for (final entry in yaml.entries) {
      final langCode = entry.key.toString();
      final translations = entry.value;
      if (translations is YamlMap) {
        final langMap = <String, String>{};
        for (final t in translations.entries) {
          langMap[t.key.toString()] = t.value.toString();
        }
        result[langCode] = langMap;
      }
    }

    return result;
  }

  /// Generates a .xcstrings JSON string.
  ///
  /// [analyzeResult] provides the localizable strings from annotations.
  /// [translations] provides translations keyed by language code.
  /// [existingXcstringsPath] loads and merges with an existing .xcstrings file.
  String generate({
    required AnalyzeResult analyzeResult,
    Map<String, Map<String, String>> translations = const {},
    String? existingXcstringsPath,
  }) {
    final localizableStrings = collectLocalizableStrings(analyzeResult);

    // Load existing .xcstrings for merging
    Map<String, dynamic>? existing;
    if (existingXcstringsPath != null) {
      final file = File(existingXcstringsPath);
      if (file.existsSync()) {
        existing =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      }
    }

    final existingStrings =
        (existing?['strings'] as Map<String, dynamic>?) ?? {};

    // Build strings map
    final stringsMap = <String, dynamic>{};
    final sortedKeys = localizableStrings.toList()..sort();

    for (final key in sortedKeys) {
      final localizations = <String, dynamic>{};

      // Source language entry
      localizations[sourceLanguage] = {
        'stringUnit': {
          'state': 'translated',
          'value': convertPlaceholders(key),
        },
      };

      // Add translations from YAML
      for (final entry in translations.entries) {
        final langCode = entry.key;
        final langTranslations = entry.value;
        if (langTranslations.containsKey(key)) {
          localizations[langCode] = {
            'stringUnit': {
              'state': 'translated',
              'value': convertPlaceholders(langTranslations[key]!),
            },
          };
        }
      }

      // Merge with existing translations (preserve languages not in YAML)
      final existingEntry =
          existingStrings[key] as Map<String, dynamic>?;
      if (existingEntry != null) {
        final existingLocalizations =
            existingEntry['localizations'] as Map<String, dynamic>?;
        if (existingLocalizations != null) {
          for (final entry in existingLocalizations.entries) {
            if (!localizations.containsKey(entry.key)) {
              localizations[entry.key] = entry.value;
            }
          }
        }
      }

      stringsMap[key] = {
        'extractionState': 'manual',
        'localizations': localizations,
      };
    }

    final output = {
      'sourceLanguage': sourceLanguage,
      'strings': stringsMap,
      'version': '1.0',
    };

    final encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(output)}\n';
  }

  /// Converts `{paramName}` placeholders to `%@` format for .xcstrings values.
  ///
  /// Single placeholder: `{title}` → `%@`
  /// Multiple placeholders: `{title}` and `{description}` → `%1$@` and `%2$@`
  ///
  /// System variables like `${applicationName}` (prefixed with `$`) are preserved
  /// as-is since they are resolved by the system at runtime.
  String convertPlaceholders(String text) {
    // Match {word} but NOT ${word} (system variables)
    final pattern = RegExp(r'(?<!\$)\{(\w+)\}');
    final matches = pattern.allMatches(text).toList();

    if (matches.isEmpty) return text;

    if (matches.length == 1) {
      return text.replaceFirst(pattern, '%@');
    }

    // Multiple placeholders: use positional format
    var result = text;
    for (var i = matches.length - 1; i >= 0; i--) {
      final match = matches[i];
      result = result.replaceRange(
        match.start,
        match.end,
        '%${i + 1}\$@',
      );
    }
    return result;
  }
}
