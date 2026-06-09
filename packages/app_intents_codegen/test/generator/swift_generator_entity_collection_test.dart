import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

SwiftGenerator _experimentalGenerator() =>
    const SwiftGenerator(experimental: ExperimentalFeatures(masterEnabled: true));

IntentInfo _intent({
  List<IntentParamInfo> parameters = const [],
  String? urlScheme,
}) => IntentInfo(
  className: 'TagPhotosIntent',
  identifier: 'com.example.tagPhotos',
  title: 'Tag Photos',
  implementation: IntentImplementationType.dart,
  urlScheme: urlScheme,
  parameters: parameters,
);

const _collection = IntentParamInfo(
  fieldName: 'photos',
  dartType: 'List<String>',
  title: 'Photos',
  isOptional: false,
  entityCollectionType: 'PhotoEntity',
);

void main() {
  group('SwiftGenerator (#53 EntityCollection parameters)', () {
    group('default / fallback (rich-types OFF)', () {
      test('emits a [Entity] array in a single struct, no #if', () {
        final result = const SwiftGenerator().generateAll(
          intents: [_intent(parameters: [_collection])],
        );

        expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
        expect(result, contains('var photos: [PhotoEntity]'));
        expect(result, isNot(contains('EntityCollection<')));
        expect(
          result,
          contains(r'let photosIds: [String] = photos.map { $0.id }'),
        );
        expect(result, contains('"photos": photosIds'));
      });
    });

    group('rich-types ON (dual-branch)', () {
      test('native EntityCollection in #if, [Entity] array in #else', () {
        final result = _experimentalGenerator().generateAll(
          intents: [_intent(parameters: [_collection])],
        );

        expect(result, contains('#if APP_INTENTS_WWDC26'));
        final ifBranch = result.substring(
          result.indexOf('#if'),
          result.indexOf('#else'),
        );
        final elseBranch = result.substring(
          result.indexOf('#else'),
          result.indexOf('#endif'),
        );

        // #if: native EntityCollection at iOS 27, reads .identifiers.
        expect(ifBranch, contains('@available(iOS 27.0, *)'));
        expect(ifBranch, contains('var photos: EntityCollection<PhotoEntity>'));
        expect(
          ifBranch,
          contains('let photosIds: [String] = photos.identifiers'),
        );

        // #else: [Entity] array at iOS 17, maps .id.
        expect(elseBranch, contains('@available(iOS 17.0, *)'));
        expect(elseBranch, contains('var photos: [PhotoEntity]'));
        expect(
          elseBranch,
          contains(r'let photosIds: [String] = photos.map { $0.id }'),
        );

        // Both branches feed the same branch-agnostic Dart wire value.
        expect(ifBranch, contains('"photos": photosIds'));
        expect(elseBranch, contains('"photos": photosIds'));
      });

      test('nullable collection uses optional chaining', () {
        const nullable = IntentParamInfo(
          fieldName: 'photos',
          dartType: 'List<String>?',
          title: 'Photos',
          isOptional: true,
          entityCollectionType: 'PhotoEntity',
        );
        final result = _experimentalGenerator().generateAll(
          intents: [_intent(parameters: [nullable])],
        );
        final ifBranch = result.substring(
          result.indexOf('#if'),
          result.indexOf('#else'),
        );
        expect(
          ifBranch,
          contains('var photos: EntityCollection<PhotoEntity>?'),
        );
        expect(
          ifBranch,
          contains('let photosIds: [String]? = photos?.identifiers'),
        );
      });
    });

    group('url scheme', () {
      test('comma-joins the identifiers', () {
        final result = const SwiftGenerator().generateAll(
          intents: [
            _intent(urlScheme: 'photoapp', parameters: [_collection]),
          ],
        );
        expect(
          result,
          contains(
            'queryItems.append(URLQueryItem(name: "photos", value: photosIds.joined(separator: ",")))',
          ),
        );
      });
    });
  });
}
