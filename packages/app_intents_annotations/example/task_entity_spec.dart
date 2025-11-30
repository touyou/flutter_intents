import 'package:app_intents_annotations/app_intents_annotations.dart';

import 'models/task.dart';

@EntitySpec(
  identifier: 'TaskEntity',
  title: 'Task',
  pluralTitle: 'Tasks',
  description: 'An entity representing a task in a task management system.',
)
class TaskEntitySpec extends EntitySpecBase<Task>{
  const TaskEntitySpec();

  @EntityId()
  String id(Task task) => task.id;

  @EntityTitle()
  String title(Task task) => task.title;

  @EntitySubtitle()
  String? subtitle(Task task) => task.dueDate != null
      ? 'Due: ${task.dueDate!.toLocal().toIso8601String()}'
      : null;

  @EntityImage()
  Uri? imageUrl(Task task) => null;

  @EntityDefaultQuery()
  Future<List<Task>> defaultQuery() async {
    return TaskRepository.instance.getAllTasks();
  }
}
