import 'package:app_intents/app_intents.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';

part 'complete_task_intent.intent.dart';

/// Intent specification for marking a task as complete.
@IntentSpec(
  identifier: 'com.example.taskapp.completeTask',
  title: 'Complete Task',
  description: 'Mark a task as completed',
  urlScheme: 'taskapp',
  urlAction: 'complete',
  // Siri speaks the full line; when it also shows the result it puts the
  // shorter supporting line next to it (ADR 0005).
  resultDialogTemplate: 'I marked that task as completed',
  resultDialogSupportingTemplate: 'Completed',
  resultDialogSystemImageName: 'checkmark.circle',
  parameterSummary: 'Complete {task}',
)
class CompleteTaskIntentSpec extends IntentSpecBase {
  @IntentParam(
    title: 'Task',
    description: 'The task to complete',
    entityType: 'TaskEntitySpec',
  )
  final String task;

  CompleteTaskIntentSpec({required this.task});
}

/// Handler for the CompleteTask intent.
Future<Task?> completeTaskIntentHandler({required String task}) async {
  return TaskRepository.instance.toggleTaskCompletion(task);
}
