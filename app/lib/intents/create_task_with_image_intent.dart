import 'package:app_intents/app_intents.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';

part 'create_task_with_image_intent.intent.dart';

/// Intent specification for creating a task with an optional image attachment.
///
/// Uses cache mode (supportedModes: foreground without urlScheme):
/// 1. Siri/Shortcuts triggers the intent
/// 2. Swift caches parameters to UserDefaults via setPendingAction()
/// 3. App opens in foreground (supportedModes: .foreground)
/// 4. Flutter reads pending action via processPendingActions()
/// 5. Handler receives params via existing executeIntent mechanism
@IntentSpec(
  identifier: 'com.example.taskapp.createTaskWithImage',
  title: 'Create Task with Image',
  description: 'Create a new task with an optional image attachment',
  supportedModes: IntentMode.foreground,
  parameterSummary: 'Create task {title} {image}',
)
class CreateTaskWithImageIntentSpec
    extends IntentSpecBase<CreateTaskWithImageInput, Task> {
  @IntentParam(title: 'Title', description: 'The title of the task')
  final String title;

  @IntentParam(
    title: 'Image',
    description: 'An image to attach to the task',
    isOptional: true,
    fileType: 'public.image',
  )
  final IntentFile? image;

  CreateTaskWithImageIntentSpec({
    required this.title,
    this.image,
  });
}

/// Input model for the intent.
class CreateTaskWithImageInput {
  final String title;
  final IntentFile? image;

  const CreateTaskWithImageInput({required this.title, this.image});
}

/// Handler for the CreateTaskWithImage intent.
///
/// This handler is called transparently regardless of execution mode
/// (cache or FlutterBridge). The image file path from IntentFile points
/// to a temporary file written by the Swift side.
Future<Task> createTaskWithImageIntentHandler({
  required String title,
  IntentFile? image,
}) async {
  return TaskRepository.instance.createTask(
    title: title,
    imagePath: image?.path,
  );
}
