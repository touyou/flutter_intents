import 'package:app_intents_codegen/app_intents_codegen.dart';
import 'package:test/test.dart';

void main() {
  group('app_intents_codegen', () {
    test('exports IntentAnalyzer', () {
      expect(IntentAnalyzer, isNotNull);
    });

    test('exports EntityAnalyzer', () {
      expect(EntityAnalyzer, isNotNull);
    });

    test('exports IntentInfo', () {
      expect(IntentInfo, isNotNull);
    });

    test('exports EntityInfo', () {
      expect(EntityInfo, isNotNull);
    });
  });
}
