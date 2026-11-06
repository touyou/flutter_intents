import 'dart:io';

import 'package:app/entities/task_entity.dart';
import 'package:app/intents/complete_task_intent.dart';
import 'package:app/intents/create_task_intent.dart';
import 'package:app/intents/create_task_with_image_intent.dart';
import 'package:app/intents/task_summary_intent.dart';
import 'package:app/repositories/task_repository.dart';
import 'package:app_intents/app_intents.dart';
import 'package:app_intents/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// One behaviour test per intent stands for both platforms: Siri and the
/// Android AppFunctions bridge both end in these Dart handlers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppIntentsHarness harness;

  setUp(() async {
    harness = AppIntentsHarness(
      // Regenerate with `make describe` after changing a spec.
      manifest: AppIntentsManifest.parse(
        File('test/app_intents.json').readAsStringSync(),
      ),
    );
    await TaskRepository.instance.clear();
    initializeCreateTaskAppIntents();
    initializeCompleteTaskAppIntents();
    initializeCreateTaskWithImageAppIntents();
    initializeTaskSummaryAppIntents();
    initializeTaskAppIntents();
  });

  tearDown(() => harness.dispose());

  test('every declared intent and entity has a handler', () {
    final inventory = harness.list();
    expect(inventory.unhandledIntents, isEmpty);
    expect(inventory.unhandledEntities, isEmpty);
    expect(inventory.undeclaredIntents, isEmpty);
  });

  test('createTask adds a task the entity query can find', () async {
    await harness.run('com.example.taskapp.createTask', {
      'title': 'Buy milk',
      'dueDate': '2026-11-07T09:00:00.000Z',
    });

    final suggested = await harness.suggestedEntities(
      'com.example.taskapp.TaskEntity',
    );
    expect(suggested.single['title'], 'Buy milk');
  });

  test('completeTask reports an unknown task as notFound', () async {
    await expectLater(
      harness.run('com.example.taskapp.completeTask', {'task': 'missing'}),
      throwsA(
        isA<AppIntentError>().having((e) => e.code, 'code', 'notFound'),
      ),
    );
  });

  test('taskSummary returns the counts its dialog reads', () async {
    await harness.run('com.example.taskapp.createTask', {'title': 'a'});

    final summary = await harness.run('com.example.taskapp.taskSummary');

    expect(summary, containsPair('openCount', 1));
    expect(summary, containsPair('completedCount', 0));
  });
}
