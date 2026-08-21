# app_intents_codegen

[![pub package](https://img.shields.io/pub/v/app_intents_codegen.svg)](https://pub.dev/packages/app_intents_codegen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Code generator for Flutter App Intents. Produces Swift, Kotlin, and Dart code from `@IntentSpec` and `@EntitySpec` annotations.

## Features

### iOS (Swift)
- Generate iOS 17+ Swift code for App Intents
- `ProvidesDialog` for Siri/Shortcuts dialog feedback
- `ParameterSummary` for Shortcuts UI display
- `AppEnum` generation for enum parameters
- Entity `DisplayRepresentation` with SF Symbol image support
- Support for `@AppShortcut` and `@AppShortcutsProvider`

### Android (Kotlin)
- Generate Android 16+ (API 36) Kotlin code for AppFunctions
- `@AppFunction` annotated methods for AI agent integration
- `@AppFunctionSerializable` data classes for entities
- `AppFunctionsBridge` singleton for MethodChannel communication

### Common
- Generate Dart initialization code for intent handlers
- CLI tools for Swift and Kotlin code generation
- Integration with `build_runner` for Dart code generation

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
class CreateTaskIntentSpec extends IntentSpecBase {
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

### 3. Generate Native Code

Use the CLI tools to generate native code:

```bash
# iOS: Generate Swift code
dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents

# Android: Generate Kotlin code
dart run app_intents_codegen:generate_kotlin -i lib -o android/app/src/main/kotlin/com/example/app/generated -p com.example.app.generated
```

#### Swift CLI Options

| Option | Description | Default |
|--------|-------------|---------|
| `-i, --input` | Input directory to scan | `lib` |
| `-o, --output` | Output directory for Swift files | `ios/Runner/GeneratedIntents` |
| `-f, --file` | Output filename | `GeneratedAppIntents.swift` |
| `--xcstrings` | Output path for .xcstrings String Catalog | (optional) |
| `-t, --translations` | Path to translations YAML file | (optional) |
| `--source-language` | Source language code | `en` |

#### Localization (.xcstrings) Generation

When `--xcstrings` is specified, the generator also produces an iOS String Catalog file containing all localizable strings from your annotations. Provide a translations YAML file to include multiple languages:

```yaml
# translations.yaml
ja:
  "Create Task": "タスクを作成"
  "Title": "タイトル"
  'Created task "{title}"': 'タスク「{title}」を作成しました'
zh-Hans:
  "Create Task": "创建任务"
```

```bash
dart run app_intents_codegen:generate_swift \
  -i lib -o ios/Runner/GeneratedIntents \
  --xcstrings ios/Runner/Localizable.xcstrings \
  -t translations.yaml
```

Keys must match the English text used in annotations. `{param}` placeholders are preserved in keys and converted to `%@` in values. System variables like `${applicationName}` are preserved as-is.

#### Kotlin CLI Options

| Option | Description | Default |
|--------|-------------|---------|
| `-i, --input` | Input directory to scan | `lib` |
| `-o, --output` | Output directory for Kotlin files | (required) |
| `-p, --package` | Kotlin package name | (required) |
| `-f, --file` | Output filename | `GeneratedAppFunctions.kt` |

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

The generator produces iOS 17+ compatible Swift code:

```swift
import AppIntents
import UIKit

@available(iOS 17.0, *)
struct CreateTaskIntentSpec: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description: IntentDescription =
        IntentDescription("Create a new task")

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Title")
    var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // URL scheme handling for Flutter integration
        // ...
        return .result(dialog: .init("Created task \"\(title)\""))
    }
}
```

### Dart Output

Generated part files contain type-safe Params classes and handler registration:

```dart
part of 'create_task_intent.dart';

class CreateTaskIntentParams {
  final String title;
  const CreateTaskIntentParams({required this.title});

  factory CreateTaskIntentParams.fromMap(Map<String, dynamic> map) {
    return CreateTaskIntentParams(title: map['title'] as String);
  }
}

void initializeCreateTaskAppIntents() {
  AppIntents().registerIntentHandler(
    'com.example.CreateTaskIntent',
    (params) async {
      final p = CreateTaskIntentParams.fromMap(params);
      await createTaskIntentHandler(title: p.title);
      return <String, dynamic>{};
    },
  );
}
```

## Related Packages

- [app_intents](https://pub.dev/packages/app_intents) - Flutter plugin for iOS App Intents and Android AppFunctions
- [app_intents_annotations](https://pub.dev/packages/app_intents_annotations) - Annotations for defining intents and entities

## License

MIT License - see the [LICENSE](LICENSE) file for details.
