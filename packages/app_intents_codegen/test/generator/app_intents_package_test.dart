import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/generator/widget_swift_generator.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

const _intent = IntentInfo(
  className: 'CreateTaskIntent',
  identifier: 'com.example.createTask',
  title: 'Create Task',
  implementation: IntentImplementationType.dart,
  parameters: [],
);

void main() {
  const generator = SwiftGenerator();

  group('SwiftGenerator AppIntentsPackage', () {
    test('emits nothing without the option', () {
      final result = generator.generateAll(intents: [_intent]);
      expect(result, isNot(contains('AppIntentsPackage')));
    });

    test('emits a bare package declaration', () {
      final result = generator.generateAll(
        intents: [_intent],
        appIntentsPackage: 'TaskAppIntentsPackage',
      );
      expect(result, contains('@available(iOS 17.0, *)'));
      expect(
        result,
        contains('struct TaskAppIntentsPackage: AppIntentsPackage {}'),
      );
    });

    test('lists includedPackages and imports their modules', () {
      final result = generator.generateAll(
        intents: [_intent],
        appIntentsPackage: 'TaskAppIntentsPackage',
        includedPackages: [
          'SharedIntents.SharedIntentsPackage',
          'OtherIntents.OtherIntentsPackage',
        ],
      );

      expect(result, contains('import SharedIntents'));
      expect(result, contains('import OtherIntents'));
      expect(
        result,
        contains('struct TaskAppIntentsPackage: AppIntentsPackage {'),
      );
      expect(
        result,
        contains('[SharedIntentsPackage.self, OtherIntentsPackage.self]'),
      );
    });

    test('imports a module only once when two types share it', () {
      final result = generator.generateAll(
        intents: [_intent],
        appIntentsPackage: 'TaskAppIntentsPackage',
        includedPackages: ['Shared.APackage', 'Shared.BPackage'],
      );
      expect('import Shared'.allMatches(result).length, 1);
    });

    test('keeps a nested type path under the module', () {
      // Importing SharedIntents makes `Groups.SharedPackage` reachable, not
      // `SharedPackage` — dropping the whole path would not compile.
      final result = generator.generateAll(
        intents: [_intent],
        appIntentsPackage: 'TaskAppIntentsPackage',
        includedPackages: ['SharedIntents.Groups.SharedPackage'],
      );
      expect(result, contains('import SharedIntents'));
      expect(result, contains('[Groups.SharedPackage.self]'));
    });

    test('an unqualified type name needs no import', () {
      // Same-module package types are legitimate; do not emit `import `.
      final result = generator.generateAll(
        intents: [_intent],
        appIntentsPackage: 'TaskAppIntentsPackage',
        includedPackages: ['LocalPackage'],
      );
      expect(result, contains('[LocalPackage.self]'));
      expect(result, isNot(contains('import LocalPackage')));
    });
  });

  group('WidgetSwiftGenerator AppIntentsPackage', () {
    test('keeps a nested type path under the module', () {
      const generator = WidgetSwiftGenerator(
        appGroupIdentifier: 'group.com.example.app',
        storageIdentifier: 'com.example.app',
      );
      final result = generator.generateAll(
        configurations: const [],
        entities: const [],
        appIntentsPackage: 'TaskWidgetAppIntentsPackage',
        includedPackages: ['SharedIntents.Groups.SharedPackage'],
      );
      expect(result, contains('import SharedIntents'));
      expect(result, contains('[Groups.SharedPackage.self]'));
      expect(
        result,
        contains('struct TaskWidgetAppIntentsPackage: AppIntentsPackage {'),
      );
    });
  });
}
