import 'package:app_intents/app_intents.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';

part 'task_entity.intent.dart';

/// Entity specification for tasks.
///
/// This allows tasks to be used as parameters in Siri intents
/// with proper display and search capabilities.
@EntitySpec(
  identifier: 'com.example.taskapp.TaskEntity',
  title: 'Task',
  pluralTitle: 'Tasks',
  description: 'A task in your task list',
)
class TaskEntitySpec extends EntitySpecBase<Task> {
  @EntityId()
  final String id;

  @EntityTitle()
  final String title;

  @EntitySubtitle()
  final String? description;

  TaskEntitySpec({
    required this.id,
    required this.title,
    this.description,
  });
}

/// Query handler for TaskEntity.
Future<List<Task>> taskEntityQuery(List<String> identifiers) async {
  return TaskRepository.instance.getTasksByIds(identifiers);
}
