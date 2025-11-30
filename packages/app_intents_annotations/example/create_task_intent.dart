import 'package:app_intents_annotations/app_intents_annotations.dart';

@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  description: 'An intent to create a new task in your task list.',
  implementation: IntentImplementation.dart,
)
class CreateTaskIntentSpec extends IntentSpecBase<CreateTaskInput, Task> {
  @IntentParam(title: "Title")
  final String title;

  @IntentParam(title: "Due Date", isOptional: true)
  final DateTime? dueDate;

  const CreateTaskIntentSpec({
    required this.title,
    this.dueDate,
  });
}

class CreateTaskInput {
  final String title;
  final DateTime? dueDate;

  const CreateTaskInput({
    required this.title,
    this.dueDate,
  });
}

class Task {}
