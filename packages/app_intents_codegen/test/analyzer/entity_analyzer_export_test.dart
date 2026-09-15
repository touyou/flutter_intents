import 'package:app_intents_codegen/src/analyzer/entity_analyzer.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

/// Wraps [body] in a spec class carrying the given `exportAs` argument.
String _source(String exportAs, String body) =>
    '''
      import 'package:app_intents_annotations/app_intents_annotations.dart';

      @EntitySpec(
        identifier: 'com.example.place',
        title: 'Place',
        pluralTitle: 'Places',
        $exportAs
      )
      class PlaceEntity extends EntitySpecBase {
        @EntityId()
        final String id = '';
        @EntityTitle()
        final String name = '';
        $body
      }
    ''';

void main() {
  group('EntityAnalyzer (#128 structured export catalog)', () {
    late EntityAnalyzer analyzer;

    setUp(() {
      analyzer = EntityAnalyzer();
    });

    test('parses exportAs: place with coordinate export fields', () async {
      final library = await resolveSource(
        _source('exportAs: EntityExportType.place,', '''
          @EntityExportField(EntityExportRole.latitude)
          final double? lat = null;
          @EntityExportField(EntityExportRole.longitude)
          final double? lng = null;
        '''),
      );

      final result = analyzer.analyze(findClass(library, 'PlaceEntity'))!;
      expect(result.exportAs, equals(EntityExportKind.place));
      expect(
        result.exportField(EntityExportRoleKind.latitude)?.fieldName,
        equals('lat'),
      );
      expect(
        result.exportField(EntityExportRoleKind.longitude)?.fieldName,
        equals('lng'),
      );
      // An export field is kept as a property even though it carries no display
      // role — the generated entity has to store it to export it.
      expect(result.properties.length, equals(4));
    });

    test('an address alone is enough for a place export', () async {
      final library = await resolveSource(
        _source('exportAs: EntityExportType.place,', '''
          @EntityExportField(EntityExportRole.address)
          final String address = '';
        '''),
      );

      final result = analyzer.analyze(findClass(library, 'PlaceEntity'))!;
      expect(result.exportAs, equals(EntityExportKind.place));
    });

    test('a place export with no location fields is an error', () async {
      final library = await resolveSource(
        _source('exportAs: EntityExportType.place,', ''),
      );

      expect(
        () => analyzer.analyze(findClass(library, 'PlaceEntity')),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('no location fields'),
          ),
        ),
      );
    });

    test('half a coordinate is an error', () async {
      final library = await resolveSource(
        _source('exportAs: EntityExportType.place,', '''
          @EntityExportField(EntityExportRole.latitude)
          final double? lat = null;
        '''),
      );

      expect(
        () => analyzer.analyze(findClass(library, 'PlaceEntity')),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('needs both'),
          ),
        ),
      );
    });

    test('a non-numeric latitude is an error', () async {
      final library = await resolveSource(
        _source('exportAs: EntityExportType.place,', '''
          @EntityExportField(EntityExportRole.latitude)
          final String lat = '';
          @EntityExportField(EntityExportRole.longitude)
          final double lng = 0;
        '''),
      );

      expect(
        () => analyzer.analyze(findClass(library, 'PlaceEntity')),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('must be double/int'),
          ),
        ),
      );
    });

    test('importable without exportAs is an error (#129)', () async {
      final library = await resolveSource(_source('importable: true,', ''));

      expect(
        () => analyzer.analyze(findClass(library, 'PlaceEntity')),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('has no exportAs'),
          ),
        ),
      );
    });

    test('importable is parsed alongside exportAs (#129)', () async {
      final library = await resolveSource(
        _source('exportAs: EntityExportType.person, importable: true,', ''),
      );

      final result = analyzer.analyze(findClass(library, 'PlaceEntity'))!;
      expect(result.importable, isTrue);
    });

    test('parses @EntityStableId alongside syncable (#132)', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @EntitySpec(
          identifier: 'com.example.device',
          title: 'Device',
          pluralTitle: 'Devices',
          syncable: true,
        )
        class DeviceEntity extends EntitySpecBase {
          @EntityId()
          final String localId = '';
          @EntityTitle()
          final String name = '';
          @EntityStableId()
          final String serverId = '';
        }
      ''');

      final result = analyzer.analyze(findClass(library, 'DeviceEntity'))!;
      expect(result.usesDualIdentifier, isTrue);
      expect(result.stableIdProperty?.fieldName, equals('serverId'));
    });

    test('@EntityStableId without syncable is an error (#132)', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @EntitySpec(
          identifier: 'com.example.device',
          title: 'Device',
          pluralTitle: 'Devices',
        )
        class DeviceEntity extends EntitySpecBase {
          @EntityId()
          final String localId = '';
          @EntityTitle()
          final String name = '';
          @EntityStableId()
          final String serverId = '';
        }
      ''');

      expect(
        () => analyzer.analyze(findClass(library, 'DeviceEntity')),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('has no effect without'),
          ),
        ),
      );
    });

    test('a nullable stable id is an error (#132)', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @EntitySpec(
          identifier: 'com.example.device',
          title: 'Device',
          pluralTitle: 'Devices',
          syncable: true,
        )
        class DeviceEntity extends EntitySpecBase {
          @EntityId()
          final String localId = '';
          @EntityTitle()
          final String name = '';
          @EntityStableId()
          final String? serverId = null;
        }
      ''');

      expect(
        () => analyzer.analyze(findClass(library, 'DeviceEntity')),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('must be a non-nullable String'),
          ),
        ),
      );
    });

    test('an export field without exportAs is an error', () async {
      final library = await resolveSource(
        _source('', '''
          @EntityExportField(EntityExportRole.latitude)
          final double? lat = null;
        '''),
      );

      expect(
        () => analyzer.analyze(findClass(library, 'PlaceEntity')),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            contains('no @EntitySpec(exportAs:)'),
          ),
        ),
      );
    });
  });
}
