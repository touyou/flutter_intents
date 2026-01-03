import 'package:app_intents_annotations/app_intents_annotations.dart';
import 'package:test/test.dart';

void main() {
  group('IntentSpecBase', () {
    test('can be extended with specific input and output types', () {
      final intentSpec = MyIntentSpec();
      expect(intentSpec, isA<IntentSpecBase<String, int>>());
    });
  });

  group('AppShortcut', () {
    test('can be created with required parameters', () {
      const shortcut = AppShortcut(
        intentIdentifier: 'CreateTaskIntent',
        phrases: ['Create a task', 'Add task'],
        shortTitle: 'Create Task',
      );

      expect(shortcut.intentIdentifier, equals('CreateTaskIntent'));
      expect(shortcut.phrases, equals(['Create a task', 'Add task']));
      expect(shortcut.shortTitle, equals('Create Task'));
      expect(shortcut.systemImageName, isNull);
    });

    test('can be created with optional systemImageName', () {
      const shortcut = AppShortcut(
        intentIdentifier: 'CreateTaskIntent',
        phrases: ['Create a task'],
        shortTitle: 'Create Task',
        systemImageName: 'plus.circle',
      );

      expect(shortcut.systemImageName, equals('plus.circle'));
    });

    test('is const constructible for use as annotation', () {
      // This test verifies that AppShortcut can be used as a const annotation
      const annotation = AppShortcut(
        intentIdentifier: 'TestIntent',
        phrases: ['Test phrase'],
        shortTitle: 'Test',
      );
      expect(annotation, isA<AppShortcut>());
    });
  });

  group('AppShortcutsProvider', () {
    test('can be created with const constructor', () {
      const provider = AppShortcutsProvider();
      expect(provider, isA<AppShortcutsProvider>());
    });

    test('is const constructible for use as annotation', () {
      // This test verifies that AppShortcutsProvider can be used as a const annotation
      const annotation = AppShortcutsProvider();
      expect(annotation, isA<AppShortcutsProvider>());
    });
  });
}

class MyIntentSpec extends IntentSpecBase<String, int> {
  const MyIntentSpec();
}
