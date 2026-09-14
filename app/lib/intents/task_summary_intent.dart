import 'package:app_intents/app_intents.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';

import '../repositories/task_repository.dart';

part 'task_summary_intent.intent.dart';

/// Asks for a count of outstanding tasks, answered with a Siri snippet card.
///
/// Unlike the other example intents this one has no `urlScheme` and no
/// foreground mode, so it runs through FlutterBridge and `perform()` gets the
/// handler's return value back. That is what lets the snippet interpolate
/// `{result.…}`; a URL scheme intent hands off to the app and returns before
/// the handler has produced anything.
@IntentSpec(
  identifier: 'com.example.taskapp.taskSummary',
  title: 'Task Summary',
  description: 'Summarize how many tasks are left',
  resultDialogTemplate: 'You have {result.openCount} tasks left',
  resultDialogSupportingTemplate: '{result.openCount} left',
  snippet: SnippetTemplate(
    title: '{result.headline}',
    subtitle: 'Updated just now',
    systemImageName: 'checklist',
    rows: [
      SnippetRow(label: 'Open', value: '{result.openCount}'),
      SnippetRow(label: 'Done', value: '{result.completedCount}'),
    ],
  ),
)
class TaskSummaryIntentSpec extends IntentSpecBase {
  TaskSummaryIntentSpec();
}

/// Handler for the TaskSummary intent.
///
/// The returned map is what the snippet's `{result.…}` placeholders read, so
/// its keys are part of the intent's contract.
Future<Map<String, dynamic>> taskSummaryIntentHandler() async {
  final tasks = TaskRepository.instance.getAllTasks();
  final open = tasks.where((task) => !task.isCompleted).length;
  return <String, dynamic>{
    'openCount': open,
    'completedCount': tasks.length - open,
    'headline': open == 0 ? 'All caught up' : '$open tasks to go',
  };
}
