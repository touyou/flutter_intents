# Usage Guide

## Setup

### 1. Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  app_intents: ^0.10.1
  app_intents_annotations: ^0.10.1

dev_dependencies:
  app_intents_codegen: ^0.10.1
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

`appfunctions:1.0.0-alpha09` requires **Android Gradle Plugin 9.1.0+**, **Gradle 9.3.1+**, and **compileSdk 37**.
Update `android/app/build.gradle.kts` (`minSdk = 36` because AppFunctions requires Android 16):

```kotlin
android {
    compileSdk = 37
    defaultConfig {
        minSdk = 36
        targetSdk = 37
    }
}
```

Add KSP and AppFunctions dependencies:

```kotlin
// android/settings.gradle.kts
id("com.android.application") version "9.1.1" apply false
id("org.jetbrains.kotlin.android") version "2.2.20" apply false
id("com.google.devtools.ksp") version "2.2.20-2.0.4" apply false

// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.devtools.ksp")
    id("dev.flutter.flutter-gradle-plugin")
}
dependencies {
    implementation("androidx.appfunctions:appfunctions:1.0.0-alpha09")
    implementation("androidx.appfunctions:appfunctions-service:1.0.0-alpha09")
    ksp("androidx.appfunctions:appfunctions-compiler:1.0.0-alpha09")
}

ksp {
    arg("appfunctions:aggregateAppFunctions", "true")
}
```

Add the following AGP 9 compatibility shims to `android/gradle.properties`:

```properties
# Flutter Gradle plugin does not yet support the new AGP 9 DSL — keep legacy DSL.
android.newDsl=false
# KSP is incompatible with AGP 9's built-in Kotlin — keep the kotlin-android plugin.
android.builtInKotlin=false
```

Update the Gradle wrapper to 9.3.1+ in `android/gradle/wrapper/gradle-wrapper.properties`:

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-9.3.1-all.zip
```

> **Note**: AppFunctions requires Android 16 (API 36) or later. The `compileSdk = 37` requirement comes from the `appfunctions:1.0.0-alpha09` AAR metadata.

### 3. iOS Native Setup (AppIntentsBridge)

The `AppIntentsBridge` Swift package provides the native bridge between your Flutter app and iOS App Intents. You can add it via Swift Package Manager (SPM):

1. Open your Xcode project (`ios/Runner.xcworkspace`)
2. Go to **File → Add Package Dependencies**
3. Enter the repository URL: `https://github.com/touyou/flutter_intents`
4. Select the `AppIntentsBridge` package product
5. Add it to your `Runner` target

Then configure App Groups for cross-process storage (required for cache mode):

1. In Xcode: Select Runner target → **Signing & Capabilities** → **+ Capability** → **App Groups**
2. Add an identifier (e.g., `group.com.example.app`)

Then in your `AppDelegate.swift`:

```swift
import app_intents
import AppIntentsBridge

// In your AppDelegate (using FlutterImplicitEngineDelegate):
if #available(iOS 17.0, *) {
  // Configure App Group storage — required for cache mode intents to share data
  // between the main app and App Intent extension processes.
  // Without this, cached data may appear to "reset" across processes.
  AppIntentsPlugin.configure(appGroupIdentifier: "group.com.example.app")

  Task { @MainActor in
    // Intent executor
    await FlutterBridge.shared.setIntentExecutor { identifier, params in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentError.intentNotFound(identifier)
      }
      return try await plugin.executeIntentAsync(identifier: identifier, params: params)
    }

    // Entity query executor
    await FlutterBridge.shared.setEntityQueryExecutor { entityIdentifier, identifiers in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentError.entityQueryNotConfigured
      }
      return try await plugin.queryEntitiesAsync(
        entityIdentifier: entityIdentifier, identifiers: identifiers)
    }

    // Suggested entities executor
    await FlutterBridge.shared.setSuggestedEntitiesExecutor { entityIdentifier in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentError.entityQueryNotConfigured
      }
      return try await plugin.getSuggestedEntitiesAsync(entityIdentifier: entityIdentifier)
    }
  }
}
```

#### FlutterBridge waitForPlugin Pattern

When App Intents execute via FlutterBridge mode, the Flutter engine may not be initialized yet. The generated entity query code uses a retry pattern internally (`FlutterBridge` waits up to 5 seconds for executors to be set). For custom Swift code that needs to access `AppIntentsPlugin.shared`, use the following pattern:

```swift
private static func waitForPlugin() async throws -> AppIntentsPlugin {
    if let plugin = AppIntentsPlugin.shared { return plugin }
    // Retry up to 20 times at 100ms intervals (max 2 seconds total).
    // Flutter engine typically initializes in 0.5–1.5 seconds on modern devices.
    // 2 seconds provides a safe margin for slower devices or debug builds.
    for _ in 0..<20 {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        if let plugin = AppIntentsPlugin.shared { return plugin }
    }
    // If the plugin is still nil after 2 seconds, the Flutter engine
    // failed to start. The intent will fail with an error shown to the user.
    throw AppIntentError.custom(
        code: "PLUGIN_UNAVAILABLE",
        message: "Flutter engine did not initialize in time"
    )
}
```

> **Timeout rationale**: 100ms interval x 20 retries = 2 seconds maximum wait. Flutter engine startup on iOS typically takes 0.5–1.5 seconds. The 2-second timeout provides adequate margin for slower devices and debug builds while keeping the user experience responsive.

> **Failure behavior**: When the timeout is exceeded, the intent throws an error. Siri/Shortcuts displays a generic failure message to the user. For production apps, prefer URL Scheme mode which avoids this timing issue entirely.

## Defining Intents

### Basic Intent

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  description: 'Create a new task in your task list',
  implementation: IntentImplementation.dart,
)
class CreateTaskIntentSpec extends IntentSpecBase {
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
class ShowTaskDetailIntentSpec extends IntentSpecBase {
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
class QuickActionIntentSpec extends IntentSpecBase {}
```

#### Kotlin Implementation

Use for Android-specific APIs:

```dart
@IntentSpec(
  identifier: 'AndroidShareIntent',
  title: 'Share',
  implementation: IntentImplementation.kotlin, // Implement in Kotlin
)
class AndroidShareIntentSpec extends IntentSpecBase {}
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
// From GeneratedAppIntents.swift (all generated types are in one file)
import AppIntents

struct TaskEntitySpec: AppEntity {
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
// Also in GeneratedAppIntents.swift
import AppIntents
import UIKit

@available(iOS 17.0, *)
struct CreateTaskIntentSpec: AppIntent {
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

### Advanced Features

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

## Execution Modes

The code generator automatically selects one of three execution modes based on your `@IntentSpec` configuration. Each mode determines how the generated Swift code communicates with your Flutter app.

### Mode Selection

| Configuration | Mode | File Params | Use Case |
|---------------|------|-------------|----------|
| `urlScheme` set | **URL Scheme** | Not supported | Most common. Opens app via deep link. |
| `supportedModes: foreground`, no `urlScheme` | **Cache** | Supported | When you need `IntentFile` parameters (images, files). |
| Neither set | **FlutterBridge** | Supported | Background execution (requires Flutter engine to be running). |

### URL Scheme Mode

The most common mode. Set `urlScheme` and `urlAction` to enable:

```dart
@IntentSpec(
  identifier: 'com.example.createTask',
  title: 'Create Task',
  urlScheme: 'taskapp',    // Your app's URL scheme
  urlAction: 'create',     // Action segment (taskapp://create?...)
  resultDialogTemplate: 'Created task "{title}"',
)
class CreateTaskIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Title')
  final String title;

  const CreateTaskIntentSpec({required this.title});
}
```

The generated Swift code opens `taskapp://create?title=xxx` via `UIApplication.shared.open(url)`. Your Flutter app receives this URL via the `app_links` package (see [Deep Link Handling](#deep-link-handling-flutter-side) below).

**Limitation**: File data cannot be passed through URL query parameters. Use Cache mode instead if you need file parameters.

### Cache Mode (Foreground)

Use this mode when your intent accepts file parameters (`IntentFile`). Set `supportedModes: IntentMode.foreground` without `urlScheme`:

```dart
@IntentSpec(
  identifier: 'com.example.createTaskWithImage',
  title: 'Create Task with Image',
  description: 'Create a new task with an optional image attachment',
  supportedModes: IntentMode.foreground,
  parameterSummary: 'Create task {title} {image}',
)
class CreateTaskWithImageIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Title', description: 'The title of the task')
  final String title;

  @IntentParam(
    title: 'Image',
    description: 'An image to attach to the task',
    isOptional: true,
    fileType: 'public.image',
  )
  final IntentFile? image;

  CreateTaskWithImageIntentSpec({required this.title, this.image});
}

Future<void> createTaskWithImageHandler({
  required String title,
  IntentFile? image,
}) async {
  // image?.path contains the temp file path written by Swift
  await TaskRepository.instance.createTask(
    title: title,
    imagePath: image?.path,
  );
}
```

**How it works**:

```
Siri/Shortcuts → Generated AppIntent.perform()
  → Writes IntentFile data to temp file
  → Calls AppIntentsPlugin.setPendingAction(identifier, params)
  → Returns .result() → iOS opens app (supportedModes: .foreground)
  → Flutter engine starts → handlers register
  → processPendingActions() reads from UserDefaults
  → Delivers params to registered handler
```

**Required**:
- Call `AppIntentsPlugin.configure(appGroupIdentifier:)` in your AppDelegate (see [iOS Native Setup](#3-ios-native-setup-appintentsbridge))
- Call `configureStorage()` and `processPendingActions()` in your `main()` (see [Plugin Usage](#plugin-usage))

### FlutterBridge Mode (Background)

The default mode when neither `urlScheme` nor `supportedModes` is set:

```dart
@IntentSpec(
  identifier: 'com.example.quickLookup',
  title: 'Quick Lookup',
)
class QuickLookupIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Query')
  final String query;

  const QuickLookupIntentSpec({required this.query});
}
```

The generated Swift code calls `FlutterBridge.shared.invoke()` directly via MethodChannel.

> **Warning**: This mode requires the Flutter engine to already be running. App Intents may execute in an isolated process (`WFIsolatedShortcutRunner`) where the Flutter engine is not available. For most use cases, prefer URL Scheme or Cache mode.

### File Parameters (IntentFile)

Use `@IntentParam(fileType:)` to accept file inputs from Siri/Shortcuts:

```dart
@IntentParam(
  title: 'Photo',
  isOptional: true,
  fileType: 'public.image',  // UTType identifier
)
final IntentFile? photo;
```

The `IntentFile` class provides:
- `path` — Temporary file path (written by the Swift side)
- `mimeType` — MIME type (e.g., `image/jpeg`), nullable
- `filename` — Original filename, nullable

Common UTType identifiers: `public.image`, `public.movie`, `public.audio`, `public.data`, `public.pdf`.

File parameters require **Cache mode** (`supportedModes: IntentMode.foreground` without `urlScheme`). On Android, `IntentFile` is mapped to `String` (file URI) in the generated Kotlin code.

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

### Initializing Handlers

Call the generated initialization functions in your `main.dart`. Each spec file generates its own `initializeXxxAppIntents()` function that registers intent handlers, entity query handlers, and suggested entities handlers.

```dart
import 'package:app_intents/app_intents.dart';
import 'intents/create_task_intent.dart';
import 'intents/create_task_with_image_intent.dart';
import 'entities/task_entity.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure App Group storage (iOS, required for cache mode).
  // Must match the appGroupIdentifier in AppDelegate.swift.
  await AppIntents().configureStorage(
    appGroupIdentifier: 'group.com.example.app',
  );

  // Register intent/entity handlers (generated code)
  initializeCreateTaskAppIntents();
  initializeCreateTaskWithImageAppIntents();
  initializeTaskEntityAppIntents();

  // Required for cache execution mode:
  // Reads any pending action stored in UserDefaults by setPendingAction()
  // and delivers it to the registered handler via executeIntent.
  AppIntents().processPendingActions();

  // Listen for pending actions arriving while the app is already running.
  // This handles the case where an intent fires after Flutter is initialized.
  AppIntents().pendingActionsStream.listen((identifier) {
    AppIntents().processPendingActions();
  });

  runApp(MyApp());
}
```

> **Note**: `processPendingActions()` is only needed if you use Cache execution mode (`supportedModes: IntentMode.foreground` without `urlScheme`). It is harmless to call even if no pending actions exist.

### Initialization Order (Cold Start)

When using `processPendingActions()`, the initialization order in `main()` is critical. Intent handlers must be registered **before** calling `processPendingActions()`, otherwise the pending action will be dispatched but no handler will receive it.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Configure App Group storage (must come first)
  await AppIntents().configureStorage(
    appGroupIdentifier: 'group.com.example.app',
  );

  // 1. Register ALL handlers
  initializeCreateTaskAppIntents();
  initializeTaskEntityAppIntents();

  // 2. THEN process pending actions (dispatches to registered handlers)
  AppIntents().processPendingActions();

  // 3. Listen for future pending actions
  AppIntents().pendingActionsStream.listen((_) {
    AppIntents().processPendingActions();
  });

  runApp(MyApp());
}
```

> **Warning**: Do NOT register intent handlers inside widget `initState()` or other lifecycle callbacks when using Cache mode. During cold start, `processPendingActions()` fires before the widget tree is built, so widget-level handlers will not yet be registered. Always register handlers in `main()` before calling `processPendingActions()`.

> **Buffering**: `pendingActionsStream` uses `FlutterEventChannel` with buffered push on the native side, so events arriving before the Dart listener is attached are not lost. However, `onIntentExecution` callbacks registered via `registerIntentHandler` are NOT buffered — if no handler is registered at the time `processPendingActions()` dispatches, the event is dropped silently.

### Updating App Shortcuts Parameters

If you are migrating from another App Intents library (e.g., `intelligence`) that required explicit calls to `AppShortcuts.updateAppShortcutParameters()`, note that this library handles entity updates differently:

- **Entity queries** (`suggestedEntities()` / `entities(for:)`) are called on-demand by the system when the Shortcuts editor or Siri needs entity data. There is no need to explicitly push updates.
- **App Shortcuts** defined via `@AppShortcutsProvider` are registered automatically at app install. The system calls `suggestedEntities()` when it needs fresh data.
- If you need to **force a refresh** of shortcut parameters (e.g., after a user joins a new team), you can call `AppShortcuts.updateAppShortcutParameters()` directly in your Swift code:

```swift
// In your AppDelegate or wherever entity data changes:
if #available(iOS 17.0, *) {
    AppShortcuts.updateAppShortcutParameters()
}
```

This is not auto-generated by the codegen — add it manually in your Swift code where entity data changes occur.

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
