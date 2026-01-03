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
docs/                         # Documentation
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
- `app_intents_codegen`: build_runner integration + Analyzers
  - `IntentAnalyzer`, `EntityAnalyzer` for annotation parsing
  - `AppIntentsGenerator` builder
- `ios-spm/AppIntentsBridge`: Swift Package
  - `FlutterBridge` actor for thread-safe communication
  - `AppIntentError`, `EntityImageSource` types

### Pending
- `app_intents_codegen`: SwiftGenerator (generate Swift AppIntent/AppEntity code)
- `app_intents_codegen`: DartGenerator (generate handler auto-registration code)
- Integration tests
- Example app completion

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

The codegen should produce Dart like:

```dart
// app_intents.g.dart
void registerIntentHandlers() {
  AppIntents.instance.registerHandler(
    'CreateTaskIntent',
    (params) async {
      final input = CreateTaskInput(
        title: params['title'] as String,
      );
      return await createTaskHandler(input);
    },
  );
}
```
