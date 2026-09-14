/// A parsed `@IntentSpec(snippet:)` template.
///
/// Describes the SwiftUI card generated for an intent's result. See
/// `SnippetTemplate` in `app_intents_annotations` for the authoring contract
/// and `docs/adr/0007-declarative-snippet-view.md` for why the layout is fixed
/// rather than open-ended.
class SnippetInfo {
  /// The card's headline template.
  final String title;

  /// An optional second line under the headline.
  final String? subtitle;

  /// An optional SF Symbol leading the headline.
  final String? systemImageName;

  /// Labelled rows under the headline.
  final List<SnippetRowInfo> rows;

  const SnippetInfo({
    required this.title,
    this.subtitle,
    this.systemImageName,
    this.rows = const [],
  });

  /// Every text template in the snippet, in render order.
  List<String> get templates => [
    title,
    ?subtitle,
    for (final row in rows) row.value,
  ];

  @override
  bool operator ==(Object other) =>
      other is SnippetInfo &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.systemImageName == systemImageName &&
      other.rows.length == rows.length &&
      List.generate(
        rows.length,
        (i) => rows[i] == other.rows[i],
      ).every((e) => e);

  @override
  int get hashCode =>
      Object.hash(title, subtitle, systemImageName, Object.hashAll(rows));

  @override
  String toString() =>
      'SnippetInfo(title: $title, subtitle: $subtitle, '
      'systemImageName: $systemImageName, rows: $rows)';
}

/// One labelled row of a [SnippetInfo].
class SnippetRowInfo {
  /// The static label, localized through the String Catalog.
  final String label;

  /// The row's value template.
  final String value;

  const SnippetRowInfo({required this.label, required this.value});

  @override
  bool operator ==(Object other) =>
      other is SnippetRowInfo && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);

  @override
  String toString() => 'SnippetRowInfo(label: $label, value: $value)';
}
