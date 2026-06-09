import 'package:app_intents_codegen/src/analyzer/enum_analyzer.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('EnumAnalyzer (WWDC26 #49 schema)', () {
    late EnumAnalyzer analyzer;

    setUp(() {
      analyzer = EnumAnalyzer();
    });

    test('parses enum schema field', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @EnumSpec(
          identifier: 'com.example.MessageType',
          title: 'Message Type',
          schema: 'messages.messageType',
        )
        enum MessageType {
          text,
          image,
        }
      ''');

      final result = analyzer.analyze(findEnum(library, 'MessageType'));
      expect(result!.schema, equals('messages.messageType'));
      expect(result.cases.map((c) => c.name), containsAll(['text', 'image']));
    });

    test('schema defaults to null', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @EnumSpec(
          identifier: 'com.example.MessageType',
          title: 'Message Type',
        )
        enum MessageType {
          text,
        }
      ''');

      final result = analyzer.analyze(findEnum(library, 'MessageType'));
      expect(result!.schema, isNull);
    });
  });
}
