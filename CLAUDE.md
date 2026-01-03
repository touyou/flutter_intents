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
  - `DartGenerator`: Generates `initializeAppIntents()` and handler registration code
  - `AppIntentsGenerator` builder (integrates DartGenerator)
  - 70+ tests covering analyzers, generators, and builder
- `ios-spm/AppIntentsBridge`: Swift Package
  - `FlutterBridge` actor for thread-safe communication
  - `AppIntentError`, `EntityImageSource` types

### Pending
- Swift code output to file system (currently DartGenerator is integrated, SwiftGenerator needs file output)
- Integration tests with Example app
- Example app completion
- End-to-end testing with actual iOS device/simulator

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

## Communication Flow (MethodChannel ↔ AppIntentsBridge)

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS App Intents                          │
│  (Siri / Shortcuts / Spotlight)                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │ triggers
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Generated AppIntent struct (from SwiftGenerator)               │
│  └── perform() calls FlutterBridge.shared.invoke()              │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  ios-spm/AppIntentsBridge/FlutterBridge.swift                   │
│  └── actor FlutterBridge (thread-safe singleton)                │
│      └── invoke(intent:params:) → looks up registered handler   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ (currently needs wiring)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  packages/app_intents/ios/Classes/AppIntentsPlugin.swift        │
│  └── executeIntent() → MethodChannel.invokeMethod("executeIntent")
│  └── queryEntities() → MethodChannel.invokeMethod("queryEntities")
│  └── getSuggestedEntities() → MethodChannel.invokeMethod(...)   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ FlutterMethodChannel
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  packages/app_intents/lib/app_intents_method_channel.dart       │
│  └── setMethodCallHandler for "executeIntent", "queryEntities"  │
│  └── Calls registered handlers from registerIntentHandler()    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Generated Dart code (from DartGenerator)                       │
│  └── initializeAppIntents() registers all handlers              │
│  └── User-implemented handler functions are called              │
└─────────────────────────────────────────────────────────────────┘
```

### Key Integration Points
- **FlutterBridge ↔ AppIntentsPlugin**: Currently separate; need to wire FlutterBridge to call AppIntentsPlugin.shared
- **MethodChannel name**: `"app_intents"`
- **Method names**: `executeIntent`, `queryEntities`, `getSuggestedEntities`

## Running Tests

```bash
# Dart packages
dart test packages/app_intents_codegen
dart test packages/app_intents_annotations

# Flutter plugin
cd packages/app_intents && flutter test

# Swift Package
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

The DartGenerator produces code like:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:app_intents/app_intents.dart';

/// Initialize all App Intents handlers.
void initializeAppIntents() {
  _registerIntentHandlers();
  _registerEntityHandlers();
}

void _registerIntentHandlers() {
  AppIntents().registerIntentHandler(
    'com.example.createTask',
    (params) async {
      final title = params['title'] as String;
      final result = await createTaskIntentHandler(title: title);
      return <String, dynamic>{};
    },
  );
}

void _registerEntityHandlers() {
  AppIntents().registerEntityQueryHandler(
    'com.example.TaskEntity',
    (identifiers) async {
      final entities = await taskEntityQuery(identifiers);
      return entities.map((e) => e.toMap()).toList();
    },
  );
}
```

**Note**: User must implement `createTaskIntentHandler()` and `taskEntityQuery()` functions.

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
