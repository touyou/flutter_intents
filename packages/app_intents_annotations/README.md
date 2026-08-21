# app_intents_annotations

[![pub package](https://img.shields.io/pub/v/app_intents_annotations.svg)](https://pub.dev/packages/app_intents_annotations)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Annotations for defining iOS App Intents and Android AppFunctions in Flutter. Use with `app_intents` and `app_intents_codegen` to generate Swift/Kotlin code for Siri, Shortcuts, Spotlight, and AI agent integration.

## Features

- `@IntentSpec` - Define App Intents with parameters
- `@IntentParam` - Define intent parameters with titles and options
- `@EntitySpec` - Define App Entities for parameter pickers
- `@EntityId`, `@EntityTitle`, `@EntitySubtitle`, `@EntityImage`, `@EntityDefaultQuery` - Entity property annotations
- `@EnumSpec`, `@EnumCaseDisplay` - Define AppEnum types for selection parameters
- `@AppShortcut`, `@AppShortcutsProvider` - Define App Shortcuts for Siri, Shortcuts, and Spotlight

## Installation

```yaml
dependencies:
  app_intents: ^0.14.0
  app_intents_annotations: ^0.14.0

dev_dependencies:
  app_intents_codegen: ^0.14.0
  build_runner: ^2.4.0
```

## Usage

### Defining an Intent

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@IntentSpec(
  identifier: 'com.example.CreateTaskIntent',
  title: 'Create Task',
  description: 'Create a new task',
)
class CreateTaskIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Title')
  final String title;

  @IntentParam(title: 'Due Date', isOptional: true)
  final DateTime? dueDate;

  CreateTaskIntentSpec({required this.title, this.dueDate});
}
```

### Defining an Entity

```dart
@EntitySpec(
  identifier: 'com.example.TaskEntity',
  title: 'Task',
  pluralTitle: 'Tasks',
)
class TaskEntitySpec extends EntitySpecBase<Task> {
  @EntityId()
  String id(Task task) => task.id;

  @EntityTitle()
  String title(Task task) => task.title;

  @EntitySubtitle()
  String? subtitle(Task task) => task.description;

  @EntityImage()
  String? image(Task task) => 'checkmark.circle';
}
```

### Defining App Shortcuts

```dart
@AppShortcutsProvider()
class TaskShortcutsProvider {
  @AppShortcut(
    intentIdentifier: 'com.example.CreateTaskIntent',
    phrases: [
      'Create a task in {applicationName}',
      'Add task to {applicationName}',
    ],
    shortTitle: 'Create Task',
    systemImageName: 'plus.circle',
  )
  static const createTask = null;
}
```

## Annotations Reference

| Annotation | Description |
|------------|-------------|
| `@IntentSpec` | Marks a class as an App Intent definition (with `resultDialogTemplate`, `parameterSummary`) |
| `@IntentParam` | Marks a field as an intent parameter (with `entityType`, `enumType`) |
| `@EntitySpec` | Marks a class as an App Entity definition |
| `@EntityId` | Marks a method as returning the entity ID |
| `@EntityTitle` | Marks a method as returning the entity title |
| `@EntitySubtitle` | Marks a method as returning the entity subtitle |
| `@EntityImage` | Marks a method as returning the entity image |
| `@EntityDefaultQuery` | Marks a method as the default query provider |
| `@EnumSpec` | Marks an enum as an AppEnum definition |
| `@EnumCaseDisplay` | Defines display properties for an enum case |
| `@AppShortcut` | Defines a shortcut phrase for an intent |
| `@AppShortcutsProvider` | Marks a class as providing app shortcuts |

## Related Packages

- [app_intents](https://pub.dev/packages/app_intents) - Flutter plugin for iOS App Intents and Android AppFunctions
- [app_intents_codegen](https://pub.dev/packages/app_intents_codegen) - Code generator for Swift, Kotlin, and Dart

## License

MIT License - see the [LICENSE](LICENSE) file for details.
