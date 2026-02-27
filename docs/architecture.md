# Architecture

## Design Philosophy

Flutter Intents provides a bridge to the iOS App Intents framework, enabling Flutter apps to integrate with Siri, Shortcuts, and Spotlight.

### Design Principles

1. **Declarative Definition**: Define Intents/Entities using annotations
2. **Separation of Concerns**: Annotations, plugin, and code generation in separate packages
3. **Type Safety**: Compile-time type checking via generics
4. **Platform Abstraction**: Loose coupling via Platform Interface pattern

## Overall Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Application                      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Intent/Entity Specifications                         │   │
│  │  Classes with @IntentSpec / @EntitySpec annotations   │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                         │                                    │
│  ┌──────────────────────▼───────────────────────────────┐   │
│  │  app_intents Plugin                                   │   │
│  │  - Platform Interface                                 │   │
│  │  - Method Channel                                     │   │
│  └──────────────────────┬───────────────────────────────┘   │
└─────────────────────────┼───────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
   ┌─────────┐    ┌──────────────┐    ┌───────────────┐
   │ Dart    │    │ Generated    │    │ iOS Native    │
   │ Handler │◄───│ Swift Code   │───►│ App Intents   │
   └─────────┘    └──────────────┘    │ Framework     │
                         ▲            └───────────────┘
                         │
              ┌──────────┴──────────┐
              │ app_intents_codegen │
              │ (build_runner)      │
              └─────────────────────┘
```

## Data Flow

### Intent Execution Flow (URL Scheme)

```
[Siri/Shortcuts/Spotlight]
         │
         ▼
[iOS App Intents Framework]
         │
         ▼
[Generated Swift Intent]
         │ openAppWhenRun = true
         ▼
[UIApplication.shared.open(url)]
         │ taskapp://action?params
         ▼
[Flutter App (via app_links)]
         │
         ▼
[Dart Handler → Business Logic]
```

> **Note**: URL scheme is used because App Intents may run in an isolated process (WFIsolatedShortcutRunner), where the Flutter engine is not available. Using URL scheme ensures the app is fully launched before processing.

### Code Generation Flow

```
[Dart Source Files]
    @IntentSpec
    @EntitySpec
         │
         ▼
[app_intents_codegen]
    - Analyzer
    - Generator
         │
         ▼
[Generated Files]
    - Swift App Intents
    - Swift Entity Queries
    - Dart Bindings
```

## Layer Structure

### Layer 1: Annotation Layer (app_intents_annotations)

Responsible only for metadata definition. No runtime dependencies.

```dart
// Intent definition
@IntentSpec(
  identifier: 'MyIntent',
  title: 'My Intent',
  implementation: IntentImplementation.dart,
)
class MyIntentSpec extends IntentSpecBase<Input, Output> {}

// Entity definition
@EntitySpec(identifier: 'MyEntity', title: 'My Entity')
class MyEntitySpec extends EntitySpecBase<MyModel> {
  @EntityId()
  String id(MyModel m) => m.id;
}
```

### Layer 2: Plugin Layer (app_intents)

Responsible for native communication via Platform Channel.

```
AppIntents (Facade)
       │
       ▼
AppIntentsPlatform (Interface)
       │
       ▼
MethodChannelAppIntents (Implementation)
       │
       ▼
FlutterMethodChannel ◄──► AppIntentsPlugin.swift
```

### Layer 3: Code Generation Layer (app_intents_codegen)

Analyzes Dart annotations and generates Swift code.

```
Source Analysis
       │
       ▼
AST Processing
       │
       ▼
Template Generation
       │
       ▼
Swift Output
```

## Design Patterns

### 1. Annotation-based Metadata

```dart
// Declaratively define metadata
@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  description: 'Creates a new task',
  implementation: IntentImplementation.dart,
)
class CreateTaskIntentSpec extends IntentSpecBase<String, Task> {}
```

**Benefits:**
- Code and specification colocated
- IDE support (completion, refactoring)
- Compile-time validation

### 2. Descriptor Pattern (Entity Property Mapping)

```dart
class TaskEntitySpec extends EntitySpecBase<Task> {
  @EntityId()
  String id(Task task) => task.id;

  @EntityTitle()
  String title(Task task) => task.title;

  @EntitySubtitle()
  String? subtitle(Task task) => task.description;

  @EntityImage()
  String? imageUrl(Task task) => task.thumbnailUrl;
}
```

**Benefits:**
- Define mappings without modifying model classes
- Flexible transformation logic
- Easy to test

### 3. Platform Interface Pattern

```dart
// Abstract interface
abstract class AppIntentsPlatform extends PlatformInterface {
  static AppIntentsPlatform _instance = MethodChannelAppIntents();

  Future<String?> getPlatformVersion();
}

// Method Channel implementation
class MethodChannelAppIntents extends AppIntentsPlatform {
  final methodChannel = MethodChannel('app_intents');

  @override
  Future<String?> getPlatformVersion() {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }
}
```

**Benefits:**
- Easy to mock for testing
- Separation of platform implementations
- Future extensibility

### 4. Implementation Language Selection Pattern

```dart
enum IntentImplementation {
  dart,   // Implement intent handling in Flutter
  swift,  // Implement in native Swift
}
```

**Use cases:**
- `dart`: When Flutter features are needed (UI display, database access, etc.)
- `swift`: Performance-critical, using iOS-specific APIs

## Type System

### Type Safety via Generics

```dart
// IntentSpecBase<I, O>
// I = Input type, O = Output type
class IntentSpecBase<I, O> {
  const IntentSpecBase();
}

// Concrete usage
class CreateTaskIntentSpec extends IntentSpecBase<CreateTaskInput, Task> {
  // Input: CreateTaskInput
  // Output: Task
}
```

### Entity Type Constraints

```dart
// EntitySpecBase<M>
// M = Model type
abstract class EntitySpecBase<M> {
  const EntitySpecBase();
}

// Usage
class TaskEntitySpec extends EntitySpecBase<Task> {
  // Entity definition for Task model
}
```

## iOS App Intents Support

### Platform Requirements

| Item | Requirement |
|------|-------------|
| **Minimum iOS Version** | iOS 17.0+ |
| **Swift** | 5.0+ |
| **Xcode** | 14.0+ |

### Design Decisions

| Item | Decision |
|------|----------|
| AppShortcutsProvider | Supported (auto-generated predefined shortcuts) |
| Handler Registration | Auto-registration (registration code generated) |
| Localization | String Catalog (iOS standard) |
| Error Handling | Both (iOS standard + custom error types) |
| Entity Image Formats | URL + Asset + SF Symbol |

### Supported Features

| iOS Feature | Status | Description |
|-------------|--------|-------------|
| AppIntent | ✅ Complete | Action execution from Siri/Shortcuts (via URL scheme) |
| AppEntity | ✅ Complete | Entity search and display |
| AppShortcut | ✅ Complete | Predefined shortcuts |
| EntityQuery | ✅ Complete | Entity search queries (via MethodChannel) |
| AppShortcutsProvider | ✅ Complete | Automatic shortcut registration |

### Generated Swift Code

```swift
// Generated from CreateTaskIntentSpec (iOS 17+)
import AppIntents
import UIKit

@available(iOS 17.0, *)
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description: IntentDescription =
        IntentDescription("Creates a new task")
    static var openAppWhenRun: Bool = true  // Launch app before execution

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Due Date")
    var dueDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult {
        // Delegate processing to app via URL scheme
        var urlString = "taskapp://create?title=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title)"
        if let dueDate = dueDate {
            let formatter = ISO8601DateFormatter()
            urlString += "&dueDate=\(formatter.string(from: dueDate))"
        }
        if let url = URL(string: urlString) {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// Generated AppShortcutsProvider
@available(iOS 17.0, *)
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Create a task in \(.applicationName)",
                "Add task to \(.applicationName)"
            ],
            shortTitle: "Create Task",
            systemImageName: "plus.circle"
        )
    }
}
```

## Future Extension Points

1. **macOS Support**: macOS Shortcuts integration
2. **Widget Integration**: iOS WidgetKit, Interactive Widgets
3. **Focus Filter**: iOS Focus integration
4. **Live Activities**: Dynamic Island / Lock Screen integration
