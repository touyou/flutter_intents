import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

IntentInfo _intent({
  String? supporting,
  String? systemImageName,
  String? full = 'I created the task {title}',
}) => IntentInfo(
  className: 'CreateTaskIntent',
  identifier: 'com.example.createTask',
  title: 'Create Task',
  implementation: IntentImplementationType.dart,
  parameters: const [
    IntentParamInfo(
      fieldName: 'title',
      dartType: 'String',
      title: 'Task Title',
      isOptional: false,
    ),
  ],
  resultDialogTemplate: full,
  resultDialogSupportingTemplate: supporting,
  resultDialogSystemImageName: systemImageName,
);

void main() {
  const generator = SwiftGenerator();

  group('SwiftGenerator IntentDialog(full:supporting:)', () {
    test('a lone template still emits the short .init form', () {
      final result = generator.generateIntent(_intent());
      expect(result, contains(r'return .result(dialog: .init("'));
      expect(result, isNot(contains('IntentDialog(full:')));
    });

    test('adding a supporting template emits full:supporting:', () {
      final result = generator.generateIntent(
        _intent(supporting: 'Task created'),
      );
      expect(
        result,
        contains(
          'return .result(dialog: IntentDialog(full: "I created the task '
          r'\(title)", supporting: "Task created"))',
        ),
      );
    });

    test('a symbol is built behind an iOS 17.2 availability check', () {
      // The symbol initializers are 17.2+ but generated intents target 17.0,
      // so the symbol must not be the only form emitted.
      final result = generator.generateIntent(
        _intent(
          supporting: 'Task created',
          systemImageName: 'checkmark.circle',
        ),
      );
      expect(result, contains('let dialog: IntentDialog'));
      expect(result, contains('if #available(iOS 17.2, *) {'));
      expect(result, contains('systemImageName: "checkmark.circle")'));
      expect(
        result,
        contains(
          'dialog = IntentDialog(full: "I created the task '
          r'\(title)", supporting: "Task created")',
        ),
      );
      expect(result, contains('return .result(dialog: dialog)'));
    });

    test('a symbol without a supporting template still falls back', () {
      final result = generator.generateIntent(
        _intent(systemImageName: 'checkmark.circle'),
      );
      expect(result, contains('if #available(iOS 17.2, *) {'));
      expect(
        result,
        contains(r'dialog = IntentDialog("I created the task \(title)")'),
      );
    });

    test('no dialog at all returns a plain result', () {
      final result = generator.generateIntent(_intent(full: null));
      expect(result, contains('return .result()'));
      expect(result, isNot(contains('some IntentResult & ProvidesDialog')));
    });
  });
}
