/// Shared parsing for the `{name}` placeholders used in dialog and snippet
/// templates.
///
/// The analyzer decides whether a template is legal, the Dart generator decides
/// whether the handler's result must be kept, and the Swift generator does the
/// substitution. When each kept its own regex those three drifted apart — one
/// accepted `{ result.x }` while another failed to substitute it, which shows
/// up as a literal `{ result.x }` in Siri rather than as an error. They all go
/// through this file now.
library;

/// Matches one `{name}` placeholder, tolerating padding inside the braces.
final RegExp _placeholder = RegExp(r'\{\s*([^{}]+?)\s*\}');

/// The prefix marking a placeholder that reads the Dart handler's result.
const String resultPlaceholderPrefix = 'result.';

/// The placeholder names in [template], in order, with padding trimmed.
Iterable<String> placeholderNames(String template) =>
    _placeholder.allMatches(template).map((m) => m.group(1)!);

/// Whether any of [templates] reads the Dart handler's returned map.
bool readsHandlerResult(Iterable<String> templates) => templates.any(
  (template) => placeholderNames(
    template,
  ).any((name) => name.startsWith(resultPlaceholderPrefix)),
);

/// The distinct handler-result keys read by [templates], in first-use order.
List<String> handlerResultKeys(Iterable<String> templates) {
  final keys = <String>[];
  for (final template in templates) {
    for (final name in placeholderNames(template)) {
      if (!name.startsWith(resultPlaceholderPrefix)) continue;
      final key = name.substring(resultPlaceholderPrefix.length);
      if (key.isNotEmpty && !keys.contains(key)) keys.add(key);
    }
  }
  return keys;
}

/// Replaces every `{[name]}` placeholder in [template] with [replacement].
///
/// Matches the same padded forms [placeholderNames] reports, so a template the
/// analyzer accepted cannot silently survive substitution.
String substitutePlaceholder(
  String template,
  String name,
  String replacement,
) => template.replaceAllMapped(
  _placeholder,
  (m) => m.group(1) == name ? replacement : m.group(0)!,
);
