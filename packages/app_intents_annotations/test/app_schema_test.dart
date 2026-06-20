import 'package:app_intents_annotations/app_intents_annotations.dart';
import 'package:test/test.dart';

void main() {
  group('AppSchemaDomain', () {
    test('keyword round-trips via fromKeyword', () {
      for (final domain in AppSchemaDomain.values) {
        expect(AppSchemaDomain.fromKeyword(domain.keyword), domain);
      }
    });

    test('fromKeyword returns null for an unknown domain', () {
      expect(AppSchemaDomain.fromKeyword('not-a-domain'), isNull);
    });

    test('includes the documented iOS 27 domains', () {
      final keywords = AppSchemaDomain.values.map((d) => d.keyword).toSet();
      expect(
        keywords,
        containsAll([
          'messages',
          'mail',
          'photos',
          'calendar',
          'maps',
          'visualIntelligence',
          'imageGeneration',
          'wordProcessor',
        ]),
      );
    });
  });

  group('AppSchemas', () {
    test('exposes dotted identifiers for verified schemas', () {
      expect(AppSchemas.messages.message, 'messages.message');
      expect(AppSchemas.messages.sendMessage, 'messages.sendMessage');
      expect(AppSchemas.messages.messageType, 'messages.messageType');
      expect(AppSchemas.mail.openMessage, 'mail.openMessage');
      expect(AppSchemas.photos.asset, 'photos.asset');
      expect(AppSchemas.photos.assetType, 'photos.assetType');
      expect(AppSchemas.system.searchInApp, 'system.searchInApp');
      expect(AppSchemas.system.open, 'system.open');
    });

    test('system.searchInApp is the iOS 27 rename of system.search', () {
      // iOS 17 used `.system.search`; iOS 27 renamed it to `.system.searchInApp`.
      // Both are valid raw schema strings, so the iOS-17 fallback is reachable
      // via [AppSchemas.of] without polluting the typed catalog.
      expect(AppSchemas.of(AppSchemaDomain.system, 'search'), 'system.search');
      expect(AppSchemas.system.searchInApp, isNot('system.search'));
    });

    test('of() builds a dotted identifier for any domain/schema', () {
      expect(
        AppSchemas.of(AppSchemaDomain.calendar, 'event'),
        'calendar.event',
      );
      expect(
        AppSchemas.of(AppSchemaDomain.wordProcessor, 'document'),
        'wordProcessor.document',
      );
    });

    test('catalog values are usable as @EntitySpec(schema:)', () {
      const spec = EntitySpec(
        identifier: 'com.example.MessageEntity',
        title: 'Message',
        pluralTitle: 'Messages',
        schema: 'messages.message',
      );
      expect(spec.schema, AppSchemas.messages.message);
    });
  });
}
