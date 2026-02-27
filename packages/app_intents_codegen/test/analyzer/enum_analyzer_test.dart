// ignore_for_file: deprecated_member_use, unnecessary_non_null_assertion
import 'package:analyzer/dart/element/element.dart';
import 'package:app_intents_codegen/src/analyzer/enum_analyzer.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('EnumAnalyzer', () {
    late EnumAnalyzer analyzer;

    setUp(() {
      analyzer = const EnumAnalyzer();
    });

    group('analyze', () {
      test('extracts basic enum information from @EnumSpec annotation',
          () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @EnumSpec(
            identifier: 'com.example.priority',
            title: 'Priority',
          )
          enum TaskPriority {
            high,
            medium,
            low,
          }
        ''');

        final enumElement = findEnum(library, 'TaskPriority');

        final result = analyzer.analyze(enumElement);

        expect(result, isNotNull);
        expect(result!.className, equals('TaskPriority'));
        expect(result.identifier, equals('com.example.priority'));
        expect(result.title, equals('Priority'));
        expect(result.cases, hasLength(3));
        expect(result.cases[0].name, equals('high'));
        expect(result.cases[0].displayTitle, equals('High'));
        expect(result.cases[1].name, equals('medium'));
        expect(result.cases[1].displayTitle, equals('Medium'));
        expect(result.cases[2].name, equals('low'));
        expect(result.cases[2].displayTitle, equals('Low'));
      });

      test('extracts custom display titles from @EnumCaseDisplay', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @EnumSpec(
            identifier: 'com.example.priority',
            title: 'Priority',
          )
          enum TaskPriority {
            @EnumCaseDisplay(title: 'Very Important')
            high,
            @EnumCaseDisplay(title: 'Normal')
            medium,
            low,
          }
        ''');

        final enumElement = findEnum(library, 'TaskPriority');

        final result = analyzer.analyze(enumElement);

        expect(result, isNotNull);
        expect(result!.cases[0].displayTitle, equals('Very Important'));
        expect(result.cases[1].displayTitle, equals('Normal'));
        expect(result.cases[2].displayTitle, equals('Low'));
      });

      test('returns null for enum without @EnumSpec annotation', () async {
        final library = await resolveSource('''
          enum PlainEnum {
            a,
            b,
          }
        ''');

        final enumElement = findEnum(library, 'PlainEnum');

        final result = analyzer.analyze(enumElement);

        expect(result, isNull);
      });

      test('extracts imageName from @EnumCaseDisplay', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @EnumSpec(
            identifier: 'com.example.category',
            title: 'Category',
          )
          enum FeedCategory {
            @EnumCaseDisplay(title: 'Feed', imageName: 'feed')
            feed,
            @EnumCaseDisplay(title: 'Explore')
            explore,
            discover,
          }
        ''');

        final enumElement = findEnum(library, 'FeedCategory');

        final result = analyzer.analyze(enumElement);

        expect(result, isNotNull);
        expect(result!.cases[0].imageName, equals('feed'));
        expect(result.cases[1].imageName, isNull);
        expect(result.cases[2].imageName, isNull);
      });
    });

    group('hasEnumSpecAnnotation', () {
      test('returns true for enum with @EnumSpec annotation', () async {
        final library = await resolveSource('''
          import 'package:app_intents_annotations/app_intents_annotations.dart';

          @EnumSpec(
            identifier: 'com.example.priority',
            title: 'Priority',
          )
          enum TaskPriority {
            high,
            low,
          }
        ''');

        final enumElement = findEnum(library, 'TaskPriority');

        expect(analyzer.hasEnumSpecAnnotation(enumElement), isTrue);
      });

      test('returns false for enum without @EnumSpec annotation', () async {
        final library = await resolveSource('''
          enum PlainEnum {
            a,
            b,
          }
        ''');

        final enumElement = findEnum(library, 'PlainEnum');

        expect(analyzer.hasEnumSpecAnnotation(enumElement), isFalse);
      });
    });
  });
}
