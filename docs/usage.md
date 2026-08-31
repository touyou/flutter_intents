# Usage Guide

## Setup

### 1. Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  app_intents: ^0.15.0
  app_intents_annotations: ^0.15.0

dev_dependencies:
  app_intents_codegen: ^0.15.0
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

`appfunctions:1.0.0-alpha11` requires **Android Gradle Plugin 9.1.0+**, **Gradle 9.3.1+**, and **compileSdk 37**.
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
id("com.android.application") version "9.2.1" apply false
id("org.jetbrains.kotlin.android") version "2.2.20" apply false
id("com.google.devtools.ksp") version "2.3.11" apply false

// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.devtools.ksp")
    id("dev.flutter.flutter-gradle-plugin")
}
dependencies {
    implementation("androidx.appfunctions:appfunctions:1.0.0-alpha11")
    // appfunctions-service was absent from the alpha10 and alpha11 releases; pin at alpha09.
    // If permanently dropped upstream, remove this dependency entirely.
    implementation("androidx.appfunctions:appfunctions-service:1.0.0-alpha09")
    ksp("androidx.appfunctions:appfunctions-compiler:1.0.0-alpha11")
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
distributionUrl=https\://services.gradle.org/distributions/gradle-9.5.1-all.zip
```

> **Note**: AppFunctions requires Android 16 (API 36) or later. The `compileSdk = 37` requirement comes from the `appfunctions:1.0.0-alpha11` AAR metadata.

### 3. iOS Native Setup (AppIntentsBridge)

The `AppIntentsBridge` Swift package provides the native bridge between your
Flutter app and iOS App Intents. It carries **no Flutter dependency**, which is
what lets an App Extension link it (see
[Consuming AppIntentsBridge](#consuming-appintentsbridge) for the extension
case).

#### Consuming AppIntentsBridge

`AppIntentsBridge` is a **second product of the plugin's own Swift package**,
which ships inside the published `app_intents` pub package. Pick whichever route
matches your project; all three build the exact same files, and the first two
are version-locked to the `app_intents` version already in your `pubspec.yaml`.

**A. Local Swift package (recommended)**

Works whether or not your project still uses CocoaPods — it only needs Flutter's
Swift Package Manager support, which is on by default.

1. Run `flutter pub get`, then `flutter build ios` once, so that
   `ios/Flutter/ephemeral/Packages/.packages/` is generated.
2. In Xcode: **File → Add Package Dependencies… → Add Local…**
3. Choose `ios/Flutter/ephemeral/Packages/.packages/app_intents`
4. Add the **`AppIntentsBridge`** library to the target that needs it — a Widget
   Extension target, and/or `Runner`. Do **not** add the `app-intents` library
   to an extension target: that one links Flutter.

That path is stable across `app_intents` upgrades (Flutter regenerates the
symlink in place), so nothing has to be re-pointed when you bump the version.
`ephemeral/` is git-ignored, so a fresh clone needs one `flutter build ios`
before the package resolves in Xcode.

**B. CocoaPods**

A standalone `app_intents_bridge` podspec sits next to the Swift package. Use it
when you want the extension target's dependency managed by CocoaPods:

```ruby
target 'Runner' do
  use_frameworks!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  # ...
end

# Must come AFTER the Runner target block: `.symlinks/plugins` is created by
# `flutter_install_all_ios_pods` during Podfile evaluation.
target 'MyWidgetExtension' do
  use_frameworks!
  pod 'app_intents_bridge', :path => '.symlinks/plugins/app_intents/ios'
end
```

The pod is named `app_intents_bridge` but declares
`module_name = 'AppIntentsBridge'`, so the import is `import AppIntentsBridge`
on this route too — the same line the generated code and the SPM routes use.
(Versions before 0.15.0 omitted that, and CocoaPods exposed the module as
`app_intents_bridge`; see #105.)

The main `app_intents` pod does **not** include these sources, so adding this
pod to the `Runner` target too is safe (no duplicate symbols) — but route A is
usually simpler there, since `Runner` already links the plugin.

**C. Remote Swift package**

If you prefer a Git-pinned dependency, the repository root carries a manifest
with the same `AppIntentsBridge` product:

1. **File → Add Package Dependencies**
2. Enter `https://github.com/touyou/flutter_intents`
3. Select the `AppIntentsBridge` product

Pin it to the tag matching your `app_intents` version (`vX.Y.Z`) — unlike routes
A and B, this dependency is versioned separately from pub.

> **Route B needs a Podfile; route A does not.** `ios/.symlinks/` is created by
> `flutter_install_all_ios_pods` while CocoaPods evaluates your Podfile, and by
> nothing else — a project that has run `pod deintegrate` has no such directory.
> Route A instead uses `ios/Flutter/ephemeral/Packages/.packages/`, which
> Flutter's own Swift Package Manager integration generates, so it keeps working
> after CocoaPods is gone. Route C needs neither, at the cost of versioning the
> dependency separately from pub.

> **Widget Extensions**: the Swift generated by
> `generate_widget_swift` starts with `import AppIntentsBridge`, so the
> extension target needs one of the routes above. Route A or B keeps it in sync
> with the plugin. See
> [WidgetKit Widget Extensions](#widgetkit-widget-extensions).

#### App Groups and AppDelegate wiring

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
@EnumSpec(identifier: 'com.example.taskapp.TaskPriority', title: 'Priority')
enum TaskPriority {
  @EnumCaseDisplay(title: 'High')
  high,
  @EnumCaseDisplay(title: 'Medium')
  medium,
  @EnumCaseDisplay(title: 'Low')
  low,
}
```

Use with `@IntentParam`:

```dart
@IntentParam(title: 'Priority', enumType: 'TaskPriority')
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

Future<void> main() async {
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
Future<void> main() async {
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

## WWDC26 Experimental Features (opt-in)

The codegen can emit WWDC26 App Intents APIs (iOS 26.4 / iOS 27+). Because those
symbols **do not exist in the stable SDK**, they are **opt-in and OFF by
default**, and the generated Swift is wrapped in `#if APP_INTENTS_WWDC26` so you
can also toggle it from build settings. Existing stable output is unchanged.

### Enabling experimental generation

```bash
# Master switch + select features (comma-separated). Master OFF → nothing emitted.
dart run app_intents_codegen:generate_swift \
  --experimental-wwdc26 \
  --experimental=value-query,value-representation,donation,long-running,app-schema,ownership,rich-types
```

To actually compile the emitted WWDC26 form, add `APP_INTENTS_WWDC26` to your
target's **Active Compilation Conditions** (Swift flags) in Xcode. Without it,
the generated `#else` (stable) branch compiles instead — so a project that
enables experimental codegen but hasn't set the flag still builds.

| Flag | Feature |
|------|---------|
| `app-schema` | `@AppEntity/@AppIntent/@AppEnum(schema:)` domain conformance (#49) |
| `ownership` | `OwnershipProvidingEntity` conformance via `@EntitySpec(ownership:)` (#55) |
| `long-running` | `LongRunningIntent` / `CancellableIntent` / execution targets (#52) |
| `rich-types` | Native `Duration` / `PersonNameComponents` / `EntityCollection` / `@UnionValue` params (#53) |
| `value-query` | `IntentValueQuery` structured search (#51) |
| `value-representation` | Cross-app entity export via `ValueRepresentation` (#54) |
| `donation` | `SyncableEntity` + `RelevantEntities` donation (#55) |

### App Schema (#49) — using the catalog

Pass a schema so Siri/Apple Intelligence understands your entity/intent in a
known vocabulary. The library ships a typed catalog so you don't hand-write
magic strings:

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@EntitySpec(
  identifier: 'com.example.app.MessageEntity',
  title: 'Message',
  pluralTitle: 'Messages',
  schema: AppSchemas.messages.message, // == 'messages.message'
)
class MessageEntitySpec extends EntitySpecBase<Message> { /* ... */ }

@IntentSpec(
  identifier: 'com.example.app.sendMessage',
  title: 'Send Message',
  schema: AppSchemas.messages.sendMessage,
)
class SendMessageIntentSpec extends IntentSpecBase { /* ... */ }
```

- `AppSchemaDomain` enumerates the known iOS 27 domains (`messages`, `mail`,
  `photos`, `calendar`, `maps`, `imageGeneration`, `visualIntelligence`, …).
- `AppSchemas.<domain>.<schema>` exposes verified identifiers (currently
  `messages`, `mail`, `photos`, `system`; more added over time).
- The catalog is **not exhaustive** — the system matches by raw string, so any
  `'domain.schema'` value works. For a schema the catalog doesn't name yet:
  `schema: AppSchemas.of(AppSchemaDomain.calendar, 'event')` → `'calendar.event'`.

#### iOS 17 → iOS 27 schema renames

Some system schemas were renamed across OS versions; the catalog exposes the
iOS 27 names. If you target iOS 17 specifically, use `AppSchemas.of` to build
the older identifier yourself.

| iOS 17 raw string | iOS 27 catalog accessor                |
|-------------------|----------------------------------------|
| `system.search`   | `AppSchemas.system.searchInApp`        |

```dart
@IntentSpec(
  identifier: 'com.example.app.search',
  title: 'Search',
  schema: AppSchemas.system.searchInApp, // == 'system.searchInApp' (iOS 27)
)
class SearchInAppIntentSpec extends IntentSpecBase { /* ... */ }
```

### IntentValueQuery (#51) — structured search

For content that is hard to index ahead of time (large, server-side, or
fast-changing), an `IntentValueQuery` receives a search input and returns
matching entities. Opt in per entity with `valueQuery: true` and define a
handler named `<entity>ValueQuery`:

```dart
@EntitySpec(
  identifier: 'com.example.app.ProductEntity',
  title: 'Product',
  pluralTitle: 'Products',
  valueQuery: true,
)
class ProductEntitySpec extends EntitySpecBase<Product> { /* ... */ }

// Handler in the same spec file (receives the system's text query):
Future<List<Product>> productEntityValueQuery(String input) async {
  return ProductRepository.instance.search(input);
}
```

The generated Dart registers the handler automatically. On the native side,
wire the value-query executor (see [Native wiring](#native-wiring-for-experimental-bridges)).
The visual (camera/screenshot, `SemanticContentDescriptor`) variant is **not**
covered here — it is native-only (tracked separately).

### Cross-app entity export (#54)

Export an entity as a system structured type so other apps can receive it.
The MVP exports as `IntentPerson` (built from the entity's id/title):

```dart
@EntitySpec(
  identifier: 'com.example.app.ContactEntity',
  title: 'Contact',
  pluralTitle: 'Contacts',
  exportAs: EntityExportType.person,
)
class ContactEntitySpec extends EntitySpecBase<Contact> { /* ... */ }
```

This generates a `Transferable` conformance with `ValueRepresentation`. Export
is system-facing (no Flutter round-trip), so no native wiring is required.

### Donations & discovery (#55)

**SyncableEntity** — set `syncable: true` when the entity's `@EntityId` is
already stable across devices (e.g. a server UUID), so Siri can refer to it
consistently when a conversation moves between devices:

```dart
@EntitySpec(identifier: '…', title: '…', pluralTitle: '…', syncable: true)
```

**RelevantEntities donation** — set `relevantEntities: true` to generate a
`register<Entity>RelevantEntitiesDonator()` function. Call it once at startup
(see native wiring), then donate from Dart as the user's context changes:

```dart
@EntitySpec(identifier: 'com.example.app.SongEntity', title: '…',
    pluralTitle: '…', relevantEntities: true)
// …
await AppIntents().donateRelevantEntities(
  'com.example.app.SongEntity',
  currentlyPlaying.map((s) => s.toJson()).toList(),
  context: 'audio.nowPlaying', // stateful overwrite; pass [] to clear
);
```

### Onscreen entity awareness (#56)

Bind the primary entity shown on screen to an `NSUserActivity` so Siri can
resolve "this". Call as the user navigates:

```dart
await AppIntents().setOnscreenEntity(
  'com.example.app.TaskEntity', task.id, title: task.title,
);
// when leaving the screen:
await AppIntents().clearOnscreenEntity();
```

This scaffold uses stable APIs (`becomeCurrent` / `targetContentIdentifier`).
The iOS 26+ `appEntityIdentifier` AppEntity association needs the concrete
entity type and is wired in `AppDelegate` (see native wiring); on-device
verification is recommended before relying on it. Per-view annotation
(`.appEntityIdentifier`) is **not supported** for Flutter (no SwiftUI view tree).

### Native wiring for experimental bridges

The new inbound/outbound paths need executors wired in `AppDelegate`, alongside
the existing ones (see [iOS Native Setup](#3-ios-native-setup-appintentsbridge)).
These reference iOS-27 symbols, so gate them with `#if APP_INTENTS_WWDC26`:

```swift
Task { @MainActor in
  // … existing intent/entity/suggested executors …

  // #51 IntentValueQuery
  await FlutterBridge.shared.setValueQueryExecutor { entityIdentifier, input in
    guard let plugin = AppIntentsPlugin.shared else {
      throw AppIntentError.entityQueryNotConfigured
    }
    return try await plugin.queryValuesAsync(entityIdentifier: entityIdentifier, input: input)
  }
}

#if APP_INTENTS_WWDC26
// #55 RelevantEntities donation: forward Dart → the generated donator.
AppIntentsPlugin.relevantEntitiesDonationForwarder = { id, entities, context in
  try await FlutterBridge.shared.donateRelevantEntities(
    entityIdentifier: id, entities: entities, context: context)
}
// Register each entity's generated donator (one call per relevantEntities entity):
if #available(iOS 27.0, *) {
  registerSongEntityRelevantEntitiesDonator()
}

// #55 intent donation (@IntentSpec(donatable: true)): forward Dart → the
// generated per-intent donator. The reverse executor rebuilds the concrete
// intent struct from params and calls `intent.donate()` (stable iOS 16+).
AppIntentsPlugin.intentDonationForwarder = { id, params in
  try await FlutterBridge.shared.donateIntent(
    intentIdentifier: id, params: params)
}
// Register each intent's generated donator (one call per donatable intent):
if #available(iOS 17.0, *) {
  registerCreateTaskIntentSpecDonator()
}

// #56 onscreen association: set appEntityIdentifier from the concrete entity type.
if #available(iOS 26.0, *) {
  AppIntentsPlugin.onscreenEntityBinder = { activity, entityIdentifier, entityId in
    // Map entityIdentifier → your concrete AppEntity type, then:
    // activity.appEntityIdentifier = EntityIdentifier(for: SongEntity.self, identifier: entityId)
  }
}
#endif
```

> Verifying generated Swift: run `scripts/verify_experimental_swift.sh` (needs a
> beta Xcode with the iOS 27 SDK). It type-checks the generated output twice —
> with and without `-D APP_INTENTS_WWDC26` — so both the WWDC26 and stable
> fallback forms are guaranteed to compile.

## WidgetKit Widget Extensions

A Widget Extension **cannot start a Flutter engine**, so the `FlutterBridge`
round-trip that the app target's generated intents use is unavailable there.
Everything an extension needs must come from the **App Group entity cache**
that `app_intents` already persists for the cold-start fallback.

Two pieces support this:

- `AppIntentsEntityCache` — a read-only Swift API for that cache, so
  hand-written extension code never hardcodes the key naming (issue #97).
- `@WidgetConfigurationSpec` — codegen for a `WidgetConfigurationIntent` and
  its cache-backed entity picker, so there is nothing to hand-write at all
  (issue #98).

### Prerequisites

The cache only exists when the app writes it, so:

1. Configure App Groups on **both** the app and the extension target
   (Signing & Capabilities → App Groups), using the same identifier.
2. In the app, call `AppIntentsPlugin.configure(appGroupIdentifier:)` (Swift)
   and `AppIntents().configureStorage(appGroupIdentifier:)` (Dart).
3. Give the entity a persisted cache — `@EntitySpec(enumerable: true)` or an
   explicit `persistedCacheKey:` — and write the entity list from Dart:

   ```dart
   await AppIntents().setCachedValue(
     AppIntentsEntityCacheKey.forEntity('com.example.joinedTeam'),
     jsonEncode(teams.map((t) => {'id': t.id, 'name': t.name}).toList()),
   );
   ```

   `AppIntentsEntityCacheKey.forEntity` produces the same default key codegen
   uses (`app_intents.entities.<identifier>`) — prefer it over a literal.

4. Add `AppIntentsBridge` to the **extension** target — see
   [Consuming AppIntentsBridge](#consuming-appintentsbridge). The extension does
   not inherit the app target's dependencies, and the generated widget Swift
   opens with `import AppIntentsBridge`.

### Reading the cache from hand-written Swift (#97)

With `AppIntentsBridge` added to the Widget Extension target
([routes](#consuming-appintentsbridge)):

```swift
import AppIntentsBridge

let cache = AppIntentsEntityCache(
    appGroupIdentifier: "group.com.example.app",
    storageIdentifier: "com.example.app"  // the HOST APP's bundle identifier
)

let teams = cache.entities(
    forEntityIdentifier: "com.example.joinedTeam",
    idKey: "id",
    titleKey: "name"
)
// -> [AppIntentsCachedEntity] with id / title / subtitle / imageName / values
```

`storageIdentifier` must be the **host app's** bundle identifier (or the
explicit `storageIdentifier` passed to `AppIntentsPlugin.configure`). An
extension's own `Bundle.main.bundleIdentifier` is different
(`com.example.app.MyWidget`) and would namespace the key differently — which is
why the API requires it rather than guessing.

Other members, when you want to read or observe the value yourself:

| Member | Returns |
|--------|---------|
| `AppIntentsEntityCache.defaultCacheKey(forEntityIdentifier:)` | `app_intents.entities.<identifier>` |
| `AppIntentsEntityCache.storageKey(forCacheKey:storageIdentifier:)` | the raw `UserDefaults` key |
| `cache.storageKey(forEntityIdentifier:)` | the raw key, using this reader's storage identifier |
| `cache.entries(forCacheKey:)` | the raw `[[String: Any]]` payload |
| `cache.isAccessible` | `false` when the App Group could not be opened |

> **Cache key ≠ `UserDefaults` key.** `defaultCacheKey(forEntityIdentifier:)`
> (and its Dart mirror `AppIntentsEntityCacheKey.forEntity`) returns the key you
> pass to `setCachedValue` — the plugin namespaces it before writing. The raw
> key is `app_intents.<storageIdentifier>.cache.<cacheKey>`, i.e. for a default
> entity key:
>
> ```text
> app_intents.com.example.app.cache.app_intents.entities.com.example.joinedTeam
> ```
>
> Reading with the un-namespaced key does not error — it silently returns nil,
> and the only symptom is an empty configuration picker. Use
> `storageKey(forCacheKey:storageIdentifier:)`, or just read through
> `entries(forCacheKey:)` / `entities(forCacheKey:)`.

`isAccessible` matters because an empty result is otherwise ambiguous. If the
extension is missing the App Groups entitlement, `UserDefaults(suiteName:)`
returns nil and every read yields `[]` — identical to "the app has not written
anything yet". The reader logs an error in that case; check `isAccessible`
before treating an empty list as normal.


`AppIntentsEntityCache(userDefaults:storageIdentifier:)` takes an already
resolved suite, which is handy in tests.

### Generating the configuration intent (#98)

Declare the configuration in Dart. There is no handler and no `part`
directive — nothing runs in Dart, so no Dart code is generated:

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@WidgetConfigurationSpec(
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
  description: 'Choose which team this widget shows.',
)
class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {
  @WidgetParameter(title: 'Team')
  final TeamEntitySpec? team;

  @WidgetParameter(title: 'Show completed')
  final bool showCompleted;

  const SelectTeamWidgetConfig({this.team, this.showCompleted = false});
}
```

Generate into a directory meant for the extension target:

```bash
cd app && dart run app_intents_codegen:generate_widget_swift \
  -o ios/MyWidget/GeneratedIntents \
  --app-group group.com.example.app \
  --storage-identifier com.example.app
```

| Option | Description |
|--------|-------------|
| `-i, --input` | Input directory (default: `lib`) |
| `-o, --output` | Output directory (required) |
| `-f, --file` | Output filename (default: `GeneratedWidgetIntents.swift`) |
| `--app-group` | App Group identifier (required) |
| `--storage-identifier` | The host app's bundle identifier (required) |

The output contains `<Entity>WidgetEntity` (`AppEntity`),
`<Entity>WidgetQuery` (`EnumerableEntityQuery`, cache-only) and the
`WidgetConfigurationIntent` itself.

> **Add the generated file to the Widget Extension target only.** Including the
> same App Intent type in both the app target and an extension target
> duplicates it in `Metadata.appIntents`, and iOS then fails to resolve the
> intent at runtime. The generated entity is named `<Entity>WidgetEntity`
> rather than reusing the app target's `<Entity>`, so a mistake here surfaces
> as a compile error instead of a silent runtime failure.

The widget itself is not generated (it differs per app):

```swift
struct TeamWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "TeamWidget",
            intent: SelectTeamWidgetConfig.self,
            provider: TeamTimelineProvider()
        ) { entry in
            TeamWidgetView(entry: entry)
        }
    }
}
```

### Two defaults worth knowing

**`isDiscoverable` defaults to `false`.** A configuration intent exists to
configure a widget; surfacing it as a standalone Shortcuts action is usually
noise. Set `isDiscoverable: true` if the intent is genuinely useful on its own.

**`defaultResult()` is not generated by default.** Implementing it pre-fills an
unedited widget instance with a value captured *at the moment the widget was
added*. That is incompatible with the common "unconfigured widgets follow the
app's global setting" fallback: once the value is baked in, changing the in-app
setting no longer moves those widgets. Opt in with
`@WidgetConfigurationSpec(generateDefaultResult: true)` when a
snapshot-at-add-time default is what you want. Otherwise an unconfigured
parameter arrives as `nil`, and the timeline provider decides the fallback. Because only one query is generated per entity, every configuration that
references the same entity must set the same value — codegen rejects a
disagreement instead of letting one configuration silently inherit the other's
behavior.

### Supported parameter types

`String`, `int`, `double`, `bool`, `DateTime` (and their nullable forms), plus
any class annotated with `@EntitySpec`. Entity parameters are always emitted
optional — a required entity blocks the widget from rendering until the user
picks one.

The referenced entity's role fields must be `String` (`@EntitySubtitle` and
`@EntityImage` may be `String?`), because the App Group cache only carries
strings.

Codegen fails with an explicit error when the setup cannot work:

- a referenced entity that is unknown, or that persists no cache
- an entity lacking `@EntityId` / `@EntityTitle`
- a role field whose type is not `String` / `String?`
- a non-id role field literally named `id` (it would collide with the generated
  `Identifiable` property)
- configurations sharing an entity that disagree on `generateDefaultResult`

That is deliberate — most of those cases would otherwise produce a picker that
silently shows no options, or generated Swift that fails to compile in Xcode.

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
