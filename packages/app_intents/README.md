# app_intents

[![pub package](https://img.shields.io/pub/v/app_intents.svg)](https://pub.dev/packages/app_intents)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Flutter plugin for iOS App Intents and Android AppFunctions integration. Enables Siri, Shortcuts, Spotlight, and AI agent (Gemini) support for your Flutter app.

## Features

- Register intent handlers to respond to Siri, Shortcuts, and AI agent actions
- Define entity queries for parameter pickers in Shortcuts
- Stream-based intent execution events
- Cross-platform: iOS App Intents + Android AppFunctions
- Seamless integration with `app_intents_annotations` and `app_intents_codegen`

## Requirements

- **iOS**: 17.0+
- **Android**: API 36+ (Android 16, for AppFunctions)
- **Flutter**: 3.3+

## Installation

Add `app_intents` to your `pubspec.yaml`:

```yaml
dependencies:
  app_intents: ^0.10.1
  app_intents_annotations: ^0.10.1

dev_dependencies:
  app_intents_codegen: ^0.10.1
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

### Storage Configuration (iOS)

For cache-mode intents, configure App Group storage to enable cross-process data sharing. Without this, data may appear to "reset" when App Intents run in extension processes.

```dart
// Call before any cache operations (typically in main())
await appIntents.configureStorage(
  appGroupIdentifier: 'group.com.example.app',
);
```

On the iOS side, also call in your AppDelegate:
```swift
AppIntentsPlugin.configure(appGroupIdentifier: "group.com.example.app")
```

### Caching API

For foreground intent execution (cache mode), the plugin provides caching support:

```dart
// Process pending actions when app resumes
final hasPending = await appIntents.processPendingActions();

// Listen for pending actions
appIntents.pendingActionsStream.listen((identifier) {
  print('Pending action: $identifier');
});

// Cache values for intent parameters
await appIntents.setCachedValue('key', 'value');
final value = await appIntents.getCachedValue('key');
await appIntents.clearCachedValue('key');
```

## iOS Configuration

1. Set iOS deployment target to 17.0+ in `ios/Podfile`:

```ruby
platform :ios, '17.0'
```

2. See the [full documentation](https://github.com/touyou/flutter_intents/blob/main/docs/usage.md) for complete iOS setup instructions including Swift code generation.

## Android Configuration

1. Set `compileSdk` and `minSdk` to 36 in `android/app/build.gradle.kts`
2. Add KSP and AppFunctions dependencies
3. See the [full documentation](https://github.com/touyou/flutter_intents/blob/main/docs/usage.md) for complete Android setup instructions including Kotlin code generation.

## Related Packages

- [app_intents_annotations](https://pub.dev/packages/app_intents_annotations) - Annotations for defining intents and entities
- [app_intents_codegen](https://pub.dev/packages/app_intents_codegen) - Code generator for Swift, Kotlin, and Dart

## License

MIT License - see the [LICENSE](LICENSE) file for details.
