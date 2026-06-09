# Flutter Intents — Example App

A task-management demo that showcases the [`app_intents`](../packages/app_intents) plugin
and its code generator end to end: defining intents/entities/enums with annotations,
generating the native iOS (App Intents) and Android (AppFunctions) glue, and wiring the
generated handlers back into a Flutter app.

## What it demonstrates

- **Intents** (`lib/intents/`)
  - `CreateTaskIntentSpec` — URL-scheme execution (`taskapp://create`), with Siri dialog
    feedback and a Shortcuts parameter summary.
  - `CompleteTaskIntentSpec` — URL-scheme execution (`taskapp://complete`) using a
    `TaskEntitySpec` parameter for the entity picker UI.
  - `CreateTaskWithImageIntentSpec` — cache-mode execution (`supportedModes: foreground`)
    with an `IntentFile` (image) parameter.
- **Entity** (`lib/entities/`) — `TaskEntitySpec` with a query handler, suggested-entities
  handler, SF Symbol image, and an App Group cold-start fallback.
- **App Shortcuts** (`lib/shortcuts/`) — `TaskAppShortcuts` exposing Siri phrases via
  `@AppShortcutsProvider`.
- **Model/storage** (`lib/models/`, `lib/repositories/`) — an in-memory `TaskRepository`
  that also projects entity-shaped data into App Group UserDefaults.

Each spec file uses the `part 'xxx.intent.dart';` pattern; the generated part files
(`*.intent.dart`) are committed alongside their specs.

## Running

From the repository root:

```bash
make ios              # build & run on an iOS simulator
make android          # build & run on an Android emulator/device
make codegen          # regenerate Dart part files (build_runner)
make swift-gen        # regenerate iOS Swift (GeneratedAppIntents.swift)
make kotlin-gen       # regenerate Android Kotlin (GeneratedAppFunctions.kt)
```

See [`docs/usage.md`](../docs/usage.md) for the full integration guide (iOS App Groups,
AppDelegate wiring, Android AGP/KSP setup) and [`docs/architecture.md`](../docs/architecture.md)
for the design rationale.
