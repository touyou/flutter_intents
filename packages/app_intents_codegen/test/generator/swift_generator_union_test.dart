import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:app_intents_codegen/src/models/union_info.dart';
import 'package:test/test.dart';

SwiftGenerator _experimentalGenerator() => const SwiftGenerator(
  experimental: ExperimentalFeatures(masterEnabled: true),
);

const _union = UnionInfo(
  className: 'GalleryContent',
  identifier: 'com.example.GalleryContent',
  cases: [
    UnionCaseInfo(dartClassName: 'PhotoContent', entityType: 'PhotoEntity'),
    UnionCaseInfo(dartClassName: 'AlbumContent', entityType: 'AlbumEntity'),
  ],
);

IntentInfo _intent({String? urlScheme}) => IntentInfo(
  className: 'OpenGalleryIntent',
  identifier: 'com.example.openGallery',
  title: 'Open Gallery',
  implementation: IntentImplementationType.dart,
  urlScheme: urlScheme,
  parameters: const [
    IntentParamInfo(
      fieldName: 'content',
      dartType: 'GalleryContent',
      title: 'Content',
      isOptional: false,
      unionInfo: _union,
    ),
  ],
);

void main() {
  group('SwiftGenerator (#53 UnionValue)', () {
    group('default / fallback (rich-types OFF)', () {
      test('degrades to the first case entity, no union enum, no #if', () {
        final result = const SwiftGenerator().generateAll(intents: [_intent()]);

        expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
        expect(result, isNot(contains('@UnionValue')));
        // Param degrades to the first case's entity type.
        expect(result, contains('var content: PhotoEntity'));
        expect(
          result,
          contains(
            'let contentUnion: [String: String] = '
            '["_type": "PhotoContent", "id": content.id]',
          ),
        );
        expect(result, contains('"content": contentUnion'));
      });
    });

    group('rich-types ON', () {
      test('emits a @UnionValue enum in its own #if block', () {
        final result = _experimentalGenerator().generateAll(
          intents: [_intent()],
        );

        expect(result, contains('@UnionValue'));
        expect(result, contains('enum GalleryContent {'));
        expect(result, contains('case photoContent(PhotoEntity)'));
        expect(result, contains('case albumContent(AlbumEntity)'));
        // Enum is iOS 27 and #if-gated (no #else for the type itself).
        expect(result, contains('@available(iOS 27.0, *)'));
      });

      test('intent param dual-branches over the union with a switch', () {
        final result = _experimentalGenerator().generateAll(
          intents: [_intent()],
        );

        final ifIdx = result.indexOf('struct OpenGalleryIntent');
        final body = result.substring(ifIdx);
        final ifBranch = body.substring(0, body.indexOf('#else'));
        final elseBranch = body.substring(
          body.indexOf('#else'),
          body.indexOf('#endif'),
        );

        // #if: native union param + switch serialization.
        expect(ifBranch, contains('var content: GalleryContent'));
        expect(
          ifBranch,
          contains(
            'case .photoContent(let e): '
            'contentUnion = ["_type": "PhotoContent", "id": e.id]',
          ),
        );

        // #else: lossy fallback to the first case entity.
        expect(elseBranch, contains('var content: PhotoEntity'));
        expect(
          elseBranch,
          contains('["_type": "PhotoContent", "id": content.id]'),
        );
      });
    });

    group('url scheme', () {
      test('encodes the union as <_type>|<id>', () {
        final result = const SwiftGenerator().generateAll(
          intents: [_intent(urlScheme: 'galleryapp')],
        );
        expect(
          result,
          contains(
            'value: (contentUnion["_type"] ?? "") + "|" + (contentUnion["id"] ?? ""))',
          ),
        );
      });
    });
  });
}
