# Flutter Intents

[![CI](https://github.com/touyou/flutter_intents/actions/workflows/ci.yml/badge.svg)](https://github.com/touyou/flutter_intents/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

| Package | pub.dev |
| --- | --- |
| [`app_intents`](packages/app_intents/) | [![pub package](https://img.shields.io/pub/v/app_intents.svg)](https://pub.dev/packages/app_intents) |
| [`app_intents_annotations`](packages/app_intents_annotations/) | [![pub package](https://img.shields.io/pub/v/app_intents_annotations.svg)](https://pub.dev/packages/app_intents_annotations) |
| [`app_intents_codegen`](packages/app_intents_codegen/) | [![pub package](https://img.shields.io/pub/v/app_intents_codegen.svg)](https://pub.dev/packages/app_intents_codegen) |

A collection of packages for integrating iOS App Intents and Android AppFunctions frameworks with Flutter applications.

[日本語版 README](README.ja.md)

## Overview

Flutter Intents enables Flutter apps to integrate with iOS App Intents (Siri, Shortcuts, Spotlight) and Android AppFunctions (Gemini, AI agents) through declarative annotations and automatic native code generation.

### Key Features

1. **Declarative Intent Definition**: Define App Intents using Dart annotations
2. **Type Safety**: Compile-time type checking via generated Params classes
3. **Code Generation**: Automatic Swift and Kotlin code generation from Dart definitions
4. **Cross-Platform**: iOS App Intents + Android AppFunctions from one codebase

## Project Structure

```
flutter_intents/
├── packages/
│   ├── app_intents_annotations/  # Annotation definitions
│   ├── app_intents/              # Flutter plugin
│   │   └── ios/app_intents/      # iOS Swift Package: plugin + AppIntentsBridge
│   └── app_intents_codegen/      # Code generator
├── app/                          # Example app
└── docs/                         # Documentation
```

## Packages

| Package | Description |
|---------|-------------|
| [app_intents](packages/app_intents/) | Flutter plugin for iOS App Intents and Android AppFunctions |
| [app_intents_annotations](packages/app_intents_annotations/) | Annotations for defining intents and entities |
| [app_intents_codegen](packages/app_intents_codegen/) | Swift, Kotlin, and Dart code generator |

## Quick Start

### 1. Add Dependencies

```yaml
dependencies:
  app_intents: ^0.14.0
  app_intents_annotations: ^0.14.0

dev_dependencies:
  app_intents_codegen: ^0.14.0
  build_runner: ^2.4.0
```

### 2. Define an Intent

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@IntentSpec(
  identifier: 'CreateTaskIntent',
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

### 3. Define an Entity

```dart
@EntitySpec(
  identifier: 'TaskEntity',
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
}
```

### 4. Generate Code

```bash
# Generate Dart code
dart run build_runner build --delete-conflicting-outputs

# Generate Swift code (iOS)
dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents

# Generate Kotlin code (Android)
dart run app_intents_codegen:generate_kotlin -i lib -o android/app/src/main/kotlin/com/example/app/generated -p com.example.app.generated
```

## Documentation

- [Architecture](docs/architecture.md) - Design philosophy and system overview
- [Package Details](docs/packages.md) - Detailed package specifications
- [Usage Guide](docs/usage.md) - Implementation guide and examples

## Requirements

- **Dart SDK**: ^3.10.0
- **Flutter**: 3.3+
- **iOS**: 17.0+ (App Intents), Swift 5.9+
- **Android**: API 36+ (Android 16, AppFunctions)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.
All participants are expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

To report a security vulnerability, please follow the process in [SECURITY.md](SECURITY.md).

## License

MIT License - see the [LICENSE](LICENSE) file for details.
