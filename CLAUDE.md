# Flutter Intents - AI Codebase Guide

## Project Overview

Flutter Intents is a Flutter plugin that bridges iOS App Intents and Android AppFunctions frameworks, enabling Flutter apps to integrate with Siri, Shortcuts, Spotlight, and AI agents (Gemini etc.).

## Package Structure

```
packages/
├── app_intents_annotations/  # Dart annotations for Intent/Entity definitions
├── app_intents/              # Flutter plugin (Platform Interface + Method Channel)
└── app_intents_codegen/      # build_runner code generator
packages/app_intents/ios/AppIntentsBridge/
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
| Android AppFunctions | **Jetpack `androidx.appfunctions` 1.0.0-alpha10** (`appfunctions-service` pinned at alpha09 pending Google Maven publish — see Gotchas) |
| Cross-Process Storage (iOS) | **App Group UserDefaults** (explicit configuration required) |
| WWDC26 New APIs | **Opt-in, default OFF** (`#if APP_INTENTS_WWDC26`, dual-branch generation) |
| App Extension entity access | **Read-only App Group cache** via `AppIntentsEntityCache` (`AppIntentsBridge`); no Flutter engine in extensions |
| WidgetConfigurationIntent | **Separate target + separate CLI** (`generate_widget_swift`); cache-only queries |
| `AppIntentsBridge` distribution | **Ships inside the pub package** (`packages/app_intents/ios/AppIntentsBridge`) + standalone `app_intents_bridge.podspec`; root `Package.swift` mirrors it for `.package(url:)` |

## Implementation Status

### Completed
- **App Extension entity access + WidgetConfigurationIntent codegen (#97 / #98)**
  - `AppIntentsEntityCache` / `AppIntentsCachedEntity` in `packages/app_intents/ios/AppIntentsBridge` — read-only public API over the App Group entity cache, importable from a Widget Extension (the package is Flutter-free). `storageIdentifier` is a **required** init argument: an extension's `Bundle.main.bundleIdentifier` is not the host app's, and guessing would silently read the wrong key.
  - Dart-side mirror `AppIntentsEntityCacheKey.forEntity(identifier)` so `setCachedValue` keys are not literals.
  - `@WidgetConfigurationSpec` / `@WidgetParameter` / `WidgetConfigurationSpecBase` + `WidgetConfigurationAnalyzer` + `WidgetSwiftGenerator` → `<Entity>WidgetEntity` (`AppEntity`), `<Entity>WidgetQuery` (`EnumerableEntityQuery`, cache-only), `<Config>` (`WidgetConfigurationIntent`).
  - CLI `dart run app_intents_codegen:generate_widget_swift` (`--app-group` / `--storage-identifier` required, baked into the output) + `make widget-gen`. Output goes to a **separate file for the Widget Extension target only**.
  - `isDiscoverable` defaults to `false`; `defaultResult()` is **not** generated unless `generateDefaultResult: true` (it would bake an add-time snapshot and break the "unconfigured widgets follow the global setting" fallback).
  - Generation-time validation (all of these would otherwise be a silent empty picker or an Xcode-only compile error): unknown entity, entity with no persisted cache, missing `@EntityId`/`@EntityTitle`, a role field that is not `String`/`String?`, a non-id role field named `id`, and configurations sharing an entity that disagree on `generateDefaultResult` (only one query is emitted per entity).
  - Author-supplied strings go through `_swiftLiteral` before being embedded in Swift string literals — an unescaped `"` breaks the build and `\(` is silently reinterpreted as interpolation.
  - Verified: `swiftc -typecheck` of the generated Swift against **both** the stable Xcode 26.5 and Xcode 27 beta 5 iPhoneOS SDKs (with `AppIntentsBridge` built as a module), covering non-`id` `@EntityId`, `defaultResult()`, scalar/optional params and `displayImageName`. See `docs/adr/0005-widget-extension-entity-access.md`.
- **WWDC26 experimental codegen (opt-in, #52 Intent execution control)**
  - `ExperimentalFeatures` config (`lib/src/experimental/experimental_features.dart`): master switch + per-feature set; default OFF reproduces stable output byte-for-byte
  - CLI `generate_swift`: `--experimental-wwdc26` (master) + `--experimental=long-running,app-schema` (per-feature)
  - `@IntentSpec(longRunning:, cancellable:, executionTargets:)` + `IntentExecutionTarget` enum
  - `SwiftGenerator` emits **two struct variants per intent**: WWDC26 form in `#if APP_INTENTS_WWDC26`, stable form in `#else` (so released-SDK builds without the flag still compile)
  - Verified: dual-branch `swiftc -typecheck` green against Xcode 27 beta iOS 27 SDK (with and without `-D APP_INTENTS_WWDC26`)
  - See "WWDC26 Experimental Code Generation" under Code Conventions for the SDK-verified API facts
- **WWDC26 App Schema (#49) + semantic indexing (#50)**
  - `@EntitySpec(schema:)` / `@IntentSpec(schema:)` (e.g. `'messages.message'`) → dual-branch `@AppEntity(schema: .messages.message)` / `@AppIntent(schema: .messages.setMessageReadStatus)` gated by the `app-schema` experimental feature (iOS 27). The entity struct, its query and extensions all move to iOS 27 in the `#if` branch.
  - `@EntityProperty(title:, indexingKey:)` → Swift `@Property(...)`; `indexingKey: 'contentDescription'` emits `@Property(indexingKey: \.contentDescription)` for semantic indexing. **Normal feature (no experimental flag)** gated at `@available(iOS 18.4, *)`.
  - Entities that expose `@Property` get an explicit initializer (the `@Property`/`EntityProperty` wrapper has **no `init(wrappedValue:)`**), with defaults so the role-only construction in the generated query keeps compiling.
  - Verified: dual-branch `swiftc -typecheck` green for schema × indexed × enumerable × `@Property` combinations (stable @ iOS 18.4, experimental @ iOS 27).
- **WWDC26 enum schema (#49) + entity ownership (#55)**
  - `@EnumSpec(schema:)` → dual-branch `@AppEnum(schema: .messages.messageType)` (gated by the `app-schema` feature, iOS 27). The `@AppEnum(schema:)` macro is lenient like the entity/intent variants.
  - `@EntitySpec(ownership:)` (`EntityOwnershipState.unknown/.shared/.public`) → an additive `OwnershipProvidingEntity` conformance extension (`var ownership: EntityOwnership { .shared }`) in its own `#if APP_INTENTS_WWDC26` block (no `#else` — without the flag the entity simply isn't ownership-aware). Gated by the new `ownership` experimental feature (iOS 27).
  - Verified: dual-branch `swiftc -typecheck` green (stable @ iOS 17, experimental @ iOS 27).
- **WWDC26 richer parameter types (#53 — `Duration` + `PersonName` + `EntityCollection` + `@UnionValue`)**
  - **`Duration`**: a Dart `Duration` `@IntentParam` generates a real duration parameter. **By default (and in the `#else` fallback)** it maps to `Measurement<UnitDuration>` (stable SDK; Shortcuts shows a duration picker). With the `rich-types` experimental feature it upgrades to the **native iOS 27 `Duration`** inside `#if APP_INTENTS_WWDC26` (dual-branch). Both branches pre-serialize to a normalized `<field>Micros: Int` local (native via `.components`; `Measurement` via `.converted(to: .seconds).value`); Dart deserializes with `Duration(microseconds:)`.
  - **`PersonName`** (new Dart value type in `app_intents_annotations`, fields `givenName`/`familyName`/`middleName`/`namePrefix`/`nameSuffix`/`nickname`): **default/`#else`** maps to a plain `String` (no `PersonNameComponents` `@Parameter` conformance on the stable SDK), **`rich-types`** upgrades to native iOS 27 `PersonNameComponents`. Both pre-serialize to a normalized `<field>Name: [String: String]` component map (native reads each component; `String` fallback carries only `givenName`); Dart deserializes with `PersonName.fromMap`. URL-scheme mode is degraded (carries `givenName` only as a plain query value — `dart:convert` is unavailable in inherited-import part files).
  - **`EntityCollection`** (`@IntentParam(entityCollectionType: 'PhotoEntity')` on a `List<String>` field): **default/`#else`** maps to a `[Entity]` array (valid since early App Intents), **`rich-types`** upgrades to native iOS 27 `EntityCollection<Entity>`. Both pre-serialize to a normalized `<field>Ids: [String]` (native `.identifiers`; array `.map { $0.id }`); the Dart handler receives a `List<String>` of identifiers (no entity resolution). URL mode comma-joins.
  - **`@UnionValue`** (one intent parameter accepting one of several entity types): declared Dart-side as a `sealed` base class with `@UnionValueSpec(identifier:)` plus one `@UnionCase(entityType:)` subclass per case (each subclass takes a single positional `String id`). The intent param's **field type** being the union sealed class is the signal — no extra `@IntentParam` field; `IntentAnalyzer` resolves the union into `IntentParamInfo.unionInfo`. **`rich-types`** emits a native iOS 27 `@UnionValue enum` (in its own `#if` block, **no `#else`** — the type can't exist on stable) and the intent param dual-branches (`#if` switches over the enum; **`#else` is lossy** — the param degrades to the first case's entity type). Both pre-serialize to `<field>Union: ["_type": <case>, "id": <entityId>]`; Dart deserializes via a generated `<union>FromMap` factory (a `switch` part-file emitted by `AppIntentsGenerator`/`UnionAnalyzer`, matching the pattern-matching skill's ADT idiom). URL mode encodes `<_type>|<id>`.
  - All ride the `rich-types` flag and the shared `nativeRichTypes` branch flag; the native types must never leak into the default/`#else` output (no stable conformance → would not compile). Same `<field>…` normalized-local pattern as IntentFile's `<field>FileInfo`. The Dart Params output is **not** flag-gated (always the same wire), so `build.yaml`/`builder.dart` need no `--experimental` wiring (the union factory part-file is emitted unconditionally by the existing `.intent.dart` PartBuilder).
  - Verified: dual-branch `swiftc -typecheck` green for FlutterBridge + URL `Duration`/`PersonName`/`EntityCollection`/`@UnionValue` intents (fallback @ iOS 17, native @ iOS 27); generated `<union>FromMap` factory + Params output is valid Dart.
- **WWDC26 incremental additions (matsudate review #4, 2026-06-18)**
  - **`AppSchemas.system.searchInApp`** — iOS 17 `.system.search` was renamed to `.system.searchInApp` in iOS 27. New typed accessor on the schema catalog (`SystemSchemas`); the raw iOS 17 string is still reachable via `AppSchemas.of(AppSchemaDomain.system, 'search')`. No codegen change.
  - **`@IntentSpec(donatable: true)`** — `AppIntent.donate()` (stable iOS 16+) via the **reverse-executor pattern** mirroring #55 `RelevantEntities`. Plugin: `AppIntents().donateIntent(identifier, params)` + `AppIntentsPlugin.intentDonationForwarder` (wire in AppDelegate to `FlutterBridge.shared.donateIntent`). Codegen: emits a `#if APP_INTENTS_WWDC26` `register<Intent>Donator()` that reconstructs the concrete intent from `params` and calls `intent.donate()`. **MVP restriction**: parameters must be primitive (`String`/`int`/`double`/`bool`/`DateTime`); entity/file/enum/union/collection params are rejected at codegen time. Gated by `--experimental=donation` for consistency with the rest of #55.
  - **`@IntentParam(useValueState: true)`** — opt in to `IntentParameter.ValueState` (`@available(iOS 18.2, *)` **stable**, **no `#if` gating needed** — SDK spike against Xcode 27 beta `AppIntents.swiftinterface` confirmed `extension IntentParameter { public enum ValueState { case unset; case set(Value) } }` at iOS 18.2). For an optional update parameter, the generated Swift `perform()` adds a sibling `"<field>State": "unset" | "cleared" | "set"` entry to the params dict by reading `$field.valueState` inside an `if #available(iOS 18.2, *)` block (`@unknown default` future-proofs against Swift 6 non-frozen enum errors). Analyzer rejects use on non-optional params. On iOS < 18.2 the state field is absent and the Dart handler treats the param as best-effort optional. No experimental flag — this is a normal feature.
  - All three verified by Dart unit tests; `useValueState` additionally verified by `swiftc -typecheck` against Xcode 27 beta iOS 27 SDK (target iOS 17.0).
- **WWDC26 AppIntentsTesting scaffold (#57, compile-checked)**
  - `app/ios/AppIntentsTests/GeneratedAppIntentsTests.swift` — an `AppIntentsTesting` scaffold for the example app's generated intents/entities (`IntentDefinitions(bundleIdentifier: "com.example.app")` → `.intents["CreateTaskIntentSpec"].makeIntent(title:).run()`, `.entities["TaskEntitySpec"].spotlightQuery()`).
  - **Compile-verified only** (`swiftc -typecheck` against the Xcode 27 beta `AppIntentsTesting.framework`, simulator SDK) — not wired into a test target / not run (running needs the whole example app built under Xcode 27 beta on an iOS 27 simulator; out of scope). Guarded by `#if canImport(AppIntentsTesting)` + `@available(iOS 27.0, *)`, so it is inert on the stable Xcode (verified: typechecks to a no-op there). See `app/ios/AppIntentsTests/README.md` for wiring.
  - `IntentDefinitions` collections are keyed by the **generated Swift struct name** (e.g. `CreateTaskIntentSpec`), not the `@IntentSpec` reverse-DNS `identifier`.
- `app_intents_annotations`: All annotations defined
  - `@IntentSpec` (with `urlScheme`/`urlAction`, `resultDialogTemplate`, `parameterSummary`)
  - `@IntentParam` (with `entityType` for entity picker, `enumType` for AppEnum parameters)
  - `@EntitySpec` (with `persistedCacheKey` for App Group cold-start fallback), `@EntityId`, `@EntityTitle`, `@EntitySubtitle`, `@EntityImage`, `@EntityDefaultQuery`
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
    - App Group UserDefaults fallback in EntityQuery (when `persistedCacheKey` set, or `enumerable`/`indexed` provides a default key) for cold-start resilience
  - `DartGenerator`: Generates `initializeXxxAppIntents()` as part files
    - Generates type-safe `XxxParams` classes with `fromMap()` and `fromQueryParameters()` factories
    - Always registers both `registerEntityQueryHandler` and `registerSuggestedEntitiesHandler`
  - `AppIntentsBuilder` using `PartBuilder` for proper part file generation
  - CLI command: `dart run app_intents_codegen:generate_swift` for Swift file output
  - Three execution modes: URL scheme, cache (foreground), FlutterBridge (background)
  - `IntentFile` parameter support with file serialization code generation
  - `supportedModes` (iOS 26+) + `openAppWhenRun` dual generation for backward compatibility
- `packages/app_intents/ios/AppIntentsBridge`: Swift Package
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
    - `@AppFunction(isDescribedByKDoc = true)` annotated methods
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

- **EntityQuery Cold-Start Fallback (`persistedCacheKey`)**: When the host app is killed by iOS and Siri/Shortcuts triggers an EntityQuery, the Flutter engine may not finish initializing within `FlutterBridge`'s 5-second timeout, causing `entityQueryNotConfigured` errors. To handle this:
  - Set `@EntitySpec(persistedCacheKey: 'your.cache.key')` to make the generated `EntityQuery` read the entity list from App Group UserDefaults before waiting on the Flutter executor.
  - When `persistedCacheKey` is not set but `enumerable: true` or `indexed: true`, codegen falls back to the default key `app_intents.entities.<identifier>`. The Dart side must use that exact string with `setCachedValue`.
  - **Key namespacing**: `persistedCacheKey` is the value you pass to `AppIntents().setCachedValue(key, value)` — not the raw `UserDefaults` key. The plugin namespaces it under `app_intents.<bundleId-or-storageId>.cache.` internally.
  - **Payload shape**: Pass either a JSON-encoded string of `List<Map<String, dynamic>>` or a pre-decoded `List<Map>`. Each map's keys must match the entity's `@EntityId`/`@EntityTitle`/`@EntitySubtitle`/`@EntityImage` field names (not the underlying model's field names — they often differ). Maps missing id or title are silently dropped.
  - **App Group prerequisite**: Same as cache-mode intents — call `AppIntentsPlugin.configure(appGroupIdentifier:)` in AppDelegate and `AppIntents().configureStorage(appGroupIdentifier:)` in Dart. Without this, the EntityQuery extension process and main app cannot share storage and the fallback won't help.
  - **Example**: `app/lib/repositories/task_repository.dart` writes both the full task storage and the entity-shaped projection under `com.example.taskapp.cache.tasks` every time tasks change.

### Future Migration
- **`@Property` wrapper**: Expose entity properties to system (Spotlight, etc.)
- **`@ComputedProperty`** (iOS 26+): Reference underlying data model instead of copying values
- **`TargetContentProvidingIntent`** (iOS 26+): Navigation intents without `perform()` method
- **`AppIntentsPackage`** (iOS 26+): Sharing types across targets (app, extensions, packages)
- **Advanced `IntentMode` submodes**: `.foreground(.immediate)`, `.foreground(.deferred)`, `.foreground(.dynamic)`
- **Multiple modes**: `[.background, .foreground]` with runtime mode determination

### Deferred WWDC26 punch list (matsudate review #4 反映後)

Items surveyed against the matsudate WWDC 2026 review #4 ("新しい Siri と App Intents", 2026-06-18). Each row is a thing the article describes that this plugin does **not** ship yet. ADR numbers in brackets are pre-reserved.

- **`@IntentSpec(resultDialog: IntentDialog(full:supporting:))`** — dual-text dialogs (voice-only `full` vs on-screen `supporting`). Current annotation only takes a single `resultDialogTemplate`. Needs SDK spike against Xcode 27 beta for the exact `IntentDialog` shape + backward-compat decision (deprecate vs add sibling fields). [ADR-0005]
- **`ShowsSnippetView`** — SwiftUI snippet card in Siri results. Flutter doesn't render SwiftUI, so the only viable path is a **declarative template** (title/subtitle/image/key-value) that codegen turns into a fixed `@ViewBuilder`. ADR 0004 already flagged this as a separate-issue spike. Needs a template DSL design before any code. [ADR-0006]
- **`$param.requestValue`** — mid-`perform()` value request. Requires a 2-way suspending RPC: Swift `perform()` suspends → plugin asks Dart for a missing value → Dart returns → `perform()` resumes. Large-scope bridge change; pick Dart-visible vs hidden-inside-generated-Swift first. [ADR-0007]
- **`PlaceDescriptor` export** — `EntityExportKind.placeDescriptor` case for #54 `ValueRepresentation(exporting:)`. ADR 0002 (line 3) explicitly defers this with `IntentPerson` only. Needs `@EntityProperty(role: 'latitude'/'longitude')` (or auto-detect-by-name) + Xcode 27 beta typecheck confirming the `PlaceDescriptor` constructor signature/availability. [extends ADR-0002]
- **`LongRunningIntent` progress + cancellation forwarding to Dart** — the current `performBackgroundTask(...) onCancel: { reason in /* … */ }` is a stub; nothing reaches the Dart handler. Needs (1) progress callback channel Dart→Swift to drive `ProgressReportingIntent.progress`, (2) reverse forwarding of `IntentCancellationReason` Swift→Dart, (3) handler signature change in generated Dart. [ADR-0008]
- **`SyncableEntityIdentifier<Local, Stable>`** (dual-id case) — `SyncableEntity` with stable-id-only is implemented; dual-id is explicitly deferred in ADR 0003 line 159. Changing entity `id` from a scalar to `SyncableEntityIdentifier<Local, Stable>` ripples through entity struct, `EntityQuery.entities(for:)` signature, cache projection, and Dart deserialization. [extends ADR-0003]
- **`@AppIntentsPackage` macro (iOS 26+)** — distinct from already-shipped `allowedExecutionTargets`. Needs SDK spike (signature absent from current verified-facts table) + ADR on scope (per-intent decorator vs package-level marker) + multi-target bundle linking strategy. [ADR-0009]
- **`UNNotificationContent.appEntityIdentifier` / AlarmKit entity tagging** — stable iOS 26+ API (`EntityIdentifier?` on `UNNotificationContent`), so no `#if` gating for the symbol itself, but the bridge wall is identical to #55/#56 (concrete entity type required → reverse-executor pattern reusing a shared `entityIdentifierBinder` forwarder). Document-only for now; would graduate to an ADR alongside #56's on-device PoC. [ADR-0010, blocked on #56]
- **SwiftUI `.appEntityIdentifier(forSelectionType:)` list annotation** — **NO-GO**, locked in ADR 0004. Flutter renders to a single `FlutterView` canvas; per-row PlatformView embedding is architecturally infeasible. Screen-level association via `setOnscreenEntity`/`clearOnscreenEntity` is the supported substitute.

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
- `@AppFunction` is in `androidx.appfunctions.service.AppFunction` (NOT `androidx.appfunctions`) — unchanged as of alpha10, verified by a successful build (see below)
- `@AppFunctionSerializable` is in `androidx.appfunctions.AppFunctionSerializable`
- `AppFunctionContext` is in `androidx.appfunctions.AppFunctionContext`
- Parameter name is `isDescribedByKDoc` (uppercase 'D'); alpha07 and earlier used the lowercase `isDescribedByKdoc`
- KSP compiler cannot handle `Map<String, Any?>` as `@AppFunction` return type — use `String` (JSON)
- KSP version: KSP1 used the `{kotlin-version}-{ksp-version}` concatenation (e.g., `2.2.20-2.0.4`); KSP2 (current) uses a standalone version (e.g., `2.3.9`) — match whatever the example app's `settings.gradle.kts` declares
- Three Jetpack artifacts: `appfunctions`, `appfunctions-service`, `appfunctions-compiler`
- **`appfunctions-service` publishing lag (still unresolved as of 2026-08-21)**: the [release notes page](https://developer.android.com/jetpack/androidx/releases/appfunctions) lists `appfunctions-service:1.0.0-alpha10`, but Google Maven had not actually published that artifact yet (`maven-metadata.xml`/`group-index.xml` for `androidx.appfunctions` topped out at alpha09 for `appfunctions-service` while `appfunctions` and `appfunctions-compiler` alpha10 were live) — `:app:mergeDebugAssets` fails to resolve `androidx.appfunctions:appfunctions-service:1.0.0-alpha10`. **Fix**: pin `appfunctions-service` one version behind (`alpha09`) while bumping `appfunctions`/`appfunctions-compiler` to the new version; re-check Maven before un-pinning. **Re-checked 2026-08-21 (PR #83, closed)**: `appfunctions-service` alpha10 POM still returns HTTP 404 on both `google()` and `mavenCentral` (`maven-metadata.xml` tops out at alpha09), while `appfunctions`/`appfunctions-compiler` alpha10 return 200 — the pin must stay. Verified: `flutter build apk --debug` succeeds with this mixed-version pin and the *existing* `KotlinGenerator` output unchanged — no `@AppFunctionServiceEntryPoint`/service-wrapper migration was actually required for this project's plain `@AppFunction` usage.
- **Kotlin version is gated by the AppFunctions/KSP toolchain — do NOT blindly accept
  Dependabot Kotlin bumps.** The example app pins Kotlin **2.2.20** (KSP `2.3.9`,
  `appfunctions:1.0.0-alpha10`). Bumping to **Kotlin 2.4.0** (released 2026-06-03) failed
  `:app:kspDebugKotlin` when bisected against KSP `2.3.9` + appfunctions **alpha09** with
  `Can't escape identifier `$Android:appDebug_FunctionComponentRegistry` because it
  contains illegal characters: :` — the AppFunctions compiler emits a colon-bearing
  identifier that Kotlin 2.4.0's stricter escaping rejects, inside KSP's `KspAAWorkerAction`
  (Analysis API). At the time of that bisection (PR #48), KSP (2.3.9) and appfunctions
  (alpha09) were the latest releases, so there was no toolchain knob to fix it.
  **Decision rule**: hold/close any Kotlin bump PR until a newer **appfunctions** alpha
  lands; re-test the bump then.

  **Re-tested 2026-08-21 (PR #90, Kotlin 2.4.10) — still broken.** By then both
  preconditions had advanced (appfunctions alpha09 → **alpha10**, KSP 2.3.9 →
  **2.3.11**), so the full "everything latest" combination was testable for the first
  time. Three real `flutter build apk --debug` runs:

  | Kotlin | KSP | appfunctions | Result |
  |---|---|---|---|
  | 2.2.20 | 2.3.9 | alpha10 | ✅ baseline |
  | **2.4.10** | **2.3.11** | alpha10 | ❌ same `Can't escape identifier` failure |
  | 2.2.20 | **2.3.11** | alpha10 | ✅ |

  The third run **isolates the cause to Kotlin 2.4.x, not KSP** — bumping KSP alone is
  safe. So a KSP bump is NOT a reason to re-test a Kotlin bump; only a new **appfunctions**
  alpha (which is what emits the colon-bearing identifier) is.
  (Verified via bisection in PR #48 — the build-script DSL migration below is independent
  and lands fine on 2.2.20.)

### Entity Identifier Consistency
The `entityIdentifier` used in Swift's FlutterBridge calls **must match** the `identifier` from `@EntitySpec` (used in Dart's `registerEntityQueryHandler` / `registerSuggestedEntitiesHandler`). Use `info.identifier` (e.g., `"com.example.taskapp.TaskEntity"`), **not** `info.className` (e.g., `"TaskEntitySpec"`).

### Entity Cache Key Format (public API surface)

The raw App Group `UserDefaults` key is `app_intents.<storageId>.cache.<cacheKey>`,
where `<storageId>` is `configure(storageIdentifier:)` → `Bundle.main.bundleIdentifier`
→ `_appGroupIdentifier` → `"app_intents"`. This format is **duplicated in two
modules on purpose**:

- `AppIntentsPlugin.cachePrefix` (`packages/app_intents/ios/...`) — writes it
- `AppIntentsEntityCache.storageKey(forCacheKey:storageIdentifier:)`
  (`packages/app_intents/ios/AppIntentsBridge`) — reads it, for App Extensions

The plugin cannot depend on `AppIntentsBridge` (it `import Flutter`s; the bridge
must stay linkable from extensions), so **changing the format means changing both**,
and it is a breaking change for any extension. `EntityCacheTests` asserts the
literal string on the bridge side; the plugin carries a cross-reference comment.
The Dart mirror of the *inner* key is `AppIntentsEntityCacheKey.forEntity`.

### AppIntentsBridge lives inside the pub package (#102)

`AppIntentsBridge` is at **`packages/app_intents/ios/AppIntentsBridge/`**, not in
a top-level `ios-spm/` directory. It has to ship inside the published pub
package: the Swift emitted by `generate_widget_swift` opens with
`import AppIntentsBridge`, and a Widget Extension target has no other way to get
the module (it must not link Flutter, so it is outside
`flutter_install_all_ios_pods`).

Three manifests point at that **one** copy of the sources — changing the layout
means changing all three:

| File | Consumer |
|------|----------|
| `packages/app_intents/ios/AppIntentsBridge/Package.swift` | Local SPM (`ios/.symlinks/plugins/app_intents/ios/AppIntentsBridge`) |
| `packages/app_intents/ios/app_intents_bridge.podspec` | CocoaPods (`pod 'app_intents_bridge', :path => '.symlinks/plugins/app_intents/ios'`) |
| `Package.swift` (repo root) | `.package(url:)` — SPM only reads the repository root |

The root manifest is also what CI's `xcodebuild -scheme AppIntentsBridge` builds,
so its `path:` arguments are load-bearing beyond documentation.

`app_intents.podspec` deliberately does **not** include these sources
(`source_files` stays scoped to `app_intents/Sources/app_intents`), so a target
can take both pods without duplicate symbols.

### AppEntity requires an `id` property

`AppEntity` refines `Identifiable`. If the generated struct has no property
literally named `id`, Swift infers `Identifiable.ID == ObjectIdentifier` and the
conformance fails with a confusing `'ObjectIdentifier' does not conform to
'EntityIdentifierConvertible'`. The Dart `@EntityId` field name is arbitrary, so
**both Swift generators normalize it to `id`** via their own `_swiftPropertyName`
helper, and both reject a *non-id* role field named `id`, which would collide
with that rename:

- `WidgetSwiftGenerator` — passes the Dart name separately as the cached-payload
  `idKey:`.
- `SwiftGenerator` (app target) — the Dart name survives only as the
  cache/dictionary key (`dict["teamId"]`), which is what the Dart cache
  projection writes.

When touching `SwiftGenerator`:

- Use `_swiftPropertyName(prop)` for any new site that emits an entity stored
  property, initializer label, or `self.x = x` assignment. Never emit
  `prop.fieldName` directly for the id-role property.
- Sites reading the identifier off a Swift value (`$0.id`, `entity.id`, `team.id`
  in intent param serialization) hardcode `id` — that is correct, not a bug.

Golden string tests passed the entire time this was broken, because they only
assert `contains(...)`. **Verify entity changes with `swiftc -typecheck`.**

### MethodChannel Type Serialization
MethodChannel only supports specific types. Non-supported types need conversion:

| Dart Type | Swift Type | Serialization |
|-----------|------------|---------------|
| `DateTime` | `Date` | ISO8601 string via `ISO8601DateFormatter()` |
| `DateTime?` | `Date?` | `.map { ISO8601DateFormatter().string(from: $0) }` |
| `IntentFile` | `IntentFile` | Write data to temp file, serialize path/mimeType/filename to Map |
| `IntentFile?` | `IntentFile?` | Same, wrapped in `if let` null check |
| `Duration` | `Measurement<UnitDuration>` (default/`#else`) or native `Duration` (`#if`, `rich-types`) | Pre-serialize to `<field>Micros: Int` microseconds; Dart side `Duration(microseconds:)`. See WWDC26 #53. |
| `Duration?` | `Measurement<UnitDuration>?` / `Duration?` | `<field>Micros: Int? = <field>.map { ... }` |
| `PersonName` | `String` (default/`#else`) or native `PersonNameComponents` (`#if`, `rich-types`) | Pre-serialize to `<field>Name: [String: String]` component map; Dart side `PersonName.fromMap`. URL mode carries `givenName` only. See WWDC26 #53. |
| `PersonName?` | `String?` / `PersonNameComponents?` | Nullable component map (`[String: String]?`) |
| `List<String>` + `@IntentParam(entityCollectionType:)` | `[Entity]` (default/`#else`) or native `EntityCollection<Entity>` (`#if`, `rich-types`) | Pre-serialize to `<field>Ids: [String]` (`.map { $0.id }` / `.identifiers`); Dart side `(map[..] as List).cast<String>()`. URL mode comma-joins. See WWDC26 #53. |

SwiftGenerator automatically handles this conversion in generated code.

### Execution Mode Selection
The SwiftGenerator auto-selects the execution mode based on `@IntentSpec` configuration:

| `urlScheme` | `supportedModes` | Mode | `perform()` behavior |
|-------------|-----------------|------|---------------------|
| set | any | URL scheme | Opens URL via `UIApplication.shared.open()` |
| null | `foreground` | Cache | Caches params to UserDefaults, app opens, Flutter reads pending |
| null | null/`background` | FlutterBridge | Direct MethodChannel via `FlutterBridge.shared.invoke()` |

### WWDC26 Experimental Code Generation
New WWDC26 App Intents APIs are emitted **opt-in (default OFF)**. They cannot use
`@available` gating because the symbols **do not exist in the stable SDK at all** —
`@available` only guards the runtime OS version, not symbol existence. So "OFF = do
not emit those lines" is mandatory.

**Flag mechanism** (`ExperimentalFeatures`):
- `--experimental-wwdc26` master switch (OFF → nothing experimental is emitted).
- `--experimental=<flag>` per-feature (`long-running`, `app-schema`, `ownership`,
  `rich-types`, `value-query`, `value-representation`, `donation`). Master ON with no per-feature flag = all features; with flags = only
  those.
- Thread the flag through the **CLI + SwiftGenerator only** until a feature changes
  Dart output (then also wire `build.yaml`/`builder.dart`). #52 is Swift-only.

**Dual-branch emission**: when an intent uses an experimental execution attribute,
`SwiftGenerator` emits two whole structs:
```
#if APP_INTENTS_WWDC26
@available(iOS 27.0, *)
struct Foo: AppIntent, LongRunningIntent, CancellableIntent { ... }   // WWDC26 form
#else
@available(iOS 17.0, *)
struct Foo: AppIntent { ... }                                          // stable fallback
#endif
```
The `#else` is **mandatory**: a user who enables experimental codegen but hasn't set
the `APP_INTENTS_WWDC26` build flag must still get compiling (stable) Swift.

**SDK-verified API facts** (from Xcode 27 beta `.swiftinterface`, not the issue drafts):
- Apple jumped to **year-based versioning**: WWDC26 APIs are **iOS 27**, not iOS 26.
- `LongRunningIntent : ProgressReportingIntent` — **iOS 27.0**; empty protocol;
  `performBackgroundTask(options:operation:)` and `performBackgroundTask(options:operation:onCancel:)`
  (the latter requires `Self: CancellableIntent`) come from an extension. `@discardableResult`.
- `CancellableIntent` — **iOS 26.4**; `withIntentCancellationHandler(operation:onCancel:isolation:)` + `IntentCancellationReason`.
- `IntentExecutionTargets` — **iOS 27.0**; OptionSet with `.main` / `.appIntentsExtension`
  / `.widgetKitExtension` (not `.widget`); used via `static var allowedExecutionTargets`.
- `ProgressReportingIntent.progress` is **extension-provided** (no member to implement).
- **App Schema (#49)** macros `@AppEntity(schema:)` / `@AppIntent(schema:)` / `@AppEnum(schema:)` are **iOS 27** external macros (`AppIntentsMacros`). The macro is lenient: it adds the conformance (`@attached(extension, conformances: AppEntity, …)`) and tolerates a minimal entity body + a redundant explicit `: AppEntity`. Schema-specific properties are optional/synthesized, so an existing generated entity compiles by just prefixing the macro. Schema accessor form is `.<domain>.<schema>` (e.g. `.messages.message`, `.messages.setMessageReadStatus`).
- **Semantic indexing (#50)**: `@Property(indexingKey:)` takes a `PartialKeyPath<CSSearchableItemAttributeSet>` (e.g. `\.contentDescription`) and is **iOS 18.4** (stable SDK, not iOS 27) — so it ships as a normal `@available(iOS 18.4, *)` feature, not behind `#if`. `@Property` ≡ `EntityProperty` (typealias); its bare `init()` is `@available(*, unavailable)`, so always emit at least `@Property(title:)`.
- `IndexedEntityQuery` (re-indexing: `reindexEntities`/`reindexAllEntities`) is iOS 27 (deferred). `@ComputedProperty`/`@DeferredProperty` are iOS 26 macros (deferred).
- **Richer parameter types (#53)**: `Swift.Duration` and `Foundation.PersonNameComponents` gain their `AppIntents._IntentValue` conformance (`extension … : @retroactive …, AppIntents._IntentValue`) **only in the iOS 27 SDK** — absent from the stable SDK (verified by diffing the Xcode 27 beta vs Xcode 26 `.swiftinterface`). So native `Duration`/`PersonNameComponents` params **must** be `#if`-gated (no `@available` — the conformance symbol doesn't exist on stable). `Duration`'s compile-everywhere fallback is `Measurement<UnitDuration>` (has an `IntentParameter` init on both SDKs); `PersonNameComponents` has **no** stable param analog, so its fallback is a plain `String`. `Duration.components` is `(seconds: Int64, attoseconds: Int64)`; 1 µs == 1e12 attoseconds. `@Parameter(title:)` alone is valid for `Duration`, `Measurement<UnitDuration>`, and `PersonNameComponents` (the last rides the generic `_IntentValue` init — there is no PNC-specific initializer). `EntityCollection<Entity>` is **iOS 27**, conforms to `Collection` (`Element == Entity.ID`) and exposes `var identifiers: [Entity.ID]` + `resolvedEntities()`; the stable fallback is a plain `[Entity]` array (`.map { $0.id }`) — done. `@UnionValue`/`AppUnionValue` are **iOS 27** (`AppUnionValue` is `@available(iOS 27)`; the `@UnionValue` macro itself is iOS 18 but attaches the iOS-27 protocol) — a `@UnionValue enum { case x(XEntity) }` switches like a normal enum at the call site (spike-confirmed); done, with a **lossy `#else`** (param degrades to the first case's entity type — no stable union-parameter representation). `AppIntentsTesting.framework` ships in Xcode 27 beta under `<platform>.platform/Developer/Library/Frameworks` (test-bundle framework) for #57.

- **IntentValueQuery (#51, `value-query`)**: `protocol IntentValueQuery : PersistentlyIdentifiable, _SupportsAppDependencies, Sendable` with `associatedtype Input : _IntentValue` — the **input is generic**, not fixed to pixels. For a serializable `Input` (text/structured search) the query is plain inbound and the bridge stays generic (plugin names no iOS-27 symbol); only the generated `<Entity>ValueQuery` struct does, gated by `#if APP_INTENTS_WWDC26` (no `#else` — additive). The visual variant has `Input == SemanticContentDescriptor` (**VisualIntelligence** framework, `pixelBuffer: CVPixelBuffer` + `labels`) → native-only, out of scope here (#58). The bridge added a generic `FlutterBridge.valueQueryExecutor` + `AppIntentsPlugin.queryValuesAsync` + Dart `registerValueQueryHandler`; opt-in via `@EntitySpec(valueQuery: true)`. See `docs/adr/0001-intent-value-query-bridge.md`.

- **Cross-app export (#54, `value-representation`)**: `AppEntity.ValueRepresentation` is a typealias for `IntentValueRepresentation<Item, IntentValue> where Item: Transferable, IntentValue: _IntentValue` with `init(exporting: (Item) async throws -> IntentValue)` (+ a key-path form `ValueRepresentation(exporting: \.prop)` for entities that already hold a system value property). System types conforming include `IntentPerson`, `PlaceDescriptor`, `IntentCurrencyAmount`, `IntentFile`, `EntityCollection`, etc. Export is **system-facing (no Dart round-trip)** → pure Swift codegen, plugin untouched. MVP catalog = `IntentPerson` only, built from the entity's `@EntityId` (`.applicationDefined`) + `@EntityTitle` (`.displayName`) — needs no Dart structured-type representation. `PlaceDescriptor` (needs lat/lon the entity lacks) and the **import** path (reuses #51's value-query bridge) are deferred. Emitted as a `#if APP_INTENTS_WWDC26` `extension <Entity>: Transferable` (no `#else`, additive; `import CoreTransferable` lives inside the `#if`). Opt-in via `@EntitySpec(exportAs: EntityExportType.person)`. See `docs/adr/0002-cross-app-entity-sharing.md`.

- **Donations & discovery (#55, `donation`)**: SDK-verified — `IntentDonationManager` is a struct with `.shared`; `AppIntent.donate() -> IntentDonationIdentifier` (stable iOS 16+); `RelevantEntities.shared.updateEntities(_:for:)` takes an `AppEntityContext` (`.audio(.nowPlaying)`) and is a **stateful overwrite** (empty list clears); `SyncableEntity : AppEntity` (id already-stable → free conformance; dual-id `SyncableEntityIdentifier<Local,Stable>` changes the id type → deferred). This item is **outbound** (Dart triggers a runtime iOS-27 call), which hits two walls: the plugin can't name the iOS-27 symbol (precompiled, `#if` can't reach it) and doesn't know the concrete entity type. Solved with a **reverse executor**: generated `#if`-gated `register<Entity>RelevantEntitiesDonator()` registers a closure on `FlutterBridge` that builds concrete entities and calls `RelevantEntities`; the iOS-27 symbols live only inside that gated closure. Plugin stays dependency-free via `AppIntentsPlugin.relevantEntitiesDonationForwarder` (wired in AppDelegate to `FlutterBridge.shared.donateRelevantEntities`, mirroring the forward executors but reversed). Dart: `AppIntents().donateRelevantEntities(id, entities, context:)`. Implemented: `SyncableEntity` (stable-id) + `RelevantEntities` donation. Deferred: `donate()`/`IntentDonationManager` (intent donation, same plumbing on intents) and dual-id `SyncableEntityIdentifier`. Opt-in via `@EntitySpec(syncable: true)` / `@EntitySpec(relevantEntities: true)`. See `docs/adr/0003-donations-and-discovery.md`.

- **Onscreen awareness (#56, plugin scaffold)**: GO/NO-GO feasibility item. Implemented a **plugin scaffold** (`AppIntents().setOnscreenEntity(typeId, instanceId, title:)` / `clearOnscreenEntity()`) that creates an `NSUserActivity`, sets `targetContentIdentifier` (stable), and `becomeCurrent()`s it. SDK facts: `NSUserActivity.appEntityIdentifier: EntityIdentifier?` (Foundation); `EntityIdentifier(for: Entity.Type, identifier:)` needs the **concrete entity type** (same wall as #55 → would use a reverse executor/`onscreenEntityBinder` wired in AppDelegate). The AppEntity association + on-device PoC are deferred (the ADR gates real adoption on PoC success). Per-view `.appEntityIdentifier` = NO-GO (Flutter has no SwiftUI view tree); custom snippet = declarative-template only (separate issue). No codegen/annotation. See `docs/adr/0004-onscreen-awareness-feasibility.md`.

**How to verify (the load-bearing check)**: golden/unit tests only assert "the strings
I emitted came out"; they pass while emitting Swift that won't compile. Always
`swiftc -typecheck` the generated form **twice** (with and without `-D APP_INTENTS_WWDC26`)
against the beta SDK. Get exact signatures from the SDK directly:
- Doc search via `xcrun mcpbridge` → `DocumentationSearch` (semantic).
- Ground truth: `…/AppIntents.framework/Modules/AppIntents.swiftmodule/arm64e-apple-ios.swiftinterface`.

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
4. `packages/app_intents_codegen/lib/src/cli/analyze_sources.dart` - Surface it to the CLIs
5. `packages/app_intents_codegen/test/` - Add tests

### Widget Extension Codegen (#98)
1. `packages/app_intents_annotations/lib/src/annotations/widget_configuration_spec.dart`
2. `packages/app_intents_codegen/lib/src/analyzer/widget_configuration_analyzer.dart`
3. `packages/app_intents_codegen/lib/src/generator/widget_swift_generator.dart`
4. `packages/app_intents_codegen/bin/generate_widget_swift.dart` - CLI entrypoint
5. `app/ios/TaskWidget/README.md` - Xcode wiring for the example app

### Extending Plugin
1. `packages/app_intents/lib/app_intents_platform_interface.dart` - Add abstract method
2. `packages/app_intents/lib/app_intents_method_channel.dart` - Implement
3. `packages/app_intents/lib/app_intents.dart` - Expose in public API
4. `packages/app_intents/ios/app_intents/Sources/app_intents/AppIntentsPlugin.swift` - iOS implementation
5. `packages/app_intents/test/` - Add tests

### iOS Native (Swift Package)
1. `packages/app_intents/ios/AppIntentsBridge/Sources/AppIntentsBridge/` - Swift source files
2. `packages/app_intents/ios/AppIntentsBridge/Tests/AppIntentsBridgeTests/` - Swift tests
3. `packages/app_intents/ios/AppIntentsBridge/Package.swift` - Package manifest (local, downstream-consumable)
4. `packages/app_intents/ios/app_intents_bridge.podspec` - Standalone pod for the same sources
5. `Package.swift` (repo root) - Mirror manifest so `.package(url:)` resolves

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
1. Add AppIntentsBridge — three equivalent routes, see `docs/usage.md` → "Consuming AppIntentsBridge": local Swift package at `ios/.symlinks/plugins/app_intents/ios/AppIntentsBridge` (recommended), the `app_intents_bridge` pod (`:path => '.symlinks/plugins/app_intents/ios'`), or the remote package `https://github.com/touyou/flutter_intents` → `AppIntentsBridge` product
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
6. Set iOS deployment target to 17.0 in Podfile (beta Xcode 27 rejects < 15.0; the plugin minimum is 17)
7. **(WWDC26 experimental only)** When emitting experimental features, wire the additional bridges in AppDelegate: `setValueQueryExecutor` (#51), `AppIntentsPlugin.relevantEntitiesDonationForwarder` + the generated `register<Entity>RelevantEntitiesDonator()` (#55), and `AppIntentsPlugin.onscreenEntityBinder` (#56). See `docs/usage.md` → "Native wiring for experimental bridges". Gate the iOS-27 ones with `#if APP_INTENTS_WWDC26`.

### Android App Integration Steps
1. Use AGP 9.2.1 / Gradle 9.5.1 (example app's current toolchain; `appfunctions:1.0.0-alpha10` needs AGP 9.1.0+ / Gradle 9.3.1+ at minimum; pin `appfunctions-service` to alpha09 until Google publishes the alpha10 artifact — see Gotchas below)
2. Add KSP plugin to `android/settings.gradle.kts`:
   ```kotlin
   id("com.android.application") version "9.2.1" apply false
   id("org.jetbrains.kotlin.android") version "2.2.20" apply false
   id("com.google.devtools.ksp") version "2.3.9" apply false
   ```
3. Add the following to `android/gradle.properties` (AGP 9 compatibility shims for Flutter + KSP):
   ```properties
   android.newDsl=false
   android.builtInKotlin=false
   ```
4. Configure `android/app/build.gradle.kts`:
   - Apply `kotlin-android` and KSP plugins, set `compileSdk = 37`, `targetSdk = 37`, `minSdk = 36`
   - Add AppFunctions dependencies (`appfunctions`, `appfunctions-service`, `appfunctions-compiler`)
   - Add KSP arg: `ksp { arg("appfunctions:aggregateAppFunctions", "true") }`
   - **Set the JVM target via the `compilerOptions` DSL, not `kotlinOptions`** — the
     legacy `android { kotlinOptions { jvmTarget = ... } }` accessor is an ERROR-level
     deprecation under modern Kotlin Gradle plugins (it fails the build-script
     compilation, not just warns). Use a top-level `kotlin {}` block instead:
     ```kotlin
     import org.jetbrains.kotlin.gradle.dsl.JvmTarget
     // ...
     kotlin {
         compilerOptions {
             jvmTarget = JvmTarget.JVM_17
         }
     }
     ```
5. Run `make kotlin-gen` to generate Kotlin code
6. Wire AppFunctionsBridge in MainActivity:
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
7. Register AppFunctionService in `AndroidManifest.xml`

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
make widget-gen    # Generate Widget Extension Swift (WidgetConfigurationIntent)
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
cd packages/app_intents/ios/AppIntentsBridge && swift test
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

@AppFunctionSerializable(isDescribedByKDoc = true)
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
    @AppFunction(isDescribedByKDoc = true)
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
| Design decisions (bridge/runtime) | `docs/adr/` (ADR; WWDC26 残課題 #51/#54/#55/#56 の設計案) |
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
