import 'package:app_intents/app_intents.dart';
import 'package:flutter_test/flutter_test.dart';

class _Task {
  const _Task(this.id, this.title);

  final String id;
  final String title;

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}

class _NotJson {
  const _NotJson();
}

class _BadJson {
  const _BadJson();

  String toJson() => 'nope';
}

void main() {
  group('intentResultPayload', () {
    test('null becomes an empty map', () {
      expect(intentResultPayload(null), isEmpty);
    });

    test('a map passes through with string keys', () {
      expect(intentResultPayload({'a': 1, 2: 'b'}), {'a': 1, '2': 'b'});
    });

    test('a value with toJson() is converted', () {
      expect(intentResultPayload(const _Task('1', 'Buy milk')), {
        'id': '1',
        'title': 'Buy milk',
      });
    });

    test('a value with no toJson() throws rather than rendering empty', () {
      // A snippet that silently renders blank is close to undiagnosable from
      // the Siri surface it appears on, so this must be loud.
      expect(
        () => intentResultPayload(const _NotJson()),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('toJson()'),
          ),
        ),
      );
    });

    test('a toJson() that does not return a map throws', () {
      expect(
        () => intentResultPayload(const _BadJson()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
