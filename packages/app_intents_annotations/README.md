# app_intents_annotations

[![pub package](https://img.shields.io/pub/v/app_intents_annotations.svg)](https://pub.dev/packages/app_intents_annotations)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Annotations for defining iOS App Intents in Flutter. Use with `app_intents` and `app_intents_codegen` to generate Swift code for Siri, Shortcuts, and Spotlight integration.

## Features

- `@IntentSpec` - Define App Intents with parameters
- `@IntentParam` - Define intent parameters with titles and options
- `@EntitySpec` - Define App Entities for parameter pickers
- `@EntityId`, `@EntityTitle`, `@EntitySubtitle`, `@EntityImage` - Entity property annotations
- `@AppShortcut`, `@AppShortcutsProvider` - Define App Shortcuts for Spotlight

## Installation

```yaml
dependencies:
  app_intents: ^0.1.0
  app_intents_annotations: ^0.1.0

dev_dependencies:
  app_intents_codegen: ^0.1.0
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
class CreateTaskIntentSpec extends IntentSpecBase<CreateTaskInput, Task> {
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

  @EntityImage(type: EntityImageType.systemName)
  String? image(Task task) => 'checkmark.circle';
}
```

### Defining App Shortcuts

```dart
@AppShortcutsProvider()
class TaskShortcutsProvider {
  @AppShortcut(
    intent: CreateTaskIntentSpec,
    phrases: [
      'Create a task in \${applicationName}',
      'Add task to \${applicationName}',
    ],
  )
  static final createTask = AppShortcutDefinition();
}
```

## Annotations Reference

| Annotation | Description |
|------------|-------------|
| `@IntentSpec` | Marks a class as an App Intent definition |
| `@IntentParam` | Marks a field as an intent parameter |
| `@EntitySpec` | Marks a class as an App Entity definition |
| `@EntityId` | Marks a method as returning the entity ID |
| `@EntityTitle` | Marks a method as returning the entity title |
| `@EntitySubtitle` | Marks a method as returning the entity subtitle |
| `@EntityImage` | Marks a method as returning the entity image |
| `@EntityDefaultQuery` | Marks a method as the default query provider |
| `@AppShortcut` | Defines a shortcut phrase for an intent |
| `@AppShortcutsProvider` | Marks a class as providing app shortcuts |

## Related Packages

- [app_intents](https://pub.dev/packages/app_intents) - Flutter plugin for iOS App Intents
- [app_intents_codegen](https://pub.dev/packages/app_intents_codegen) - Code generator for Swift and Dart

## License

MIT License - see the [LICENSE](LICENSE) file for details.
