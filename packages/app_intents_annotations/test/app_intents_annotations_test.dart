import 'package:app_intents_annotations/app_intents_annotations.dart';
import 'package:test/test.dart';

void main() {
  group('IntentSpecBase', () {
    test('can be extended with specific input and output types', () {
      final intentSpec = MyIntentSpec();
      expect(intentSpec, isA<IntentSpecBase<String, int>>());
    });
  });
}

class MyIntentSpec extends IntentSpecBase<String, int> {
  const MyIntentSpec();
}
