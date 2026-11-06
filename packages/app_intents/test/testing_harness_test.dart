import 'package:app_intents/app_intents.dart';
import 'package:app_intents/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifestJson = '''
{
  "formatVersion": 1,
  "intents": [
    {
      "identifier": "test.create",
      "className": "CreateSpec",
      "title": "Create",
      "parameters": {
        "type": "object",
        "properties": {
          "title": {"type": "string"},
          "due": {"anyOf": [{"type": "string", "format": "date-time"}, {"type": "null"}]},
          "priority": {"type": "string", "enum": ["low", "high"]}
        },
        "required": ["title"],
        "additionalProperties": false
      }
    },
    {
      "identifier": "test.declaredOnly",
      "className": "DeclaredOnlySpec",
      "title": "Declared only",
      "parameters": {"type": "object", "properties": {}, "required": []}
    }
  ],
  "entities": [
    {
      "identifier": "test.Task",
      "className": "TaskSpec",
      "title": "Task",
      "schema": {
        "type": "object",
        "properties": {"id": {"type": "string"}, "title": {"type": "string"}},
        "required": ["id", "title"]
      }
    }
  ],
  "enums": []
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppIntentsHarness harness;

  setUp(() {
    harness = AppIntentsHarness(
      manifest: AppIntentsManifest.parse(_manifestJson),
    );
  });

  tearDown(() => harness.dispose());

  test('installs itself as the platform and restores the previous one', () {
    final previous = AppIntentsPlatform.instance;
    final nested = AppIntentsHarness();
    expect(AppIntentsPlatform.instance, isNot(same(previous)));
    nested.dispose();
    expect(AppIntentsPlatform.instance, same(previous));
  });

  group('list', () {
    test('reports registered handlers and declared intents without one', () {
      AppIntents().registerIntentHandler('test.create', (_) async => {});
      AppIntents().registerIntentHandler('test.typo', (_) async => {});
      AppIntents().registerEntityQueryHandler('test.Task', (_) async => []);

      final inventory = harness.list();

      expect(inventory.intents, {'test.create', 'test.typo'});
      expect(inventory.entityQueries, {'test.Task'});
      expect(inventory.unhandledIntents, {'test.declaredOnly'});
      expect(inventory.undeclaredIntents, {'test.typo'});
      expect(inventory.unhandledEntities, isEmpty);
    });

    test('has no declaration diff without a manifest', () {
      final bare = AppIntentsHarness();
      addTearDown(bare.dispose);
      AppIntents().registerIntentHandler('x', (_) async => {});
      expect(bare.list().intents, {'x'});
      expect(bare.list().unhandledIntents, isEmpty);
      expect(bare.list().undeclaredIntents, isEmpty);
    });
  });

  group('run', () {
    test('passes params and returns the result over the channel', () async {
      Map<String, dynamic>? received;
      AppIntents().registerIntentHandler('test.create', (params) async {
        received = params;
        return {'id': '1', 'title': params['title']};
      });

      final result = await harness.run('test.create', {
        'title': 'Milk',
        'due': '2026-11-07T09:00:00.000Z',
      });

      expect(result, {'id': '1', 'title': 'Milk'});
      // The reserved execution id is stripped, as on a device.
      expect(received, {'title': 'Milk', 'due': '2026-11-07T09:00:00.000Z'});
    });

    test('opens an execution scope', () async {
      String? executionId;
      AppIntents().registerIntentHandler('test.create', (_) async {
        executionId = AppIntentExecution.current?.executionId;
        return {};
      });

      await harness.run('test.create', {'title': 'a'});

      expect(executionId, startsWith('harness-'));
    });

    test('keeps the AppIntentError code', () async {
      AppIntents().registerIntentHandler('test.create', (_) async {
        throw AppIntentError.fromCode(
          AppIntentErrorCode.notFound,
          message: 'gone',
        );
      });

      await expectLater(
        harness.run('test.create', {'title': 'a'}),
        throwsA(
          isA<AppIntentError>()
              .having((e) => e.code, 'code', 'notFound')
              .having((e) => e.message, 'message', 'gone'),
        ),
      );
    });

    test('fails at once with handlerNotFound for a missing handler', () async {
      await expectLater(
        harness.run('test.declaredOnly'),
        throwsA(
          isA<AppIntentError>().having(
            (e) => e.code,
            'code',
            'handlerNotFound',
          ),
        ),
      );
    });

    test(
      'reports a result the codec cannot carry, as a device would',
      () async {
        AppIntents().registerIntentHandler('test.create', (_) async {
          return {'when': DateTime(2026)};
        });

        await expectLater(
          harness.run('test.create', {'title': 'a'}),
          throwsA(isA<AppIntentError>().having((e) => e.code, 'code', 'error')),
        );
      },
    );

    test('rejects params that do not match the declared schema', () async {
      var called = false;
      AppIntents().registerIntentHandler('test.create', (_) async {
        called = true;
        return {};
      });

      await expectLater(
        harness.run('test.create', {
          'priority': 'urgent',
          'due': 'tomorrow',
          'extra': 1,
        }),
        throwsA(
          isA<AppIntentsSchemaViolation>().having(
            (e) => e.errors,
            'errors',
            containsAll([
              contains('missing required "title"'),
              contains(r'$.priority'),
              contains(r'$.due'),
              contains('unexpected key "extra"'),
            ]),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('sends malformed params when validation is off', () async {
      final lax = AppIntentsHarness(
        manifest: AppIntentsManifest.parse(_manifestJson),
        validateParams: false,
      );
      addTearDown(lax.dispose);
      AppIntents().registerIntentHandler('test.create', (p) async => p);

      expect(await lax.run('test.create', {'extra': 1}), {'extra': 1});
    });

    test('records progress and delivers cancellation', () async {
      AppIntents().registerIntentHandler('test.create', (_) async {
        final execution = AppIntentExecution.current!;
        await execution.reportProgress(0.5);
        final reason = await execution.cancelled;
        return {'reason': reason.reason};
      });

      final run = harness.start('test.create', {'title': 'a'});
      await pumpEventQueue();
      expect(run.progress.single.fraction, 0.5);
      await run.cancel(reason: 'timeout');

      expect(await run.result, {'reason': 'timeout'});
    });

    test('answers requestValue through onRequestValue', () async {
      final asking = AppIntentsHarness(
        onRequestValue: (_, parameter) => 'value for $parameter',
      );
      addTearDown(asking.dispose);
      AppIntents().registerIntentHandler('ask', (_) async {
        final value = await AppIntentExecution.current!.requestValue('note');
        return {'note': value};
      });

      expect(await asking.run('ask'), {'note': 'value for note'});
    });
  });

  group('entities', () {
    test('queryEntities and suggestedEntities reach the handlers', () async {
      AppIntents().registerEntityQueryHandler(
        'test.Task',
        (ids) async => [
          for (final id in ids) {'id': id, 'title': 'Task $id'},
        ],
      );
      AppIntents().registerSuggestedEntitiesHandler(
        'test.Task',
        () async => [
          {'id': 's', 'title': 'Suggested'},
        ],
      );

      expect(await harness.queryEntities('test.Task', ['a']), [
        {'id': 'a', 'title': 'Task a'},
      ]);
      expect(await harness.suggestedEntities('test.Task'), [
        {'id': 's', 'title': 'Suggested'},
      ]);
    });

    test('reports an entity map the Swift query would drop', () async {
      AppIntents().registerSuggestedEntitiesHandler(
        'test.Task',
        () async => [
          {'id': 's', 'name': 'wrong key'},
        ],
      );

      await expectLater(
        harness.suggestedEntities('test.Task'),
        throwsA(
          isA<AppIntentsSchemaViolation>().having(
            (e) => e.errors.single,
            'error',
            contains('missing required "title"'),
          ),
        ),
      );
    });
  });

  test(
    'runs without an execution scope, like an ordinary iOS intent',
    () async {
      AppIntents().registerIntentHandler('plain', (_) async {
        return {'scoped': AppIntentExecution.current != null};
      });

      expect(await harness.run('plain', {}, false), {'scoped': false});
    },
  );

  test('outgoing values go through the codec', () async {
    await expectLater(
      AppIntents().setCachedValue('k', DateTime(2026)),
      throwsArgumentError,
    );
  });

  test('a disposed harness hands the channel back', () async {
    final inner = AppIntentsHarness();
    AppIntents().registerIntentHandler('inner', (_) async => {});
    inner.dispose();
    AppIntents().registerIntentHandler('outer', (_) async => {'ok': true});

    expect(await harness.run('outer'), {'ok': true});
  });

  test('keeps cache writes and donations in memory', () async {
    await AppIntents().setCachedValue('k', 'v');
    expect(harness.cache, {'k': 'v'});
    expect(await AppIntents().getCachedValue('k'), 'v');

    await AppIntents().donateIntent('test.create', {'title': 'a'});
    expect(harness.nativeCalls.single.method, 'donateIntent');
  });

  test('rejects a manifest from an unknown format version', () {
    expect(
      () => AppIntentsManifest.parse('{"formatVersion": 99}'),
      throwsFormatException,
    );
  });
}
