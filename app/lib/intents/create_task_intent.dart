import 'package:app_intents/app_intents.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';

part 'create_task_intent.intent.dart';

/// Input for creating a task.
class CreateTaskInput {
  final String title;
  final String? description;
  final DateTime? dueDate;

  const CreateTaskInput({
    required this.title,
    this.description,
    this.dueDate,
  });
}

/// Intent specification for creating a new task.
@IntentSpec(
  identifier: 'com.example.taskapp.createTask',
  title: 'Create Task',
  description: 'Create a new task in your task list',
)
class CreateTaskIntentSpec extends IntentSpecBase<CreateTaskInput, Task> {
  @IntentParam(title: 'Title', description: 'The title of the task')
  final String title;

  @IntentParam(
    title: 'Description',
    description: 'Optional description for the task',
    isOptional: true,
  )
  final String? description;

  @IntentParam(
    title: 'Due Date',
    description: 'When the task is due',
    isOptional: true,
  )
  final DateTime? dueDate;

  CreateTaskIntentSpec({
    required this.title,
    this.description,
    this.dueDate,
  });
}

/// Handler for the CreateTask intent.
Future<Task> createTaskIntentHandler({
  required String title,
  String? description,
  DateTime? dueDate,
}) async {
  return TaskRepository.instance.createTask(
    title: title,
    description: description,
    dueDate: dueDate,
  );
}
