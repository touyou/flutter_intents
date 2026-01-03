import 'package:app_intents_annotations/app_intents_annotations.dart';

// Example Intent specification
@IntentSpec(
  identifier: 'com.example.CreateTaskIntent',
  title: 'Create Task',
  description: 'Creates a new task',
)
class CreateTaskIntentSpec extends IntentSpecBase<void, void> {
  @IntentParam(title: 'Title')
  final String title;

  @IntentParam(title: 'Due Date', isOptional: true)
  final DateTime? dueDate;

  const CreateTaskIntentSpec({required this.title, this.dueDate});
}

void main() {
  // Example usage - annotations are processed at build time
  const intent = CreateTaskIntentSpec(title: 'Example Task');
  print('Intent identifier: ${intent.title}');
}
