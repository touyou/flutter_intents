# Usage Guide

## Setup

### 1. Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  app_intents: ^0.2.1
  app_intents_annotations: ^0.2.1

dev_dependencies:
  app_intents_codegen: ^0.2.1
  build_runner: ^2.4.0
```

### 2. Platform Configuration

#### iOS

Set iOS version to 17.0 or higher in `ios/Podfile` (App Intents framework requirement):

```ruby
platform :ios, '17.0'
```

> **Note**: App Intents framework requires iOS 17.0 or later.

#### Android

Set `compileSdk`, `minSdk`, and `targetSdk` to 36 in `android/app/build.gradle.kts` (AppFunctions requires Android 16):

```kotlin
android {
    compileSdk = 36
    defaultConfig {
        minSdk = 36
        targetSdk = 36
    }
}
```

Add KSP and AppFunctions dependencies:

```kotlin
// android/settings.gradle.kts
id("com.google.devtools.ksp") version "2.2.20-2.0.4" apply false

// android/app/build.gradle.kts
plugins {
    id("com.google.devtools.ksp")
}
dependencies {
    implementation("androidx.appfunctions:appfunctions:1.0.0-alpha07")
    implementation("androidx.appfunctions:appfunctions-service:1.0.0-alpha07")
    ksp("androidx.appfunctions:appfunctions-compiler:1.0.0-alpha07")
}
```

> **Note**: AppFunctions requires Android 16 (API 36) or later.

## Defining Intents

### Basic Intent

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

// Input model
class CreateTaskInput {
  final String title;
  final DateTime? dueDate;

  CreateTaskInput({required this.title, this.dueDate});
}

// Output model
class Task {
  final String id;
  final String title;
  final DateTime? dueDate;

  Task({required this.id, required this.title, this.dueDate});
}

// Intent definition
@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  description: 'Create a new task in your task list',
  implementation: IntentImplementation.dart,
)
class CreateTaskIntentSpec extends IntentSpecBase<CreateTaskInput, Task> {
  @IntentParam(title: 'Task Title', description: 'The title of the task')
  final String title;

  @IntentParam(
    title: 'Due Date',
    description: 'Optional due date for the task',
    isOptional: true,
  )
  final DateTime? dueDate;

  const CreateTaskIntentSpec({required this.title, this.dueDate});
}
```

### Choosing Implementation Language

#### Dart Implementation (Recommended)

Use when you need access to Flutter features (UI, database, state management):

```dart
@IntentSpec(
  identifier: 'ShowTaskDetailIntent',
  title: 'Show Task',
  implementation: IntentImplementation.dart, // Implement in Dart
)
class ShowTaskDetailIntentSpec extends IntentSpecBase<String, void> {
  @IntentParam(title: 'Task ID')
  final String taskId;

  const ShowTaskDetailIntentSpec({required this.taskId});
}
```

#### Swift Implementation

Use for iOS-specific APIs or performance-critical operations:

```dart
@IntentSpec(
  identifier: 'QuickActionIntent',
  title: 'Quick Action',
  implementation: IntentImplementation.swift, // Implement in Swift
)
class QuickActionIntentSpec extends IntentSpecBase<void, String> {}
```

## Defining Entities

### Basic Entity

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

// Model class
class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;
  final String? thumbnailUrl;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.isCompleted = false,
    this.thumbnailUrl,
  });
}

// Entity definition
@EntitySpec(
  identifier: 'TaskEntity',
  title: 'Task',
  pluralTitle: 'Tasks',
  description: 'A task in your task list',
)
class TaskEntitySpec extends EntitySpecBase<Task> {
  // Required: Entity unique ID
  @EntityId()
  String id(Task task) => task.id;

  // Required: Display title
  @EntityTitle()
  String title(Task task) => task.title;

  // Optional: Subtitle
  @EntitySubtitle()
  String? subtitle(Task task) {
    if (task.dueDate != null) {
      return 'Due: ${_formatDate(task.dueDate!)}';
    }
    return task.description;
  }

  // Optional: Thumbnail image
  @EntityImage()
  String? imageUrl(Task task) => task.thumbnailUrl;

  // Optional: Default query (entity list retrieval)
  @EntityDefaultQuery()
  Future<List<Task>> defaultQuery() async {
    return TaskRepository.instance.getAllTasks();
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
```

### Adding Custom Queries

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

  // Default query: All tasks
  @EntityDefaultQuery()
  Future<List<Task>> defaultQuery() async {
    return TaskRepository.instance.getAllTasks();
  }

  // Future support planned: Custom queries
  // @EntityQuery(title: 'Incomplete Tasks')
  // Future<List<Task>> incompleteTasks() async {
  //   return TaskRepository.instance.getIncompleteTasks();
  // }
}
```

## Defining App Shortcuts

App Shortcuts become available in Siri/Shortcuts immediately after app installation.

### Defining AppShortcutsProvider

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

// Define shortcuts provider
@AppShortcutsProvider()
class MyAppShortcuts {
  // Define each shortcut
  @AppShortcut(
    intentIdentifier: 'CreateTaskIntent',
    phrases: [
      'Create a task in {applicationName}',
      'Add task to {applicationName}',
    ],
    shortTitle: 'Create Task',
    systemImageName: 'plus.circle',
  )
  static const createTask = null;

  @AppShortcut(
    intentIdentifier: 'ShowTasksIntent',
    phrases: [
      'Show my tasks in {applicationName}',
      'List tasks in {applicationName}',
    ],
    shortTitle: 'Show Tasks',
    systemImageName: 'list.bullet',
  )
  static const showTasks = null;
}
```

### Generated Swift Code

```swift
// Generated: AppShortcuts.swift
import AppIntents

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
        AppShortcut(
            intent: ShowTasksIntent(),
            phrases: [
                "Show my tasks in \(.applicationName)",
                "List tasks in \(.applicationName)"
            ],
            shortTitle: "Show Tasks",
            systemImageName: "list.bullet"
        )
    }
}
```

## Code Generation

### Running Generation

```bash
# Generate once
dart run build_runner build

# Watch and generate continuously
dart run build_runner watch
```

### Generated Files (Expected)

#### Swift Code

```swift
// Generated: TaskEntity.swift
import AppIntents

struct TaskEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Task",
        numericFormat: "\(placeholder: .int) Tasks"
    )

    static var defaultQuery = TaskQuery()

    var id: String
    var title: String
    var subtitle: String?
    var imageUrl: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitle.map { "\($0)" },
            image: imageUrl.map { .init(url: URL(string: $0)!) }
        )
    }
}

struct TaskQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TaskEntity] {
        // Call Dart's defaultQuery() via Flutter
        return try await FlutterBridge.queryEntities(identifiers: identifiers)
    }

    func suggestedEntities() async throws -> [TaskEntity] {
        return try await FlutterBridge.suggestedEntities()
    }
}
```

```swift
// Generated: CreateTaskIntent.swift
import AppIntents
import UIKit

@available(iOS 17.0, *)
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description: IntentDescription =
        IntentDescription("Create a new task in your task list")
    static var openAppWhenRun: Bool { true }

    // ParameterSummary: Controls how the intent appears in Shortcuts UI
    static var parameterSummary: some ParameterSummary {
        Summary("Create task \(\.$title)")
    }

    @Parameter(title: "Task Title", description: "The title of the task")
    var title: String

    @Parameter(title: "Due Date", description: "Optional due date for the task")
    var dueDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var components = URLComponents()
        components.scheme = "taskapp"
        components.host = "create"
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "title", value: String(describing: title)))
        if let dueDate {
            queryItems.append(URLQueryItem(name: "dueDate", value: ISO8601DateFormatter().string(from: dueDate)))
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else {
            throw AppIntentError.custom(code: "URL_CONSTRUCTION_FAILED", message: "Failed to construct URL for intent")
        }
        await UIApplication.shared.open(url)
        // ProvidesDialog: Shows feedback in Siri/Shortcuts
        return .result(dialog: .init("Created task \"\(title)\""))
    }
}
```

> **Note**: URL scheme is used because App Intents may run in an isolated iOS process, making direct MethodChannel calls impossible. URL scheme ensures the app is fully launched before Flutter-side processing.

### New in v0.2.0

#### Result Dialog Template

Show feedback to users in Siri/Shortcuts after intent execution:

```dart
@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  urlScheme: 'taskapp',
  urlAction: 'create',
  resultDialogTemplate: 'Created task "{title}"',  // Siri shows this message
)
```

The `{paramName}` placeholders are replaced with actual parameter values in the generated Swift code. This generates `some IntentResult & ProvidesDialog` as the return type.

#### Parameter Summary

Control how the intent appears in the Shortcuts editor:

```dart
@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  parameterSummary: 'Create task {title}',  // Shown in Shortcuts UI
)
```

The `{paramName}` placeholders become `\(\.$paramName)` in the generated Swift `ParameterSummary`.

#### AppEnum Support

Define enum parameters for selection-based inputs:

```dart
@EnumSpec(title: 'Priority')
enum TaskPriority {
  @EnumCaseDisplay(title: 'High', subtitle: 'Urgent tasks')
  high,
  @EnumCaseDisplay(title: 'Medium')
  medium,
  @EnumCaseDisplay(title: 'Low')
  low,
}
```

Use with `@IntentParam`:

```dart
@IntentParam(title: 'Priority', enumType: TaskPriority)
final TaskPriority priority;
```

This generates a Swift `AppEnum` with proper `typeDisplayRepresentation` and `caseDisplayRepresentations`.

## Deep Link Handling (Flutter Side)

Use the `app_links` package to receive URL schemes from generated Swift Intents.

### Setup

```yaml
# pubspec.yaml
dependencies:
  app_links: ^6.3.3
```

### Info.plist Configuration

```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.example.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>taskapp</string>  <!-- App-specific scheme -->
        </array>
    </dict>
</array>
<key>FlutterDeepLinkingEnabled</key>
<false/>  <!-- Set to false when using app_links package -->
```

### Flutter Implementation

```dart
import 'package:app_links/app_links.dart';

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();

    // Initial link when app launches
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }

    // Links while app is running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    switch (uri.host) {
      case 'create':
        // taskapp://create?title=xxx&dueDate=xxx
        _handleCreateTask(uri.queryParameters);
        break;
      case 'complete':
        // taskapp://complete?taskId=xxx
        _handleCompleteTask(uri.queryParameters);
        break;
    }
  }
}
```

## Plugin Usage

### Basic Usage

```dart
import 'package:app_intents/app_intents.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appIntents = AppIntents();
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  Future<void> _initPlatformState() async {
    String? platformVersion;
    try {
      platformVersion = await _appIntents.getPlatformVersion();
    } catch (e) {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion ?? 'Unknown';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Running on: $_platformVersion'),
        ),
      ),
    );
  }
}
```

## Best Practices

### 1. Intent Identifier Naming

```dart
// Good: Clear and unique identifier
@IntentSpec(identifier: 'com.myapp.CreateTaskIntent', ...)

// Good: Simple identifier (for small apps)
@IntentSpec(identifier: 'CreateTaskIntent', ...)

// Avoid: Ambiguous identifier
@IntentSpec(identifier: 'Create', ...)
```

### 2. Parameter Design

```dart
// Good: Appropriate optional settings
@IntentParam(title: 'Title')  // Required
final String title;

@IntentParam(title: 'Due Date', isOptional: true)  // Optional
final DateTime? dueDate;

// Good: Descriptive title
@IntentParam(
  title: 'Task Priority',
  description: 'Set the priority level (1-5)',
)
final int priority;
```

### 3. Entity Property Mapping

```dart
// Good: Meaningful subtitle
@EntitySubtitle()
String? subtitle(Task task) {
  if (task.isOverdue) return 'Overdue!';
  if (task.dueDate != null) return 'Due: ${formatDate(task.dueDate!)}';
  return task.description;
}

// Good: Image with fallback
@EntityImage()
String? imageUrl(Task task) {
  return task.thumbnailUrl ?? task.categoryIconUrl;
}
```

### 4. Error Handling

```dart
@EntityDefaultQuery()
Future<List<Task>> defaultQuery() async {
  try {
    return await TaskRepository.instance.getAllTasks();
  } catch (e) {
    // Log the error
    debugPrint('Failed to fetch tasks: $e');
    // Return empty list (prevent crash)
    return [];
  }
}
```

## Troubleshooting

### Build Errors

**Problem**: `undefined class 'IntentSpec'`

**Solution**: Import the `app_intents_annotations` package

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';
```

### iOS Build Errors

**Problem**: `Deployment target below iOS 17.0`

**Solution**: Update `ios/Podfile`

```ruby
platform :ios, '17.0'
```

> **Note**: App Intents framework requires iOS 17.0 or later.

### Code Generation Not Working

**Problem**: Generated files not created

**Solution**:
1. Ensure `build_runner` is in `dev_dependencies`
2. Run `dart run build_runner build --delete-conflicting-outputs`
3. Verify annotations are correctly applied
