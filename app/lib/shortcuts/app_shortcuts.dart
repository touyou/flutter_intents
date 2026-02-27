import 'package:app_intents_annotations/app_intents_annotations.dart';

@AppShortcutsProvider()
class TaskAppShortcuts {
  @AppShortcut(
    intentIdentifier: 'com.example.taskapp.createTask',
    phrases: [
      'Create a task in \${applicationName}',
      'Add a new task to \${applicationName}',
    ],
    shortTitle: 'Create Task',
    systemImageName: 'plus.circle',
  )
  static const createTask = null;

  @AppShortcut(
    intentIdentifier: 'com.example.taskapp.completeTask',
    phrases: [
      'Complete a task in \${applicationName}',
      'Mark task as done in \${applicationName}',
    ],
    shortTitle: 'Complete Task',
    systemImageName: 'checkmark.circle',
  )
  static const completeTask = null;
}
