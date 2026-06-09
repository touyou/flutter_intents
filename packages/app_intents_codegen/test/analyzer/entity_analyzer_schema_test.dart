import 'package:app_intents_codegen/src/analyzer/entity_analyzer.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('EntityAnalyzer (WWDC26 #49 schema / #50 @EntityProperty)', () {
    late EntityAnalyzer analyzer;

    setUp(() {
      analyzer = EntityAnalyzer();
    });

    test('parses schema field', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @EntitySpec(
          identifier: 'com.example.message',
          title: 'Message',
          pluralTitle: 'Messages',
          schema: 'messages.message',
        )
        class MessageEntity extends EntitySpecBase {
          @EntityId()
          final String id = '';
          @EntityTitle()
          final String title = '';
        }
      ''');

      final result = analyzer.analyze(findClass(library, 'MessageEntity'));
      expect(result!.schema, equals('messages.message'));
    });

    test('schema defaults to null', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @EntitySpec(
          identifier: 'com.example.message',
          title: 'Message',
          pluralTitle: 'Messages',
        )
        class MessageEntity extends EntitySpecBase {
          @EntityId()
          final String id = '';
          @EntityTitle()
          final String title = '';
        }
      ''');

      final result = analyzer.analyze(findClass(library, 'MessageEntity'));
      expect(result!.schema, isNull);
    });

    test('parses @EntityProperty with title and indexingKey', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @EntitySpec(
          identifier: 'com.example.note',
          title: 'Note',
          pluralTitle: 'Notes',
        )
        class NoteEntity extends EntitySpecBase {
          @EntityId()
          final String id = '';
          @EntityTitle()
          final String title = '';
          @EntityProperty(title: 'Body', indexingKey: 'contentDescription')
          final String body = '';
        }
      ''');

      final result = analyzer.analyze(findClass(library, 'NoteEntity'));
      final bodyProp = result!.properties.firstWhere(
        (p) => p.fieldName == 'body',
      );

      expect(bodyProp.exposeAsProperty, isTrue);
      expect(bodyProp.propertyTitle, equals('Body'));
      expect(bodyProp.indexingKey, equals('contentDescription'));
      expect(result.hasExposedProperties, isTrue);
      expect(result.hasIndexingKeys, isTrue);
    });
  });
}
