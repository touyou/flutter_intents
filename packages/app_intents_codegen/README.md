# app_intents_codegen

[![pub package](https://img.shields.io/pub/v/app_intents_codegen.svg)](https://pub.dev/packages/app_intents_codegen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Code generator for Flutter App Intents. Produces Swift and Dart code from `@IntentSpec` and `@EntitySpec` annotations.

## Features

- Generate iOS 16+ Swift code for App Intents
- Generate Dart initialization code for intent handlers
- Support for `@AppShortcut` and `@AppShortcutsProvider`
- CLI tool for Swift code generation
- Integration with `build_runner` for Dart code generation

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

### 1. Define Intents and Entities

Create your intent and entity specifications using annotations from `app_intents_annotations`:

```dart
// lib/intents/create_task_intent.dart
import 'package:app_intents/app_intents.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';

part 'create_task_intent.intent.dart';

@IntentSpec(
  identifier: 'com.example.CreateTaskIntent',
  title: 'Create Task',
)
class CreateTaskIntentSpec extends IntentSpecBase<void, Task> {
  @IntentParam(title: 'Title')
  final String title;

  CreateTaskIntentSpec({required this.title});
}

Future<Task> createTaskIntentHandler({required String title}) async {
  // Your implementation
}
```

### 2. Generate Dart Code

Run `build_runner` to generate Dart initialization code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This creates `*.intent.dart` part files with `initializeXxxAppIntents()` functions.

### 3. Generate Swift Code

Use the CLI tool to generate Swift code for iOS:

```bash
dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents
```

#### CLI Options

| Option | Description | Default |
|--------|-------------|---------|
| `-i, --input` | Input directory to scan | `lib` |
| `-o, --output` | Output directory for Swift files | `ios/Runner/GeneratedIntents` |
| `-f, --file` | Output filename | `GeneratedAppIntents.swift` |

### 4. Integrate Generated Code

Initialize the generated handlers in your Flutter app:

```dart
void main() {
  initializeCreateTaskAppIntents();
  initializeTaskEntityAppIntents();
  // ... other initializations

  runApp(MyApp());
}
```

## Generated Code

### Swift Output

The generator produces iOS 16+ compatible Swift code:

```swift
import AppIntents

@available(iOS 16.0, *)
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"

    @Parameter(title: "Title")
    var title: String

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // URL scheme handling for Flutter integration
    }
}
```

### Dart Output

Generated part files contain handler registration:

```dart
part of 'create_task_intent.dart';

void initializeCreateTaskAppIntents() {
  AppIntents().registerIntentHandler(
    'com.example.CreateTaskIntent',
    (params) async {
      // Handler invocation
    },
  );
}
```

## Related Packages

- [app_intents](https://pub.dev/packages/app_intents) - Flutter plugin for iOS App Intents
- [app_intents_annotations](https://pub.dev/packages/app_intents_annotations) - Annotations for defining intents and entities

## License

MIT License - see the [LICENSE](LICENSE) file for details.
