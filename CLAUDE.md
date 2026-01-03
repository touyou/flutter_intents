# Flutter Intents - AI Codebase Guide

## Project Overview

Flutter Intents is a Flutter plugin that bridges iOS App Intents framework, enabling Flutter apps to integrate with Siri, Shortcuts, and Spotlight.

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
| iOS Minimum | **iOS 16** |
| AppShortcutsProvider | **Supported** |
| Handler Registration | **Auto-registration** (code-generated) |
| Localization | **String Catalog** (iOS standard) |
| Error Handling | **Both** (iOS standard + custom) |
| Entity Images | **URL + Asset + SF Symbol** |
| Intent Execution | **URL Scheme** (due to Flutter engine timing) |
| Deep Linking | **app_links** package |

## Implementation Status

### Completed
- `app_intents_annotations`: All annotations defined
  - `@IntentSpec`, `@IntentParam`, `@EntitySpec`, `@EntityId`, `@EntityTitle`, `@EntitySubtitle`, `@EntityImage`, `@EntityDefaultQuery`
  - `@AppShortcut`, `@AppShortcutsProvider`
- `app_intents`: Platform Interface extended
  - `registerIntentHandler`, `registerEntityQueryHandler`, `registerSuggestedEntitiesHandler`
  - `onIntentExecution` stream
  - iOS `AppIntentsPlugin.swift` updated
- `app_intents_codegen`: build_runner integration + Analyzers + Generators
  - `IntentAnalyzer`, `EntityAnalyzer` for annotation parsing
  - `SwiftGenerator`: Generates iOS 16+ AppIntent/AppEntity/AppShortcutsProvider Swift code
  - `DartGenerator`: Generates `initializeXxxAppIntents()` as part files
  - `AppIntentsBuilder` using `PartBuilder` for proper part file generation
  - CLI command: `dart run app_intents_codegen:generate_swift` for Swift file output
  - 70+ tests covering analyzers, generators, and builder
- `ios-spm/AppIntentsBridge`: Swift Package
  - `FlutterBridge` actor for thread-safe communication
  - `AppIntentError`, `EntityImageSource` types
- `app/` Example App: Task management demo
  - `CreateTaskIntentSpec`, `CompleteTaskIntentSpec` intents
  - `TaskEntitySpec` entity with query handler
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

### Pending
- macOS platform support (future)
- Background intent execution without opening app (requires native-only fallback)

## Code Conventions

### TypeChecker API (source_gen 2.0.0)
Use `TypeChecker.fromRuntime(Type)` with import of the annotation type:
```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

const _intentSpecChecker = TypeChecker.fromRuntime(IntentSpec);
```

**Do NOT use** `TypeChecker.fromName()` - it doesn't exist in source_gen 2.0.0.

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

### MethodChannel Type Serialization
MethodChannel only supports specific types. Non-supported types need conversion:

| Dart Type | Swift Type | Serialization |
|-----------|------------|---------------|
| `DateTime` | `Date` | ISO8601 string via `ISO8601DateFormatter()` |
| `DateTime?` | `Date?` | `.map { ISO8601DateFormatter().string(from: $0) }` |

SwiftGenerator automatically handles this conversion in generated code.

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

### Key Integration Points
- **FlutterBridge ↔ AppIntentsPlugin**: Wired via `setIntentExecutor()` in AppDelegate
- **MethodChannel name**: `"app_intents"`
- **Method names**: `executeIntent`, `queryEntities`, `getSuggestedEntities`

### iOS App Integration Steps
1. Copy AppIntentsBridge Swift files to `ios/Runner/AppIntentsBridge/`
2. Run `dart run app_intents_codegen:generate_swift` to generate Swift code
3. Add Swift files to Xcode project (update project.pbxproj)
4. Wire FlutterBridge in AppDelegate:
```swift
import app_intents

// In didFinishLaunchingWithOptions:
if #available(iOS 16.0, *) {
  Task {
    await FlutterBridge.shared.setIntentExecutor { identifier, params in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentsError.channelNotAvailable
      }
      return try await plugin.executeIntentAsync(identifier: identifier, params: params)
    }
  }
}
```
5. Set iOS deployment target to 16.0 in Podfile

## Development Commands

Use the Makefile for common tasks:

```bash
make help       # Show all available commands
make ios        # Build and run Example App on iOS simulator
make ios-build  # Build iOS app only (no run)
make codegen    # Run Dart code generation (build_runner)
make swift-gen  # Generate Swift code from annotations
make test       # Run all tests
make clean      # Clean build artifacts
```

Or use the script directly with options:

```bash
./scripts/run_ios.sh                    # Build and run on simulator
./scripts/run_ios.sh --no-run           # Build only
./scripts/run_ios.sh --release          # Release build
./scripts/run_ios.sh -d <DEVICE_ID>     # Specify device
```

## Running Tests

```bash
# All tests via Makefile
make test

# Or individually:
dart test packages/app_intents_codegen
dart test packages/app_intents_annotations
cd packages/app_intents && flutter test
cd ios-spm/AppIntentsBridge && swift test
```

## Running Analysis

```bash
dart analyze packages/app_intents_codegen/lib
dart analyze packages/app_intents_annotations/lib
cd packages/app_intents && flutter analyze
```

## Generated Swift Code Example

The codegen should produce Swift like:

```swift
import AppIntents

@available(iOS 16.0, *)
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"

    @Parameter(title: "Title")
    var title: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let result = try await FlutterBridge.shared.invoke(
            intent: "CreateTaskIntent",
            params: ["title": title]
        )
        return .result()
    }
}
```

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
class CreateTaskIntentSpec extends IntentSpecBase<CreateTaskInput, Task> {
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

void initializeCreateTaskAppIntents() {
  _registerCreateTaskIntentHandlers();
}

void _registerCreateTaskIntentHandlers() {
  AppIntents().registerIntentHandler('com.example.taskapp.createTask', (params) async {
    final title = params['title'] as String;
    final result = await createTaskIntentHandler(title: title);
    return result.toJson();
  });
}
```

**Note**: Each spec file generates its own `initializeXxxAppIntents()` function. Call all of them in `main.dart`.

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
