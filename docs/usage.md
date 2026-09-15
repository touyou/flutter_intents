# Usage Guide

## Setup

### 1. Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  app_intents: ^0.16.0
  app_intents_annotations: ^0.16.0

dev_dependencies:
  app_intents_codegen: ^0.16.0
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

##### Spoken vs. on-screen text

Siri sometimes only speaks the result and sometimes also shows it. Add
`resultDialogSupportingTemplate` to give those two cases different text — the
spoken line can carry context a reader already gets from the screen:

```dart
@IntentSpec(
  identifier: 'CompleteTaskIntent',
  title: 'Complete Task',
  resultDialogTemplate: 'I marked that task as completed',  // spoken
  resultDialogSupportingTemplate: 'Completed',              // shown on screen
  resultDialogSystemImageName: 'checkmark.circle',          // optional SF Symbol
)
```

This generates `IntentDialog(full:supporting:)`. Both templates support
`{paramName}` interpolation and both land in the String Catalog.

`resultDialogSystemImageName` uses an initializer that is iOS 17.2+, so the
generated Swift builds it behind `if #available(iOS 17.2, *)` and falls back to
the symbol-less dialog — the intent's deployment target stays at iOS 17.0.

Both fields require `resultDialogTemplate`; setting either alone is a code
generation error rather than a silently ignored field.

#### Snippet Card

Siri can show a card next to the result. App Intents renders it with SwiftUI,
which a Flutter app cannot supply, so `@IntentSpec(snippet:)` takes a fixed
layout that the generator turns into a SwiftUI view:

```dart
@IntentSpec(
  identifier: 'com.example.app.taskSummary',
  title: 'Task Summary',
  resultDialogTemplate: 'You have {result.openCount} tasks left',
  snippet: SnippetTemplate(
    title: '{result.headline}',
    subtitle: 'Updated just now',
    systemImageName: 'checklist',
    rows: [
      SnippetRow(label: 'Open', value: '{result.openCount}'),
      SnippetRow(label: 'Done', value: '{result.completedCount}'),
    ],
  ),
)
```

Two kinds of placeholder are available:

| Placeholder | Source | Execution modes |
|---|---|---|
| `{paramName}` | an intent parameter | all |
| `{result.key}` | a key of the Dart handler's returned map | **FlutterBridge only** |

`{result.key}` needs the handler's return value, which only comes back when
`perform()` calls FlutterBridge. A URL scheme or foreground intent hands off to
the app and returns before the handler runs, so using it there is a code
generation error rather than a card that silently renders empty. The same
placeholder works in `resultDialogTemplate`.

For a `{result.…}` intent the generated Dart returns the handler's value
(through `intentResultPayload`, which accepts a `Map`, anything with
`toJson()`, or `null`) instead of discarding it. Handlers for every other
intent are unaffected.

Row labels are literal, so they localize through the String Catalog; values are
interpolated per run. Anything richer than this layout belongs in the app
itself — open it with `openAppWhenRun` instead.

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

## IntentValueQuery (#51) — structured search

> **Not experimental.** `IntentValueQuery` is declared at iOS 26.0 in the
> released SDK, so the query type is generated by default — guarded by
> `@available(iOS 26.0, *)`, with no `#if` and no `--experimental` flag.
> (`--experimental=value-query` is still accepted and reported as a no-op.)

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

## Sharing intents across targets (`AppIntentsPackage`)

To use one set of generated intents from both your app target and an extension
(a widget, for example), put the generated Swift in a **shared Swift package**
that both targets link, rather than compiling the same file into both — two
copies of one intent type duplicate it in `Metadata.appIntents` and iOS then
fails to resolve the intent.

```bash
# the shared package
dart run app_intents_codegen:generate_swift \
  -o ../SharedIntents/Sources/SharedIntents \
  --app-intents-package SharedIntentsPackage

# a consuming target
dart run app_intents_codegen:generate_widget_swift \
  -o ios/TaskWidget/GeneratedIntents \
  --app-group group.com.example.app \
  --storage-identifier com.example.app \
  --app-intents-package TaskWidgetAppIntentsPackage \
  --include-package SharedIntents.SharedIntentsPackage
```

`--include-package` takes a module-qualified type name; the module prefix
becomes an `import`.

**What the declaration does and does not do.** Whether a target sees another
module's intents depends on **how it links**, not on this declaration. Xcode's
SPM links statically by default, and a statically linked dependency's extracted
metadata merges into the consumer with no declaration at all. The declaration
produces the `extract.packagedata` entry that matters across a **dynamic** link
boundary — Apple's guidance is to use an App Intents Package "when referencing
code not compiled into a static library". So if a type is missing from the
metadata, look at target membership and link form; adding or removing
`includedPackages` will not change it.

Two things to keep in mind:

- One `AppIntentsPackage` declaration per target. A duplicate declaration in the
  main target has been observed to break Shortcuts intent routing.
- Keep `@AppShortcutsProvider` in the **app target**, not the shared package —
  moving it into a package yields zero auto shortcuts.

> **Do not declare an App Intents Package for a statically linked setup.**
> A sibling project shipped a build with the declaration and its App Intents
> stopped being ingested **only through App Store / TestFlight installs** — not
> "the shortcut is missing", but the app not appearing in Shortcuts at all,
> while the same build run from Xcode worked. A build bisect pinned it to the
> commit adding the declaration. The declaration's only contribution to the
> shipped bundle is `extract.packagedata`, which holds the **mangled names** of
> `includedPackages` — the one place in App Intents metadata where a type is
> looked up by mangled name at runtime, and the only thing whose failure could
> take down the whole bundle. Distribution builds are also the only ones where
> `STRIP_SWIFT_SYMBOLS` applies.
>
> Since a statically linked target already merges the metadata **without** any
> declaration, adding one there is all risk and no gain. Reach for these flags
> only when you actually cross a dynamic link boundary. (Root cause is pinned
> but the fix is not yet confirmed on TestFlight, so treat this as a strong
> warning rather than a settled fact.)

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
  --experimental=value-representation,donation,long-running,app-schema,ownership,rich-types,reindexing
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
| `rich-types` | Native `Duration` / `PersonNameComponents` / `EntityCollection` / `@UnionValue` params (#53), and union-returning value queries (#133) |
| `value-representation` | Cross-app entity export/import via `ValueRepresentation` (#54, #129) |
| `donation` | `SyncableEntity` (incl. dual id, #132) + `RelevantEntities` donation (#55, #133) |
| `reindexing` | `IndexedEntityQuery` — the system asking your app to re-index an entity (#133) |

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

Exporting as a **place** needs location data the display roles cannot carry, so
mark the fields with `@EntityExportField`:

```dart
@EntitySpec(
  identifier: 'com.example.app.StoreEntity',
  title: 'Store', pluralTitle: 'Stores',
  exportAs: EntityExportType.place,
)
class StoreEntitySpec extends EntitySpecBase<Store> {
  @EntityId final String id;
  @EntityTitle final String name;              // becomes `commonName`
  @EntityExportField(EntityExportRole.latitude) final double? lat;
  @EntityExportField(EntityExportRole.longitude) final double? lng;
  @EntityExportField(EntityExportRole.address) final String? address;
  // …
}
```

A coordinate pair and/or an address is enough — declare whichever you have (a
lone latitude is a generation error). Export fields become ordinary stored
properties on the generated entity and are read back from the same entity
dictionary your queries return, so **include them in your cache projection**;
otherwise the export finds them nil and declines.

This generates a `Transferable` conformance with `ValueRepresentation`. Export
is system-facing (no Flutter round-trip), so no native wiring is required.

**The catalog is fixed by the SDK.** `ValueRepresentation(exporting:)` exists
only for `IntentPerson` and for types conforming to `_SystemIntentValue`. Of the
types you might reach for, that means `PlaceDescriptor` works and
`IntentCurrencyAmount`, `IntentFile` and `EntityCollection` do not — they exist
in the SDK but are not exportable, which is why there is no enum case for them.

### Cross-app entity import (#129)

Add `importable: true` to also accept the system type **from** another app. The
generated `importing:` closure asks Dart which entity the incoming value maps
to, because only your data can answer that:

```dart
@EntitySpec(
  identifier: 'com.example.app.ContactEntity',
  title: 'Contact', pluralTitle: 'Contacts',
  exportAs: EntityExportType.person,
  importable: true,
)
class ContactEntitySpec extends EntitySpecBase<Contact> { /* ... */ }
```

```dart
AppIntents().registerValueImportHandler(
  'com.example.app.ContactEntity',
  (value) async {
    // value['kind'] is 'person' | 'place'; the rest is the flattened value —
    // 'displayName' / 'nameComponents' / 'handle' for a person,
    // 'commonName' / 'address' / 'latitude' / 'longitude' for a place.
    final match = await contacts.findByName(value['displayName'] as String?);
    return match?.toJson();   // null → the import is declined
  },
);
```

Returning `null` makes the generated `importing:` closure throw, which declines
the import instead of inventing an entity. Creating content on the fly is a valid answer too: return the
map of what you just created.

### Donations & discovery (#55)

**SyncableEntity** — set `syncable: true` when the entity's `@EntityId` is
already stable across devices (e.g. a server UUID), so Siri can refer to it
consistently when a conversation moves between devices:

```dart
@EntitySpec(identifier: '…', title: '…', pluralTitle: '…', syncable: true)
```

When the id is **local** and a second, server-assigned id is the stable one, mark
that field with `@EntityStableId` (#132). The generated entity's Swift `id`
becomes `SyncableEntityIdentifier<String, String>`:

```dart
@EntitySpec(identifier: '…', title: '…', pluralTitle: '…', syncable: true)
class DeviceEntitySpec extends EntitySpecBase<Device> {
  @EntityId final String localId;
  @EntityTitle final String name;
  @EntityStableId final String serverId;
  // …
}
```

Because the id type changes, the whole entity and its query dual-branch, and the
query hands your Dart handler **both halves** of every identifier it is asked
about — match on whichever your records are keyed by. A dual-id entity cannot be
used as an `@IntentParam(entityType:)` value (codegen rejects it): the identifier
has no single string form your handler could match.

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

// #133: explicit removal. Without a context these span every context, which an
// empty donation cannot express (it only clears the one context it names).
await AppIntents().removeRelevantEntities(
  'com.example.app.SongEntity', [stale.toJson()]);
await AppIntents().removeAllRelevantEntities('com.example.app.SongEntity');
```

### Long-running intents: progress and cancellation (#130)

`@IntentSpec(longRunning: true, cancellable: true)` gives the intent the system's
progress UI and a cancellation hook. The Dart handler reaches both through
`AppIntentExecution.current` — the handler signature is unchanged, the context is
installed in a `Zone` around the call:

```dart
Future<void> exportTasksHandler({required String format}) async {
  final execution = AppIntentExecution.current;
  for (var i = 0; i < tasks.length; i++) {
    if (execution?.isCancelled ?? false) return;   // cooperative: stop cleanly
    await exportOne(tasks[i]);
    await execution?.reportProgress((i + 1) / tasks.length);
  }
}
```

`current` is null for any intent that did not open an execution scope — every
intent that is neither long-running/cancellable nor has a requestable
parameter, and also the stable `#else` build of a long-running one (progress and
cancellation are iOS 27 symbols). Treat it as optional, as above: on such a
build `execution?.reportProgress(…)` is simply a no-op.

`AppIntents().onIntentCancellation` carries the same notices as a stream, for
tearing down work a handler started and left running.

### Asking the user for a value mid-run (#131)

`@IntentParam(requestValue: true)` lets the handler ask the system to prompt for
an **optional** parameter that the caller left out:

```dart
@IntentSpec(identifier: 'com.example.app.addNote', title: 'Add Note')
class AddNoteIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Note', isOptional: true, requestValue: true)
  final String? note;
  // …
}

Future<void> addNoteHandler({String? note}) async {
  final text = note ?? await AppIntentExecution.current?.requestValue<String>('note');
  // … `perform()` stays suspended until the user answers …
}
```

Only optional parameters qualify — the system already prompts on its own for a
missing required one — and only primitive types (`String`/`int`/`double`/`bool`/
`DateTime`), because the answer travels back over the MethodChannel. Codegen
rejects anything else. This is **not** experimental: `requestValue` is iOS 16, so
it works in both build branches.

### One query answering with several entity types (#133)

An app gets a single `IntentValueQuery` per input type, so a search that should
return more than one kind of entity has to answer with a union. Set
`valueQuery: true` on the union:

```dart
@UnionValueSpec(identifier: 'com.example.app.SearchResult', valueQuery: true)
sealed class SearchResult { const SearchResult(); }

@UnionCase(entityType: 'TaskEntitySpec')
class TaskResult extends SearchResult { final String id; const TaskResult(this.id); }

@UnionCase(entityType: 'ProjectEntitySpec')
class ProjectResult extends SearchResult { final String id; const ProjectResult(this.id); }
```

The Dart handler is registered under the union identifier and tags each result
with `_type` — the `@UnionCase` subclass name — alongside that entity's own
fields:

```dart
AppIntents().registerValueQueryHandler(
  'com.example.app.SearchResult',
  (input) async {
    final query = input['query'] as String? ?? '';
    return [
      for (final t in await tasks.search(query))
        {'_type': 'TaskResult', ...t.toEntityJson()},
      for (final p in await projects.search(query))
        {'_type': 'ProjectResult', ...p.toEntityJson()},
    ];
  },
);
```

Every case's entity must have an `@EntitySpec` in the same generation run — the
query builds the entity from the handler's result, so it needs that entity's
shape.

### Re-indexing an entity on request (#133)

With `indexed: true` and the `reindexing` feature on, the generated query also
conforms to `IndexedEntityQuery`, so the system can ask your app to refresh
Spotlight's copy of an entity. The generated implementation re-reads through the
existing query path (which is what reaches Dart) and hands the result to
`CSSearchableIndex.indexAppEntities` — no extra handler to write.

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

// #130/#131 execution context. Not gated: a requestable parameter is iOS 16,
// and a cancellation can arrive on any build that opened a scope.
AppIntentsPlugin.intentProgressForwarder = { executionId, completed, total in
  try await FlutterBridge.shared.updateProgress(
    executionId: executionId, completed: completed, total: total)
}
AppIntentsPlugin.intentValueRequestForwarder = { executionId, parameter in
  try await FlutterBridge.shared.requestValue(
    executionId: executionId, parameter: parameter)
}
Task {
  await FlutterBridge.shared.setCancellationNotifier { executionId, reason in
    await MainActor.run {
      AppIntentsPlugin.shared?.notifyIntentCancellation(
        executionId: executionId, reason: reason)
    }
  }
}

#if APP_INTENTS_WWDC26
// #55 RelevantEntities donation: forward Dart → the generated donator.
// The `operation` argument is "update" / "remove" / "removeAll" (#133).
AppIntentsPlugin.relevantEntitiesDonationForwarder = { id, operation, entities, context in
  try await FlutterBridge.shared.donateRelevantEntities(
    entityIdentifier: id, operation: operation, entities: entities, context: context)
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

> Verifying generated Swift: run `scripts/verify_experimental_swift.sh`, and run
> it against **both** Xcodes via `DEVELOPER_DIR`. With an Xcode 27 it type-checks
> the output twice — with and without `-D APP_INTENTS_WWDC26` — so the WWDC26 and
> stable fallback forms are both known to compile. With a stable Xcode it checks
> only the non-`#if` branch (the WWDC26 branch names iOS 27 symbols that SDK does
> not have), and that run is what proves an ungated feature compiles without the
> iOS 27 SDK. It type-checks at deployment target iOS 17.0, not the SDK version,
> so a missing `@available` guard fails here instead of in a real app.

## WidgetKit Widget Extensions

### Relevant widget intents (#55)

Tell the system which configured widget intents are worth surfacing in the
Smart Stack right now. Opt the configuration in, then donate from Dart:

```dart
@WidgetConfigurationSpec(
  identifier: 'com.example.app.selectTask',
  title: 'Displayed task',
  relevantIntents: true,
)
class SelectTaskWidgetConfig extends WidgetConfigurationSpecBase { /* ... */ }
```

```dart
await AppIntents().donateRelevantIntents([
  RelevantIntentDonation(
    configurationIdentifier: 'com.example.app.selectTask',
    widgetKind: 'TaskWidget',
    parameters: {'task': 'task-123'},
    relevance: RelevantContextSpec.inferredLocation(InferredLocation.home),
  ),
]);
```

Every call **replaces the app's entire set** — pass the full list each time, and
an empty list to clear it. That is the shape of the underlying
`RelevantIntentManager.updateRelevantIntents`, so donating one at a time would
leave only the last one.

Available contexts: `date`, `dateRange` (the `kind` refinement needs iOS 26),
`inferredLocation` (home / work / school / commute), `sleep`, `fitness` and
`headphonesConnected`. `RelevantContext.location(_ exact: CLRegion)` is
deliberately not offered — a `CLRegion` cannot be rebuilt from a map, so it
would produce donations the system silently drops.

**The generated registration constructs your configuration intent**, so the
target that calls it has to see that type. That is plain Swift module
visibility, unrelated to App Intents metadata: put the generated file in a
module the app and the widget extension both link, rather than compiling it into
each (which duplicates the intent in `Metadata.appIntents`).

Generate that shared copy with `--public` — Swift's default `internal` would
otherwise hide every generated declaration from the importing targets:

```bash
dart run app_intents_codegen:generate_widget_swift \
  -o ../SharedIntents/Sources/SharedIntents \
  --app-group group.com.example.app \
  --storage-identifier com.example.app \
  --public
```

Then wire it up:

```swift
// AppDelegate
if #available(iOS 17.0, *) {
  registerRelevantIntentDonator()   // generated
  AppIntentsPlugin.relevantIntentDonationForwarder = { donations in
    try await FlutterBridge.shared.donateRelevantIntents(donations)
  }
}
```


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
