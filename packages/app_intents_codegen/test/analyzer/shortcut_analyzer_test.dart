// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:app_intents_codegen/src/analyzer/shortcut_analyzer.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('ShortcutAnalyzer', () {
    late ShortcutAnalyzer analyzer;

    setUp(() {
      analyzer = ShortcutAnalyzer();
    });

    group('hasAppShortcutsProviderAnnotation', () {
      test('returns true for class with @AppShortcutsProvider', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @AppShortcutsProvider()
          class MyAppShortcuts {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'MyAppShortcuts');

        expect(analyzer.hasAppShortcutsProviderAnnotation(classElement), isTrue);
      });

      test('returns false for class without @AppShortcutsProvider', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          class MyAppShortcuts {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'MyAppShortcuts');

        expect(analyzer.hasAppShortcutsProviderAnnotation(classElement), isFalse);
      });
    });

    group('analyze', () {
      test('extracts shortcut information from @AppShortcut annotations',
          () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @AppShortcutsProvider()
          class MyAppShortcuts {
            @AppShortcut(
              intentIdentifier: 'CreateTaskIntent',
              phrases: ['Create a task', 'Add task'],
              shortTitle: 'Create Task',
              systemImageName: 'plus.circle',
            )
            static const createTask = null;
          }
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'MyAppShortcuts');

        final result = analyzer.analyze(classElement);

        expect(result, hasLength(1));
        expect(result[0].intentClassName, equals('CreateTaskIntent'));
        expect(result[0].phrases, equals(['Create a task', 'Add task']));
        expect(result[0].shortTitle, equals('Create Task'));
        expect(result[0].systemImageName, equals('plus.circle'));
      });

      test('extracts multiple shortcuts from provider class', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @AppShortcutsProvider()
          class MyAppShortcuts {
            @AppShortcut(
              intentIdentifier: 'CreateTaskIntent',
              phrases: ['Create a task'],
              shortTitle: 'Create Task',
              systemImageName: 'plus.circle',
            )
            static const createTask = null;

            @AppShortcut(
              intentIdentifier: 'CompleteTaskIntent',
              phrases: ['Complete task'],
              shortTitle: 'Complete Task',
              systemImageName: 'checkmark.circle',
            )
            static const completeTask = null;
          }
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'MyAppShortcuts');

        final result = analyzer.analyze(classElement);

        expect(result, hasLength(2));
        expect(result[0].intentClassName, equals('CreateTaskIntent'));
        expect(result[1].intentClassName, equals('CompleteTaskIntent'));
      });

      test('uses default system image when not provided', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @AppShortcutsProvider()
          class MyAppShortcuts {
            @AppShortcut(
              intentIdentifier: 'CreateTaskIntent',
              phrases: ['Create a task'],
              shortTitle: 'Create Task',
            )
            static const createTask = null;
          }
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'MyAppShortcuts');

        final result = analyzer.analyze(classElement);

        expect(result, hasLength(1));
        expect(result[0].systemImageName, equals('star.fill'));
      });

      test('returns empty list for class without @AppShortcutsProvider',
          () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          class MyAppShortcuts {
            @AppShortcut(
              intentIdentifier: 'CreateTaskIntent',
              phrases: ['Create a task'],
              shortTitle: 'Create Task',
            )
            static const createTask = null;
          }
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'MyAppShortcuts');

        final result = analyzer.analyze(classElement);

        expect(result, isEmpty);
      });
    });
  });
}
