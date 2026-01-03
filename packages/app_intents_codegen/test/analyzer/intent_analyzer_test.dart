// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:app_intents_codegen/src/analyzer/intent_analyzer.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('IntentAnalyzer', () {
    late IntentAnalyzer analyzer;

    setUp(() {
      analyzer = IntentAnalyzer();
    });

    group('analyze', () {
      test('extracts basic intent information from @IntentSpec annotation',
          () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
          )
          class GreetIntent extends IntentSpecBase<String, void> {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'GreetIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.className, equals('GreetIntent'));
        expect(result.identifier, equals('com.example.greet'));
        expect(result.title, equals('Greet User'));
        expect(result.description, isNull);
        expect(result.implementation, equals(IntentImplementationType.dart));
      });

      test('extracts description when provided', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
            description: 'Greets the user with a friendly message',
          )
          class GreetIntent extends IntentSpecBase<String, void> {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'GreetIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(
            result!.description, equals('Greets the user with a friendly message'));
      });

      test('extracts swift implementation type', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
            implementation: IntentImplementation.swift,
          )
          class GreetIntent extends IntentSpecBase<String, void> {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'GreetIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.implementation, equals(IntentImplementationType.swift));
      });

      test('extracts input and output types from IntentSpecBase', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.add',
            title: 'Add Numbers',
          )
          class AddIntent extends IntentSpecBase<int, int> {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'AddIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.inputType, equals('int'));
        expect(result.outputType, equals('int'));
      });

      test('extracts parameters with @IntentParam annotation', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.greet',
            title: 'Greet User',
          )
          class GreetIntent extends IntentSpecBase<String, void> {
            @IntentParam(title: 'User Name')
            final String name;

            @IntentParam(
              title: 'Greeting Message',
              description: 'The message to display',
              isOptional: true,
            )
            final String? message;

            GreetIntent({required this.name, this.message});
          }
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'GreetIntent');

        final result = analyzer.analyze(classElement);

        expect(result, isNotNull);
        expect(result!.parameters, hasLength(2));

        final nameParam = result.parameters.firstWhere((p) => p.fieldName == 'name');
        expect(nameParam.title, equals('User Name'));
        expect(nameParam.dartType, equals('String'));
        expect(nameParam.isOptional, isFalse);
        expect(nameParam.description, isNull);

        final messageParam =
            result.parameters.firstWhere((p) => p.fieldName == 'message');
        expect(messageParam.title, equals('Greeting Message'));
        expect(messageParam.dartType, equals('String?'));
        expect(messageParam.isOptional, isTrue);
        expect(messageParam.description, equals('The message to display'));
      });

      test('returns null for class without @IntentSpec annotation', () async {
        final library = await resolveSource('''
          class PlainClass {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'PlainClass');

        final result = analyzer.analyze(classElement);

        expect(result, isNull);
      });
    });

    group('hasIntentSpecAnnotation', () {
      test('returns true for class with @IntentSpec annotation', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @IntentSpec(
            identifier: 'com.example.test',
            title: 'Test Intent',
          )
          class TestIntent extends IntentSpecBase<void, void> {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'TestIntent');

        expect(analyzer.hasIntentSpecAnnotation(classElement), isTrue);
      });

      test('returns false for class without @IntentSpec annotation', () async {
        final library = await resolveSource('''
          class PlainClass {}
        ''');

        final classElement = library.topLevelElements
            .whereType<ClassElement>()
            .firstWhere((e) => e.name == 'PlainClass');

        expect(analyzer.hasIntentSpecAnnotation(classElement), isFalse);
      });
    });
  });
}
