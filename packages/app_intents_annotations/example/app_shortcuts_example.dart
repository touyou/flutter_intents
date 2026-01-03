import 'package:app_intents_annotations/app_intents_annotations.dart';

/// Example of using AppShortcutsProvider and AppShortcut annotations
///
/// This example demonstrates how to define app shortcuts that will be
/// available in Siri and Spotlight immediately after app installation.
///
/// Requirements:
/// - iOS 16.0 or later
@AppShortcutsProvider()
class TaskAppShortcuts {
  /// Shortcut for creating a new task
  ///
  /// Users can say "Create a task in TaskApp" or "Add task" to Siri
  @AppShortcut(
    intentIdentifier: 'CreateTaskIntent',
    phrases: [
      'Create a task in {applicationName}',
      'Add task to {applicationName}',
      'New task',
    ],
    shortTitle: 'Create Task',
    systemImageName: 'plus.circle.fill',
  )
  static const createTask = null;

  /// Shortcut for listing all tasks
  @AppShortcut(
    intentIdentifier: 'ListTasksIntent',
    phrases: [
      'Show my tasks in {applicationName}',
      'List tasks',
      'What are my tasks',
    ],
    shortTitle: 'List Tasks',
    systemImageName: 'list.bullet',
  )
  static const listTasks = null;

  /// Shortcut for completing a task
  @AppShortcut(
    intentIdentifier: 'CompleteTaskIntent',
    phrases: [
      'Complete task in {applicationName}',
      'Mark task as done',
    ],
    shortTitle: 'Complete Task',
    systemImageName: 'checkmark.circle.fill',
  )
  static const completeTask = null;
}

void main() {
  // This example shows the annotation usage.
  // The actual code generation will be handled by app_intents_generator.
  print('TaskAppShortcuts defined with AppShortcutsProvider annotation');
}
