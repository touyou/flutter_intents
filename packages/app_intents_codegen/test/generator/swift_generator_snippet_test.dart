import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:app_intents_codegen/src/models/snippet_info.dart';
import 'package:test/test.dart';

IntentInfo _intent({SnippetInfo? snippet, String? dialog, String? urlScheme}) =>
    IntentInfo(
      className: 'CreateTaskIntent',
      identifier: 'com.example.createTask',
      title: 'Create Task',
      implementation: IntentImplementationType.dart,
      urlScheme: urlScheme,
      resultDialogTemplate: dialog,
      snippet: snippet,
      parameters: const [
        IntentParamInfo(
          fieldName: 'title',
          dartType: 'String',
          title: 'Task Title',
          isOptional: false,
        ),
      ],
    );

void main() {
  const generator = SwiftGenerator();

  group('SwiftGenerator snippet view', () {
    test('no snippet leaves the intent and imports untouched', () {
      final result = generator.generateAll(intents: [_intent()]);
      expect(result, isNot(contains('import SwiftUI')));
      expect(result, isNot(contains('SnippetView')));
      expect(
        result,
        contains('let _ = try await FlutterBridge.shared.invoke('),
      );
    });

    test('emits a view struct and imports SwiftUI', () {
      final result = generator.generateAll(
        intents: [
          _intent(
            snippet: const SnippetInfo(
              title: '{title}',
              subtitle: 'Saved',
              systemImageName: 'checkmark.circle.fill',
              rows: [SnippetRowInfo(label: 'List', value: 'Inbox')],
            ),
          ),
        ],
      );

      expect(result, contains('import SwiftUI'));
      expect(result, contains('struct CreateTaskIntentSnippetView: View {'));
      expect(result, contains('let snippetTitle: String'));
      expect(result, contains('let snippetSubtitle: String'));
      expect(result, contains('let rowValue0: String'));
      expect(result, contains('Image(systemName: "checkmark.circle.fill")'));
      expect(result, contains('LabeledContent("List") {'));
      expect(
        result,
        contains(
          'func perform() async throws -> some IntentResult & ShowsSnippetView',
        ),
      );
      expect(
        result,
        contains(r'return .result(view: CreateTaskIntentSnippetView('),
      );
      expect(result, contains(r'snippetTitle: "\(title)"'));
    });

    test('emits no leaked Dart interpolation', () {
      // The golden assertions below all passed while the view body contained a
      // literal `$i5$_indent` — string tests cannot see a broken indent helper,
      // only the Swift typecheck can. This guards the cheap half of that.
      final result = generator.generateAll(
        intents: [
          _intent(
            snippet: const SnippetInfo(
              title: '{title}',
              subtitle: 'Saved',
              systemImageName: 'star',
              rows: [SnippetRowInfo(label: 'Due', value: '{result.dueDate}')],
            ),
          ),
        ],
      );
      expect(result, isNot(contains(r'$_indent')));
      expect(result, isNot(contains(r'$i4')));
      expect(result, isNot(contains(r'$i5')));
    });

    test('omits the subtitle property when the template has none', () {
      final result = generator.generateAll(
        intents: [_intent(snippet: const SnippetInfo(title: '{title}'))],
      );
      expect(result, isNot(contains('snippetSubtitle')));
      expect(result, isNot(contains('Image(systemName:')));
    });

    test('combines with a dialog in the return type and call', () {
      final result = generator.generateAll(
        intents: [
          _intent(
            dialog: 'Created {title}',
            snippet: const SnippetInfo(title: '{title}'),
          ),
        ],
      );
      expect(
        result,
        contains('some IntentResult & ProvidesDialog & ShowsSnippetView'),
      );
      expect(result, contains('return .result(dialog: .init('));
      expect(result, contains(', view: CreateTaskIntentSnippetView('));
    });

    test('binds the invoke result only when {result.…} is read', () {
      final result = generator.generateAll(
        intents: [
          _intent(
            snippet: const SnippetInfo(
              title: '{title}',
              rows: [SnippetRowInfo(label: 'Due', value: '{result.dueDate}')],
            ),
          ),
        ],
      );

      expect(
        result,
        contains('let snippetResult = try await FlutterBridge.shared.invoke('),
      );
      expect(
        result,
        contains('let snippetValues = snippetResult as? [String: Any] ?? [:]'),
      );
      expect(
        result,
        contains(
          'let snippetValue_dueDate = snippetValues["dueDate"].map '
          '{ String(describing: \$0) } ?? ""',
        ),
      );
      expect(result, contains(r'rowValue0: "\(snippetValue_dueDate)"'));
    });

    test('a dialog can read {result.…} too', () {
      // The dialog and the card describe the same result; it would be strange
      // for only one of them to be able to name a handler value.
      final result = generator.generateAll(
        intents: [
          _intent(
            dialog: 'You have {result.openCount} left',
            snippet: const SnippetInfo(title: 'Summary'),
          ),
        ],
      );
      expect(
        result,
        contains('let snippetValue_openCount = snippetValues["openCount"]'),
      );
      expect(
        result,
        contains(r'.init("You have \(snippetValue_openCount) left")'),
      );
      expect(result, isNot(contains('{result.openCount}')));
    });

    test('escapes author text before embedding it in a Swift literal', () {
      final result = generator.generateAll(
        intents: [
          _intent(
            snippet: const SnippetInfo(
              title: '{title}',
              systemImageName: 'a"b',
              rows: [SnippetRowInfo(label: 'He said "hi"', value: 'x')],
            ),
          ),
        ],
      );
      expect(result, contains(r'Image(systemName: "a\"b")'));
      expect(result, contains(r'LabeledContent("He said \"hi\"") {'));
    });
  });
}
