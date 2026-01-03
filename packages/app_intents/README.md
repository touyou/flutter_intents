# app_intents

[![pub package](https://img.shields.io/pub/v/app_intents.svg)](https://pub.dev/packages/app_intents)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Flutter plugin for iOS App Intents integration. Enables Siri, Shortcuts, and Spotlight support for your Flutter app.

## Features

- Register intent handlers to respond to Siri and Shortcuts actions
- Define entity queries for parameter pickers in Shortcuts
- Stream-based intent execution events
- Seamless integration with `app_intents_annotations` and `app_intents_codegen`

## Requirements

- iOS 16.0 or later
- Flutter 3.38+

## Installation

Add `app_intents` to your `pubspec.yaml`:

```yaml
dependencies:
  app_intents: ^0.1.0
  app_intents_annotations: ^0.1.0

dev_dependencies:
  app_intents_codegen: ^0.1.0
  build_runner: ^2.4.0
```

## Usage

### Basic Setup

```dart
import 'package:app_intents/app_intents.dart';

final appIntents = AppIntents();

// Register an intent handler
appIntents.registerIntentHandler(
  'com.example.AddTaskIntent',
  (params) async {
    final title = params['title'] as String;
    // Process the intent...
    return {'taskId': 'new-task-id'};
  },
);
```

### Entity Queries

Provide entities for parameter pickers in Shortcuts:

```dart
// Query entities by identifiers
appIntents.registerEntityQueryHandler(
  'TaskEntity',
  (identifiers) async {
    final tasks = await database.getTasksByIds(identifiers);
    return tasks.map((t) => {
      'id': t.id,
      'title': t.title,
    }).toList();
  },
);

// Provide suggested entities
appIntents.registerSuggestedEntitiesHandler(
  'TaskEntity',
  () async {
    final recentTasks = await database.getRecentTasks(limit: 10);
    return recentTasks.map((t) => {
      'id': t.id,
      'title': t.title,
    }).toList();
  },
);
```

### Intent Execution Stream

Listen to intent executions reactively:

```dart
appIntents.onIntentExecution.listen((request) {
  print('Intent ${request.identifier} executed');
  print('Parameters: ${request.params}');
});
```

## iOS Configuration

1. Set iOS deployment target to 16.0+ in `ios/Podfile`:

```ruby
platform :ios, '16.0'
```

2. See the [full documentation](https://github.com/touyou/flutter_intents/blob/main/docs/usage.md) for complete iOS setup instructions including Swift code generation.

## Related Packages

- [app_intents_annotations](https://pub.dev/packages/app_intents_annotations) - Annotations for defining intents and entities
- [app_intents_codegen](https://pub.dev/packages/app_intents_codegen) - Code generator for Swift and Dart

## License

MIT License - see the [LICENSE](LICENSE) file for details.
