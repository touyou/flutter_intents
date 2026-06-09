import 'package:app_intents_codegen/src/analyzer/union_analyzer.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('UnionAnalyzer (#53 UnionValue)', () {
    late UnionAnalyzer analyzer;

    setUp(() {
      analyzer = UnionAnalyzer();
    });

    test('extracts cases from @UnionCase subclasses', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @UnionValueSpec(identifier: 'com.example.GalleryContent', title: 'Gallery')
        sealed class GalleryContent {
          const GalleryContent();
        }

        @UnionCase(entityType: 'PhotoEntity')
        class PhotoContent extends GalleryContent {
          final String id;
          const PhotoContent(this.id);
        }

        @UnionCase(entityType: 'AlbumEntity')
        class AlbumContent extends GalleryContent {
          final String id;
          const AlbumContent(this.id);
        }
      ''');

      final result = analyzer.analyze(findClass(library, 'GalleryContent'));

      expect(result, isNotNull);
      expect(result!.className, equals('GalleryContent'));
      expect(result.identifier, equals('com.example.GalleryContent'));
      expect(result.title, equals('Gallery'));
      expect(result.cases, hasLength(2));

      final photo = result.cases.firstWhere(
        (c) => c.dartClassName == 'PhotoContent',
      );
      expect(photo.entityType, equals('PhotoEntity'));
      expect(photo.swiftCaseName, equals('photoContent'));

      final album = result.cases.firstWhere(
        (c) => c.dartClassName == 'AlbumContent',
      );
      expect(album.entityType, equals('AlbumEntity'));
    });

    test('returns null for a non-annotated class', () async {
      final library = await resolveSource('''
        class Plain {}
      ''');
      expect(analyzer.analyze(findClass(library, 'Plain')), isNull);
    });

    test('throws when no @UnionCase subclasses exist', () async {
      final library = await resolveSource('''
        import 'package:app_intents_annotations/app_intents_annotations.dart';

        @UnionValueSpec(identifier: 'com.example.Empty')
        sealed class Empty {
          const Empty();
        }
      ''');
      expect(
        () => analyzer.analyze(findClass(library, 'Empty')),
        throwsA(isA<Object>()),
      );
    });
  });
}
