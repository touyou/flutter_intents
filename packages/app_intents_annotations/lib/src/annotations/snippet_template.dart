/// A declarative description of the card Siri shows alongside an intent's
/// result.
///
/// App Intents renders these cards with SwiftUI, which a Flutter app has no
/// way to supply — a Flutter widget tree cannot be handed to Siri. So instead
/// of taking a view, this takes a small fixed layout (image, title, subtitle,
/// labelled rows) that the generator turns into a concrete SwiftUI view. It is
/// deliberately not a general-purpose UI language: anything beyond this shape
/// belongs in the app itself, reached with `openAppWhenRun`.
///
/// Text fields accept two kinds of placeholder:
///
/// - `{paramName}` — an intent parameter, the same syntax as
///   `resultDialogTemplate`. Works in every execution mode.
/// - `{result.key}` — a key of the map the Dart handler returns. Only
///   available when the intent runs through FlutterBridge, because the URL
///   scheme and cache modes hand off to the app and return before the handler
///   has produced anything. Using one elsewhere is a code generation error.
///
/// Example:
///
/// ```dart
/// @IntentSpec(
///   identifier: 'com.example.app.createTask',
///   title: 'Create Task',
///   resultDialogTemplate: 'Created {title}',
///   snippet: SnippetTemplate(
///     title: '{title}',
///     subtitle: 'Added to {result.listName}',
///     systemImageName: 'checkmark.circle.fill',
///     rows: [SnippetRow(label: 'Due', value: '{result.dueDate}')],
///   ),
/// )
/// ```
class SnippetTemplate {
  /// The card's headline. Required — a card with no title has nothing to say.
  final String title;

  /// A secondary line under the title. Omitted from the view when null.
  final String? subtitle;

  /// An SF Symbol shown leading the title (e.g. `'checkmark.circle.fill'`).
  final String? systemImageName;

  /// Labelled rows under the headline, rendered as `LabeledContent`.
  ///
  /// Labels are literal text and are localized through the String Catalog;
  /// values are interpolated per run.
  final List<SnippetRow> rows;

  const SnippetTemplate({
    required this.title,
    this.subtitle,
    this.systemImageName,
    this.rows = const [],
  });
}

/// One labelled row of a [SnippetTemplate].
class SnippetRow {
  /// The static label on the leading side of the row.
  final String label;

  /// The row's value. Supports the same placeholders as [SnippetTemplate].
  final String value;

  const SnippetRow({required this.label, required this.value});
}
