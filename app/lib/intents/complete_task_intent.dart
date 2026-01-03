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
)
class CompleteTaskIntentSpec extends IntentSpecBase<String, Task?> {
  @IntentParam(title: 'Task ID', description: 'The ID of the task to complete')
  final String taskId;

  CompleteTaskIntentSpec({required this.taskId});
}

/// Handler for the CompleteTask intent.
Future<Task?> completeTaskIntentHandler({
  required String taskId,
}) async {
  return TaskRepository.instance.toggleTaskCompletion(taskId);
}
