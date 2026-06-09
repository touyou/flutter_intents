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
  className: 'AuthorIntent',
  identifier: 'com.example.author',
  title: 'Set Author',
  implementation: IntentImplementationType.dart,
  urlScheme: urlScheme,
  parameters: parameters,
);

const _personName = IntentParamInfo(
  fieldName: 'author',
  dartType: 'PersonName',
  title: 'Author',
  isOptional: false,
);

void main() {
  group('SwiftGenerator (#53 PersonName parameters)', () {
    group('default / fallback (rich-types OFF)', () {
      test('emits a String parameter in a single struct, no #if', () {
        final result = const SwiftGenerator().generateAll(
          intents: [_intent(parameters: [_personName])],
        );

        expect(result, isNot(contains('#if APP_INTENTS_WWDC26')));
        expect(result, contains('var author: String'));
        expect(result, isNot(contains('PersonNameComponents')));
        // String fallback carries only givenName.
        expect(
          result,
          contains('let authorName: [String: String] = ["givenName": author]'),
        );
        expect(result, contains('"author": authorName'));
      });
    });

    group('rich-types ON (dual-branch)', () {
      test('native PersonNameComponents in #if, String fallback in #else', () {
        final result = _experimentalGenerator().generateAll(
          intents: [_intent(parameters: [_personName])],
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

        // #if: native PersonNameComponents at iOS 27, reads every component.
        expect(ifBranch, contains('@available(iOS 27.0, *)'));
        expect(ifBranch, contains('var author: PersonNameComponents'));
        expect(ifBranch, contains('var authorName: [String: String] = [:]'));
        expect(
          ifBranch,
          contains('if let v = author.givenName { authorName["givenName"] = v }'),
        );
        expect(
          ifBranch,
          contains('if let v = author.nickname { authorName["nickname"] = v }'),
        );

        // #else: String fallback at iOS 17.
        expect(elseBranch, contains('@available(iOS 17.0, *)'));
        expect(elseBranch, contains('var author: String'));
        expect(
          elseBranch,
          contains(
            'let authorName: [String: String] = ["givenName": author]',
          ),
        );

        // Both branches feed the same branch-agnostic Dart wire value.
        expect(ifBranch, contains('"author": authorName'));
        expect(elseBranch, contains('"author": authorName'));
      });

      test('nullable PersonName unwraps before building the component map', () {
        const nullable = IntentParamInfo(
          fieldName: 'editor',
          dartType: 'PersonName?',
          title: 'Editor',
          isOptional: true,
        );
        final result = _experimentalGenerator().generateAll(
          intents: [_intent(parameters: [nullable])],
        );
        final ifBranch = result.substring(
          result.indexOf('#if'),
          result.indexOf('#else'),
        );

        expect(ifBranch, contains('var editor: PersonNameComponents?'));
        expect(ifBranch, contains('var editorName: [String: String]? = nil'));
        expect(ifBranch, contains('if let editor {'));
      });
    });

    group('url scheme (degraded — given name only)', () {
      test('carries the given name as a single query value', () {
        final result = const SwiftGenerator().generateAll(
          intents: [
            _intent(urlScheme: 'authorapp', parameters: [_personName]),
          ],
        );

        expect(
          result,
          contains('if let authorGiven = authorName["givenName"] {'),
        );
        expect(
          result,
          contains(
            'queryItems.append(URLQueryItem(name: "author", value: authorGiven))',
          ),
        );
      });
    });
  });
}
