# Flutter Intents - AI Codebase Guide

## Project Overview

Flutter Intents is a Flutter plugin that bridges iOS App Intents and Android AppFunctions frameworks, enabling Flutter apps to integrate with Siri, Shortcuts, Spotlight, and AI agents (Gemini etc.).

## Package Structure

```
packages/
├── app_intents_annotations/  # Dart annotations for Intent/Entity definitions
├── app_intents/              # Flutter plugin (Platform Interface + Method Channel)
└── app_intents_codegen/      # build_runner code generator
ios-spm/
└── AppIntentsBridge/         # Swift Package for iOS native bridge
app/                          # Example Flutter application
docs/
├── architecture.md           # System architecture and design rationale
├── packages.md               # Package responsibilities and dependencies
└── usage.md                  # User guide and integration instructions
```

## Key Design Decisions

| Decision | Choice |
|----------|--------|
| iOS Minimum | **iOS 17** |
| AppShortcutsProvider | **Supported** |
| Handler Registration | **Auto-registration** (code-generated) |
| Localization | **String Catalog** (iOS standard) |
| Error Handling | **Both** (iOS standard + custom) |
| Entity Images | **URL + Asset + SF Symbol** |
| Intent Execution (iOS) | **URL Scheme** (due to Flutter engine timing) |
| Intent Execution (Android) | **MethodChannel** (in-process, no URL scheme needed) |
| Deep Linking | **app_links** package |
| Android Minimum | **API 36** (Android 16, for AppFunctions) |
| Android AppFunctions | **Jetpack `androidx.appfunctions` 1.0.0-alpha07** |
| Cross-Process Storage (iOS) | **App Group UserDefaults** (explicit configuration required) |

## Implementation Status

### Completed
- `app_intents_annotations`: All annotations defined
  - `@IntentSpec` (with `urlScheme`/`urlAction`, `resultDialogTemplate`, `parameterSummary`)
  - `@IntentParam` (with `entityType` for entity picker, `enumType` for AppEnum parameters)
  - `@EntitySpec`, `@EntityId`, `@EntityTitle`, `@EntitySubtitle`, `@EntityImage`, `@EntityDefaultQuery`
  - `@EnumSpec`, `@EnumCaseDisplay` for AppEnum support
  - `@AppShortcut`, `@AppShortcutsProvider`
- `app_intents`: Platform Interface extended
  - `registerIntentHandler`, `registerEntityQueryHandler`, `registerSuggestedEntitiesHandler`
  - `onIntentExecution` stream
  - Caching API: `getCachedValue`, `setCachedValue`, `clearCachedValue`, `processPendingActions`, `configureStorage`
  - iOS `AppIntentsPlugin.swift`: App Group UserDefaults for cross-process storage, `setPendingAction` for cache mode, `configure(appGroupIdentifier:)` for shared storage
- `app_intents_codegen`: build_runner integration + Analyzers + Generators
  - `IntentAnalyzer`, `EntityAnalyzer`, `EnumAnalyzer`, `ShortcutAnalyzer` for annotation parsing
  - `SwiftGenerator`: Generates iOS 17+ AppIntent/AppEntity/AppEnum/AppShortcutsProvider Swift code
    - URL scheme execution (when `urlScheme` set) or FlutterBridge invocation
    - `IntentResult & ProvidesDialog` for Siri/Shortcuts dialog feedback
    - `ParameterSummary` for Shortcuts UI display
    - Entity parameter types with picker UI support
    - Entity `DisplayRepresentation` with SF Symbol image support
    - AppEnum generation with `typeDisplayRepresentation` and `caseDisplayRepresentations` (with optional image)
    - Entity `displayImageName` for type-level static image (asset bundle `named:`)
    - `EnumerableEntityQuery` extension generation (when `enumerable: true`)
    - `IndexedEntity` extension with `CSSearchableItemAttributeSet` (when `indexed: true`, iOS 26+)
    - AppShortcut phrase `{paramName}` → `\(\.$paramName)` conversion
    - Proper error handling (`throw` instead of silent `return .result()`)
    - FlutterBridge-backed EntityQuery with `entities(for:)` and `suggestedEntities()`
  - `DartGenerator`: Generates `initializeXxxAppIntents()` as part files
    - Generates type-safe `XxxParams` classes with `fromMap()` and `fromQueryParameters()` factories
    - Always registers both `registerEntityQueryHandler` and `registerSuggestedEntitiesHandler`
  - `AppIntentsBuilder` using `PartBuilder` for proper part file generation
  - CLI command: `dart run app_intents_codegen:generate_swift` for Swift file output
  - Three execution modes: URL scheme, cache (foreground), FlutterBridge (background)
  - `IntentFile` parameter support with file serialization code generation
  - `supportedModes` (iOS 26+) + `openAppWhenRun` dual generation for backward compatibility
- `ios-spm/AppIntentsBridge`: Swift Package
  - `FlutterBridge` actor for thread-safe communication
  - `AppIntentError`, `EntityImageSource` types
- `app/` Example App: Task management demo
  - `CreateTaskIntentSpec` (URL scheme: `taskapp://create`, dialog + parameterSummary)
  - `CompleteTaskIntentSpec` (URL scheme: `taskapp://complete`, dialog + parameterSummary)
  - `CreateTaskWithImageIntentSpec` (cache mode: `supportedModes: foreground`, `IntentFile` parameter)
  - `CompleteTask` uses entity parameter (`TaskEntitySpec`) for picker UI
  - `TaskEntitySpec` entity with query handler + suggested entities handler + SF Symbol image
  - `TaskAppShortcuts` with `@AppShortcutsProvider` for Siri shortcuts
  - `Task` model with JSON serialization
  - `TaskRepository` in-memory storage
  - Handlers defined inline with specs (part file pattern)

- iOS Integration Complete:
  - FlutterBridge wired to AppIntentsPlugin via `setIntentExecutor()` closure
  - AppIntentsBridge Swift files copied to `app/ios/Runner/AppIntentsBridge/`
  - Generated Swift code at `app/ios/Runner/GeneratedIntents/GeneratedAppIntents.swift`
  - Xcode project.pbxproj updated with Swift file references
  - iOS build verified successful

- URL Scheme Deep Linking (Phase 3):
  - Intent execution via URL scheme (`taskapp://action?params`)
  - `app_links` package for receiving deep links in Flutter
  - Entity queries still use MethodChannel (work when app is foregrounded)
  - `openAppWhenRun = true` ensures app is launched before intent executes
  - SnackBar feedback for successful intent actions

- Android AppFunctions Integration:
  - `KotlinGenerator`: Generates Android 16+ AppFunctions Kotlin code
    - `@AppFunction(isDescribedByKdoc = true)` annotated methods
    - `@AppFunctionSerializable` data classes for entities
    - `AppFunctionsBridge` singleton for MethodChannel communication
    - `GeneratedAppFunctions` class with no-arg constructor (KSP requirement)
  - Android `AppIntentsPlugin.kt`: MethodChannel bridge (`"app_intents"`)
  - CLI command: `dart run app_intents_codegen:generate_kotlin` for Kotlin file output
  - Example app Gradle configured with KSP and AppFunctions dependencies
  - `MainActivity` wires `AppFunctionsBridge` to plugin's MethodChannel
  - Android APK build verified successful

### Known Limitations
- **Flutter Engine Timing**: Direct MethodChannel calls from App Intents may fail because:
  - App Intents can run in isolated process (`WFIsolatedShortcutRunner`)
  - Flutter engine may not be initialized when intent executes
  - Solution: Use URL scheme to open app, then process action after Flutter is ready

- **Unused Intent Handlers**: With URL scheme approach, the generated Dart `registerIntentHandler` calls are not invoked at runtime:
  - `initializeCreateTaskAppIntents()` and similar register handlers via MethodChannel
  - These handlers are never called because intent execution uses URL scheme instead
  - Entity query handlers (`registerEntityQueryHandler`, `registerSuggestedEntitiesHandler`) are still used
  - Keeping unused handlers is harmless (minimal overhead) and useful for testing

- **Cross-Process Storage Requires App Group**: Cache mode intents running in extension processes (`WFIsolatedShortcutRunner`) require App Group configuration:
  - Without App Group, `UserDefaults.standard` is isolated per process → data appears to "reset"
  - `Bundle.main.bundleIdentifier` differs between main app and extensions → cache key mismatch
  - Solution: Call `AppIntentsPlugin.configure(appGroupIdentifier:)` in both AppDelegate and generated Swift code
  - Dart side: Call `AppIntents().configureStorage(appGroupIdentifier:)` before cache operations

### Future Migration
- **`@Property` wrapper**: Expose entity properties to system (Spotlight, etc.)
- **`@ComputedProperty`** (iOS 26+): Reference underlying data model instead of copying values
- **`TargetContentProvidingIntent`** (iOS 26+): Navigation intents without `perform()` method
- **`AppIntentsPackage`** (iOS 26+): Sharing types across targets (app, extensions, packages)
- **Advanced `IntentMode` submodes**: `.foreground(.immediate)`, `.foreground(.deferred)`, `.foreground(.dynamic)`
- **Multiple modes**: `[.background, .foreground]` with runtime mode determination

### Pending
- macOS platform support (future)
- Background intent execution without opening app (requires native-only fallback)

## Code Conventions

### TypeChecker API (source_gen 2.0.0)
Use `TypeChecker.fromUrl()` with the full package URL:
```dart
const _intentSpecChecker = TypeChecker.fromUrl(
    'package:app_intents_annotations/src/annotations/intent_spec.dart#IntentSpec');
```

**Do NOT use** `TypeChecker.fromName()` or `TypeChecker.fromRuntime()` — the codebase uses `fromUrl()` throughout.

### Deprecation Warnings
Add `// ignore_for_file: deprecated_member_use` for `ClassElement` deprecation warnings in analyzer files.

### Part File Pattern (DartGenerator)
Generated Dart code uses the `part`/`part of` directive pattern:
1. User adds `part 'filename.intent.dart';` to their spec file
2. User imports `package:app_intents/app_intents.dart` in spec file
3. Handler function is defined in the same spec file
4. Generated part file inherits imports and can access the handler

### CLI Swift Generator
Generate Swift code for iOS:
```bash
cd app
dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents
```
Options:
- `-i, --input`: Input directory (default: `lib`)
- `-o, --output`: Output directory (default: `ios/Runner/GeneratedIntents`)
- `-f, --file`: Output filename (default: `GeneratedAppIntents.swift`)
- `--xcstrings`: Output path for .xcstrings String Catalog (optional)
- `-t, --translations`: Path to translations YAML file (optional)
- `--source-language`: Source language code (default: `en`)

### CLI Kotlin Generator
Generate Kotlin code for Android AppFunctions:
```bash
cd app
dart run app_intents_codegen:generate_kotlin \
  -i lib \
  -o android/app/src/main/kotlin/com/example/app/generated \
  -p com.example.app.generated
```
Options:
- `-i, --input`: Input directory (default: `lib`)
- `-o, --output`: Output directory (required)
- `-p, --package`: Kotlin package name (required)
- `-f, --file`: Output filename (default: `GeneratedAppFunctions.kt`)

### Android AppFunctions API Gotchas
- `@AppFunction` is in `androidx.appfunctions.service.AppFunction` (NOT `androidx.appfunctions`)
- `@AppFunctionSerializable` is in `androidx.appfunctions.AppFunctionSerializable`
- `AppFunctionContext` is in `androidx.appfunctions.AppFunctionContext`
- Parameter name is `isDescribedByKdoc` (lowercase 'd'), NOT `isDescribedByKDoc`
- KSP compiler cannot handle `Map<String, Any?>` as `@AppFunction` return type — use `String` (JSON)
- KSP version format: `{kotlin-version}-{ksp-version}` (e.g., `2.2.20-2.0.4`)
- Three Jetpack artifacts: `appfunctions`, `appfunctions-service`, `appfunctions-compiler`

### Entity Identifier Consistency
The `entityIdentifier` used in Swift's FlutterBridge calls **must match** the `identifier` from `@EntitySpec` (used in Dart's `registerEntityQueryHandler` / `registerSuggestedEntitiesHandler`). Use `info.identifier` (e.g., `"com.example.taskapp.TaskEntity"`), **not** `info.className` (e.g., `"TaskEntitySpec"`).

### MethodChannel Type Serialization
MethodChannel only supports specific types. Non-supported types need conversion:

| Dart Type | Swift Type | Serialization |
|-----------|------------|---------------|
| `DateTime` | `Date` | ISO8601 string via `ISO8601DateFormatter()` |
| `DateTime?` | `Date?` | `.map { ISO8601DateFormatter().string(from: $0) }` |
| `IntentFile` | `IntentFile` | Write data to temp file, serialize path/mimeType/filename to Map |
| `IntentFile?` | `IntentFile?` | Same, wrapped in `if let` null check |

SwiftGenerator automatically handles this conversion in generated code.

### Execution Mode Selection
The SwiftGenerator auto-selects the execution mode based on `@IntentSpec` configuration:

| `urlScheme` | `supportedModes` | Mode | `perform()` behavior |
|-------------|-----------------|------|---------------------|
| set | any | URL scheme | Opens URL via `UIApplication.shared.open()` |
| null | `foreground` | Cache | Caches params to UserDefaults, app opens, Flutter reads pending |
| null | null/`background` | FlutterBridge | Direct MethodChannel via `FlutterBridge.shared.invoke()` |

### TDD Approach
Follow Red-Green-Refactor:
1. Write failing test
2. Implement minimum code to pass
3. Refactor while keeping tests green

### Git Commits
Use conventional commit prefixes:
- `feat:` new features
- `test:` test additions
- `fix:` bug fixes
- `refactor:` code improvements
- `docs:` documentation
- `chore:` maintenance

**Important**: Always commit changes BEFORE testing on device/simulator. This ensures:
1. Changes are saved even if testing reveals issues
2. Easy rollback if needed
3. Clear separation between implementation and debug iterations

## Key Files for Each Task

### Adding New Annotations
1. `packages/app_intents_annotations/lib/src/annotations/` - Add annotation class
2. `packages/app_intents_annotations/lib/app_intents_annotations.dart` - Export
3. `packages/app_intents_annotations/test/` - Add tests

### Extending Codegen
1. `packages/app_intents_codegen/lib/src/analyzer/` - Add analyzer
2. `packages/app_intents_codegen/lib/src/generator/` - Add generator
3. `packages/app_intents_codegen/lib/src/builder.dart` - Integrate with builder
4. `packages/app_intents_codegen/test/` - Add tests

### Extending Plugin
1. `packages/app_intents/lib/app_intents_platform_interface.dart` - Add abstract method
2. `packages/app_intents/lib/app_intents_method_channel.dart` - Implement
3. `packages/app_intents/lib/app_intents.dart` - Expose in public API
4. `packages/app_intents/ios/Classes/AppIntentsPlugin.swift` - iOS implementation
5. `packages/app_intents/test/` - Add tests

### iOS Native (Swift Package)
1. `ios-spm/AppIntentsBridge/Sources/AppIntentsBridge/` - Swift source files
2. `ios-spm/AppIntentsBridge/Tests/AppIntentsBridgeTests/` - Swift tests
3. `ios-spm/AppIntentsBridge/Package.swift` - Package manifest

## Communication Flow

### Intent Execution (URL Scheme Approach)

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS App Intents                          │
│  (Siri / Shortcuts / Spotlight)                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │ triggers
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Generated AppIntent struct                                     │
│  └── perform() opens URL: taskapp://action?params               │
│  └── openAppWhenRun = true ensures app launches                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │ UIApplication.shared.open(url)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Flutter App (via app_links package)                            │
│  └── AppLinks().uriLinkStream receives URL                      │
│  └── Parse action and parameters from URL                       │
│  └── Execute business logic (e.g., create/complete task)        │
└─────────────────────────────────────────────────────────────────┘
```

### Intent Execution (Cache Approach)

Used when `supportedModes: foreground` is set without `urlScheme`.
Supports `IntentFile` parameters (file/image data).

```
Siri/Shortcuts → AppIntent.perform()
  → Serialize params (including IntentFile → temp file)
  → AppIntentsPlugin.setPendingAction(identifier, params)
  → return .result()
  → supportedModes: .foreground → iOS opens the app
  → Flutter engine starts → plugin registers → handlers register
  → processPendingActions() checks UserDefaults
  → Pending action found → executeIntent via MethodChannel
  → Existing handler receives params (transparent)
```

### Entity Queries (MethodChannel Approach)

Entity queries (for parameter pickers) still use MethodChannel because
they only run when the app is foregrounded via `openAppWhenRun = true`.

```
┌─────────────────────────────────────────────────────────────────┐
│  EntityQuery.suggestedEntities() / entities(for:)               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  FlutterBridge.shared.queryEntities/suggestedEntities           │
│  └── Waits up to 5 seconds for executor to be set               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  AppIntentsPlugin (MethodChannel)                               │
│  └── queryEntitiesAsync() / getSuggestedEntitiesAsync()         │
│  └── @MainActor ensures main thread execution                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Dart handlers (registered via initializeXxxAppIntents)         │
└─────────────────────────────────────────────────────────────────┘
```

### Android AppFunctions (MethodChannel Approach)

Android AppFunctions run in-process, so MethodChannel works directly (no URL scheme needed).

```
┌─────────────────────────────────────────────────────────────────┐
│  AI Agent (Gemini etc.) → AppFunctionService (KSP-generated)    │
└──────────────────────────┬──────────────────────────────────────┘
                           │ invokes
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  GeneratedAppFunctions.createTask()                             │
│  └── @AppFunction annotated suspend method                      │
└──────────────────────────┬──────────────────────────────────────┘
                           │ delegates to
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  AppFunctionsBridge.getInstance().executeIntent()                │
│  └── Singleton, initialized with MethodChannel from plugin      │
└──────────────────────────┬──────────────────────────────────────┘
                           │ MethodChannel invokeMethod
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  AppIntentsPlugin (MethodChannel "app_intents")                 │
│  └── executeIntent → Dart _intentHandlers[identifier]           │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Dart handlers (registered via initializeXxxAppIntents)         │
└─────────────────────────────────────────────────────────────────┘
```

### Key Integration Points
- **iOS: FlutterBridge ↔ AppIntentsPlugin**: Wired via `setIntentExecutor()`, `setEntityQueryExecutor()`, and `setSuggestedEntitiesExecutor()` in AppDelegate
- **Android: AppFunctionsBridge ↔ AppIntentsPlugin**: Wired via `AppFunctionsBridge.initialize(channel)` in MainActivity
- **MethodChannel name**: `"app_intents"`
- **Method names**: `executeIntent`, `queryEntities`, `getSuggestedEntities`

### iOS App Integration Steps
1. Add AppIntentsBridge: either via SPM (`File → Add Package Dependencies` → `https://github.com/touyou/flutter_intents` → `AppIntentsBridge` product) or copy Swift files to `ios/Runner/AppIntentsBridge/`
2. Run `dart run app_intents_codegen:generate_swift` to generate Swift code
3. Add Swift files to Xcode project (update project.pbxproj)
4. Enable App Groups in Xcode (required for cache mode):
   - Select Runner target → Signing & Capabilities → + Capability → App Groups
   - Add identifier (e.g., `group.com.example.app`)
5. Wire FlutterBridge and configure storage in AppDelegate (using `FlutterImplicitEngineDelegate`):
```swift
import app_intents

// In didInitializeImplicitFlutterEngine(_:):
if #available(iOS 17.0, *) {
  // Configure App Group storage (required for cache mode cross-process data sharing)
  AppIntentsPlugin.configure(appGroupIdentifier: "group.com.example.app")

  Task { @MainActor in
    await FlutterBridge.shared.setIntentExecutor { identifier, params in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentError.intentNotFound(identifier)
      }
      return try await plugin.executeIntentAsync(identifier: identifier, params: params)
    }
    await FlutterBridge.shared.setEntityQueryExecutor { entityIdentifier, identifiers in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentError.entityQueryNotConfigured
      }
      return try await plugin.queryEntitiesAsync(
        entityIdentifier: entityIdentifier, identifiers: identifiers)
    }
    await FlutterBridge.shared.setSuggestedEntitiesExecutor { entityIdentifier in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentError.entityQueryNotConfigured
      }
      return try await plugin.getSuggestedEntitiesAsync(entityIdentifier: entityIdentifier)
    }
  }
}
```
6. Set iOS deployment target to 17.0 in Podfile

### Android App Integration Steps
1. Add KSP plugin to `android/settings.gradle.kts`:
   ```kotlin
   id("com.google.devtools.ksp") version "2.2.20-2.0.4" apply false
   ```
2. Configure `android/app/build.gradle.kts`:
   - Apply KSP plugin, set `compileSdk = 36`, `minSdk = 36`
   - Add AppFunctions dependencies (`appfunctions`, `appfunctions-service`, `appfunctions-compiler`)
   - Add KSP arg: `ksp { arg("appfunctions:aggregateAppFunctions", "true") }`
3. Run `make kotlin-gen` to generate Kotlin code
4. Wire AppFunctionsBridge in MainActivity:
```kotlin
import com.example.app_intents.AppIntentsPlugin
import com.example.app.generated.AppFunctionsBridge

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = AppIntentsPlugin.shared
        if (plugin != null) {
            AppFunctionsBridge.initialize(plugin.getChannel())
        }
    }
}
```
5. Register AppFunctionService in `AndroidManifest.xml`

## Development Commands

Use the Makefile for common tasks:

```bash
make help          # Show all available commands
make ios           # Build and run Example App on iOS simulator
make ios-build     # Build iOS app only (no run)
make android       # Build and run Example App on Android emulator/device
make android-build # Build Android APK only (no run)
make codegen       # Run Dart code generation (build_runner)
make swift-gen     # Generate Swift code from annotations
make kotlin-gen    # Generate Kotlin code for Android AppFunctions
make test          # Run all tests
make clean         # Clean build artifacts
```

Or use the scripts directly with options:

```bash
./scripts/run_ios.sh                    # Build and run on iOS simulator
./scripts/run_ios.sh --no-run           # Build only
./scripts/run_ios.sh --release          # Release build
./scripts/run_ios.sh -d <DEVICE_ID>     # Specify device

./scripts/run_android.sh                # Build and run on Android
./scripts/run_android.sh --no-run       # Build APK only
./scripts/run_android.sh --release      # Release build
./scripts/run_android.sh -d <DEVICE_ID> # Specify device
```

## Running Tests

```bash
# All tests via Makefile
make test

# Or individually:
dart test packages/app_intents_codegen
dart test packages/app_intents_annotations
cd packages/app_intents && flutter test
cd app && flutter test
cd ios-spm/AppIntentsBridge && swift test
```

## Running Analysis

```bash
dart analyze packages/app_intents_codegen/lib
dart analyze packages/app_intents_annotations/lib
cd packages/app_intents && flutter analyze
```

## Generated Swift Code Example

The codegen produces Swift with URL scheme execution (when `urlScheme` is set).
Features: `ProvidesDialog` for Siri feedback, `ParameterSummary` for Shortcuts UI,
and proper error handling on URL construction failure.

```swift
import AppIntents
import UIKit

@available(iOS 17.0, *)
struct CreateTaskIntentSpec: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description: IntentDescription =
        IntentDescription("Create a new task in your task list")

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    static var openAppWhenRun: Bool { true }

    static var parameterSummary: some ParameterSummary {
        Summary("Create task \(\.$title)")
    }

    @Parameter(title: "Title", description: "The title of the task")
    var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var components = URLComponents()
        components.scheme = "taskapp"
        components.host = "create"
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "title", value: String(describing: title)))
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else {
            throw AppIntentError.custom(code: "URL_CONSTRUCTION_FAILED", message: "Failed to construct URL for intent")
        }
        await UIApplication.shared.open(url)
        return .result(dialog: .init("Created task \"\(title)\""))
    }
}
```

Without `urlScheme`, FlutterBridge invocation is generated instead (for background execution).

## Generated Dart Code Example

The DartGenerator produces **part files** that integrate with the user's spec files:

**User's spec file** (`create_task_intent.dart`):
```dart
import 'package:app_intents/app_intents.dart';
import 'package:app_intents_annotations/app_intents_annotations.dart';

part 'create_task_intent.intent.dart';  // ← Generated part file

@IntentSpec(
  identifier: 'com.example.taskapp.createTask',
  title: 'Create Task',
)
class CreateTaskIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Title')
  final String title;

  CreateTaskIntentSpec({required this.title});
}

// Handler defined in same file (accessed by generated code)
Future<Task> createTaskIntentHandler({required String title}) async {
  return TaskRepository.instance.createTask(title: title);
}
```

**Generated part file** (`create_task_intent.intent.dart`):
```dart
part of 'create_task_intent.dart';

// GENERATED CODE - DO NOT MODIFY BY HAND

class CreateTaskIntentParams {
  final String title;
  final String? description;
  final DateTime? dueDate;

  const CreateTaskIntentParams({required this.title, this.description, this.dueDate});

  factory CreateTaskIntentParams.fromMap(Map<String, dynamic> map) {
    return CreateTaskIntentParams(
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
    );
  }
  factory CreateTaskIntentParams.fromQueryParameters(Map<String, String> params) {
    return CreateTaskIntentParams(
      title: params['title']!,
      description: params['description'],
      dueDate: params['dueDate'] != null ? DateTime.tryParse(params['dueDate']!) : null,
    );
  }
}

void initializeCreateTaskAppIntents() {
  _registerCreateTaskIntentHandlers();
}

void _registerCreateTaskIntentHandlers() {
  AppIntents().registerIntentHandler('com.example.taskapp.createTask', (params) async {
    final p = CreateTaskIntentParams.fromMap(params);
    await createTaskIntentHandler(title: p.title, description: p.description, dueDate: p.dueDate);
    return <String, dynamic>{};
  });
}
```

**Note**: Each spec file generates its own `initializeXxxAppIntents()` function. Call all of them in `main.dart`.

## Generated Kotlin Code Example

The Kotlin codegen produces AppFunctions code for Android 16+:

```kotlin
package com.example.app.generated

import androidx.appfunctions.AppFunctionContext
import androidx.appfunctions.AppFunctionSerializable
import androidx.appfunctions.service.AppFunction
import io.flutter.plugin.common.MethodChannel

@AppFunctionSerializable(isDescribedByKdoc = true)
data class TaskEntitySpec(
    val id: String,
    val title: String,
    val description: String? = null
)

class GeneratedAppFunctions {
    private val bridge: AppFunctionsBridge
        get() = AppFunctionsBridge.getInstance()

    /**
     * Create a new task in your task list
     *
     * @param appFunctionContext The context for this app function execution.
     * @param title The title of the task
     */
    @AppFunction(isDescribedByKdoc = true)
    suspend fun createTask(
        appFunctionContext: AppFunctionContext,
        title: String
    ): String {
        val params = mutableMapOf<String, Any?>()
        params["title"] = title
        return bridge.executeIntent("com.example.taskapp.createTask", params)
    }
}
```

KSP compiler auto-generates `GeneratedAppFunctionsAppFunctionService` from the `@AppFunction` annotations.

## Knowledge Accumulation Workflow

### After Each Task: Update Documentation

1. **CLAUDE.md** (this file) - For project-wide, persistent knowledge
   - New design decisions → Add to "Key Design Decisions" table
   - New gotchas/conventions → Add to "Code Conventions" section
   - Implementation progress → Update "Implementation Status" section
   - New file patterns → Add to "Key Files for Each Task" section

2. **`.claude/settings.local.json`** - For frequently used commands
   - Add new Bash command patterns as needed (use wildcards)
   - Keep commands minimal and DRY

3. **Memory (via conversation)** - For session-specific context
   - Complex debugging sessions
   - Temporary workarounds

### Progressive Disclosure Structure

CLAUDE.md follows progressive disclosure:
```
Quick Reference (top)     → Project Overview, Package Structure
├── Design Context        → Key Design Decisions, Implementation Status
├── How-To Guides         → Code Conventions, Key Files for Each Task
├── Architecture Deep Dive → Communication Flow diagram
└── Examples (bottom)     → Generated Code Examples
```

When adding new content:
- **Frequent lookups** → Place higher in the file
- **Reference material** → Place lower in the file
- **One-time setup info** → Consider moving to `docs/` instead

### What Goes Where

| Content Type | Location |
|--------------|----------|
| API gotchas (e.g., TypeChecker usage) | CLAUDE.md → Code Conventions |
| Design rationale | `docs/architecture.md` |
| User-facing guides | `docs/usage.md` |
| Package dependencies | `docs/packages.md` |
| Allowed shell commands | `.claude/settings.local.json` |
| Test fixtures/mocks | In-code comments or test files |

### Trigger Points for Updates

Update CLAUDE.md when:
- ✅ A new annotation/analyzer/generator is added
- ✅ A non-obvious API usage pattern is discovered
- ✅ Implementation status changes (pending → completed)
- ✅ A design decision is made or changed
- ✅ Integration between components is clarified

Do NOT update CLAUDE.md for:
- ❌ Routine bug fixes
- ❌ Test-only changes
- ❌ Formatting/style changes
