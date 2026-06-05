## 0.10.1

- No codegen changes; version bump aligns with `app_intents` 0.10.1 (Android `compilerOptions` DSL fix for Kotlin 2.3+ / AGP 9.1.0+, #20)
- Maintenance: dependency bumps (`analyzer`, `source_gen`, `build`, `build_test`, `dart_style`, `test`)

## 0.10.0

- No codegen changes; version bump aligns with `app_intents` 0.10.0 (Swift Package Manager support for the iOS plugin, #29)

## 0.9.0

- Generated Swift `EntityQuery` now reads cached entities from App Group `UserDefaults` before waiting on the Flutter executor, mitigating the cold-start `entityQueryNotConfigured` error when iOS has killed the host app (#26)
- `SwiftGenerator` emits the new App Group fallback path when `@EntitySpec(persistedCacheKey: ...)` is set, or when `enumerable: true` / `indexed: true` provides a default key `app_intents.entities.<identifier>`
- Generated Swift `AppShortcuts` struct now uses the `@AppShortcutsBuilder` result builder annotation per Apple's `AppShortcutsProvider` protocol requirement (#25)

## 0.8.0

- Upgrade `androidx.appfunctions` from `1.0.0-alpha07` to `1.0.0-alpha09` in the example app (#23)
- `KotlinGenerator` now emits `@AppFunction(isDescribedByKDoc = true)` and `@AppFunctionSerializable(isDescribedByKDoc = true)` (uppercase `D`) to match the renamed parameter introduced in alpha08
- **Breaking** for downstream Android hosts: alpha09's AAR metadata requires AGP 9.1.0+, Gradle 9.3.1+, and `compileSdk = 37`. Hosts also need `android.newDsl=false` (Flutter Gradle plugin compatibility) and `android.builtInKotlin=false` (KSP compatibility) in `android/gradle.properties`. Regenerate Kotlin output with `dart run app_intents_codegen:generate_kotlin` after upgrading. See `docs/usage.md` for the full setup.

## 0.7.8

- No codegen changes; version bump to align with plugin fix release (Android cache no-op handlers)

## 0.7.7

- No codegen changes; version bump to align with plugin fix release

## 0.7.6

- No codegen changes; version bump to align with plugin bug fix release (App Group storage fix)

## 0.7.5

- Fix: Kotlin codegen file parameter (`IntentFile`) now includes `mimeType` and `filename` in generated map (#15)
- Docs: Add `waitForPlugin()` pattern explanation with timeout rationale and failure behavior (#16)
- Docs: Document `processPendingActions()` initialization order and cold start race condition (#17)
- Docs: Add `updateAppShortcutParameters()` migration guide for users migrating from other libraries (#18)

## 0.7.4

- Fix: Use `${param}` placeholder format in xcstrings keys for ParameterSummary and AppShortcut phrases (#14)
  - Swift key-path syntax `\(\.$param)` requires `${param}` in xcstrings keys, not `{param}`
  - YAML translations support both `{param}` and `${param}` key formats
- Revert: Remove `LocalizedStringResource` wrapper from `IntentDescription` (unnecessary for localization)

## 0.7.3

- Fix: Wrap `IntentDescription` with `LocalizedStringResource` for proper localization support (#14)

## 0.7.2

- Fix: Escape newlines in Swift `IntentDescription("...")` string literal to prevent compile errors

## 0.7.1

- Fix: Kotlin KDoc multiline description now correctly adds ` * ` prefix to continuation lines
- Fix: Add missing `import AppIntentsBridge` in generated Swift code for FlutterBridge mode and entity queries

## 0.7.0

- Add `.xcstrings` String Catalog generation for iOS localization
  - New `XcstringsGenerator` class collects all localizable strings from annotations
  - Translations YAML file support for multi-language localization
  - Merge mode preserves existing translations when regenerating
  - `{param}` placeholders converted to `%@` / `%1$@` format; `${applicationName}` preserved
- Add CLI options to `generate_swift`: `--xcstrings`, `--translations`, `--source-language`
- Add `yaml` package dependency

## 0.6.2

- Fix: `_toUpperSnakeCase` no longer prepends underscore to uppercase-starting enum names in KotlinGenerator
- Fix: Add missing `return` keyword in `displayRepresentation` for entities without nullable image
- Fix: Deduplicate `generateAppShortcutsProvider` / `_generateShortcutsProviderBody` in SwiftGenerator
- Fix: Simplify `_cleanClassName` to single-pass `Spec` suffix removal
- Fix: Extract `_isNullableParam` helper to eliminate triple-computation in DartGenerator
- Fix: Remove unnecessary intermediate `StringBuffer` in `generateAll`
- Fix: Add temp file cleanup in generated Swift code for FlutterBridge execution mode
- Improve: Analyzer error reporting — `InvalidGenerationSourceError` instead of silent null for missing required fields
- Improve: Fix `_toDisplayTitle` docstring accuracy in EnumAnalyzer
- Improve: Inline `_formatType` dead abstraction in EntityAnalyzer
- Improve: Type `_extractPhrases` parameter as `DartObject?` instead of `dynamic` in ShortcutAnalyzer

## 0.6.1

- Fix: Map `IntentFile`/`IntentFile?` to `String`/`String?` in KotlinGenerator for KSP compatibility (#11)
  - KSP compiler does not support `IntentFile` as `@AppFunction` parameter type
  - File parameters now generate `mapOf("path" to value)` for Dart-side `IntentFile.fromMap()` compatibility
- Documentation fixes: correct outdated code examples and API references

## 0.6.0

- **BREAKING**: Remove `inputType`/`outputType` from `IntentInfo` model
- Generate type-safe `XxxParams` class for each intent with parameters
  - `fromMap(Map<String, dynamic>)` for MethodChannel / cache mode
  - `fromQueryParameters(Map<String, String>)` for URL scheme deep links
  - Supports String, int, double, bool, DateTime, IntentFile types
- Handler registration now uses Params class and always returns empty map
- Remove `_extractTypeArguments()` from IntentAnalyzer

## 0.5.2

- Fix Swift 6 strict concurrency errors in `FlutterBridge.swift` when used as SPM package
  - Add `sending` keyword to all non-Sendable parameters and return types crossing actor boundaries
  - Affects `invoke()`, `queryEntities()`, `suggestedEntities()`, and all executor/handler closures

## 0.5.1

- Add root `Package.swift` so AppIntentsBridge can be fetched via standard SPM from repository URL

## 0.5.0

- Fix AppShortcut phrase `{paramName}` to generate `\(\.$paramName)` Swift syntax
- Add `imageName` support in `@EnumCaseDisplay` code generation (asset bundle image)
- Add `displayImageName` support in `@EntitySpec` for entity `DisplayRepresentation` image
  - Static image via `named:` for entity type, per-instance `@EntityImage` via `systemName:` takes priority
- Add `EnumerableEntityQuery` extension generation when `enumerable: true`
- Add `IndexedEntity` extension generation when `indexed: true` (iOS 26+, `import CoreSpotlight`)
- Update `EnumAnalyzer` to extract `imageName` from `@EnumCaseDisplay`
- Update `EntityAnalyzer` to extract `displayImageName`, `indexed`, `enumerable` from `@EntitySpec`
- 189 tests (28 new tests for all new features)

## 0.4.1

- Widen dependency constraints to resolve conflicts with other codegen packages (e.g., `go_router_builder`)
  - `source_gen: ">=2.0.0 <5.0.0"` (was `^2.0.0`)
  - `analyzer: ">=7.0.0 <11.0.0"` (was `^7.0.0`)
  - `build: ">=2.4.0 <5.0.0"` (was `^2.4.0`)
  - `build_test: ">=2.2.0 <4.0.0"` (was `^2.2.0`)
- Migrate to `TypeChecker.fromUrl()` for compatibility with source_gen 4.x
- Migrate to `LibraryElement.classes`/`.enums` API for compatibility with analyzer 10.x
- Fix nullable `element.name` handling for analyzer 10.x

## 0.4.0

- Add `supportedModes` support in SwiftGenerator
  - Generates `@available(iOS 26.0, *) static var supportedModes: IntentModes { .foreground }`
  - Generates `static var openAppWhenRun: Bool { true }` for backward compatibility
  - Both properties generated when `supportedModes: foreground` or `urlScheme` is set
- Add `IntentFile` parameter support in SwiftGenerator
  - `@Parameter(supportedTypeIdentifiers:)` for file type parameters
  - File serialization code generation (write to temp file, extract path/mimeType/filename)
  - `import UniformTypeIdentifiers` when file params present
- Add cache mode in SwiftGenerator (`_writeCachePerformMethod`)
  - Auto-generated when `supportedModes: foreground` without `urlScheme`
  - Caches params to UserDefaults via `AppIntentsPlugin.setPendingAction()`
  - `processPendingActions()` delivers cached actions via existing `executeIntent` mechanism
- Add `IntentFile.fromMap()` extraction in DartGenerator for file parameters
- Fix: Use `Map.from()` for IntentFile params from MethodChannel (avoid type cast errors)
- Add `IntentModeType` enum and `fileType` field to codegen models
- Update IntentAnalyzer to parse `supportedModes` and `fileType` annotations

## 0.3.0

- Add `KotlinGenerator` for Android AppFunctions code generation
  - `@AppFunction(isDescribedByKdoc = true)` annotated methods
  - `@AppFunctionSerializable` data classes for entities
  - `AppFunctionsBridge` singleton for MethodChannel communication
  - Enum class generation with `fromValue()` companion object
- Add CLI command `generate_kotlin` for Kotlin file output
- Extract shared `analyzeSources()` utility for Swift/Kotlin CLI commands
- 154 tests (38 new Kotlin generator tests)
- Update documentation for cross-platform support

## 0.2.1

- Documentation updates to reflect v0.2.0 features
- No code changes

## 0.2.0

- **BREAKING**: Raise iOS minimum to 17.0
- Add `IntentResult & ProvidesDialog` support via `resultDialogTemplate`
- Add `ParameterSummary` generation via `parameterSummary`
- Add `AppEnum` code generation (`@EnumSpec`, `EnumAnalyzer`, `_generateEnumBody`)
- Add entity image support in `DisplayRepresentation` (SF Symbol icons)
- Add `{applicationName}` to `\(.applicationName)` phrase conversion for AppShortcuts
- Fix AppShortcutsProvider to use Swift result builder pattern (no array literals)
- Fix error handling: `throw AppIntentError.custom(...)` instead of silent `return .result()`
- Fix double-quote escaping in dialog templates
- Fix shortcut `intentIdentifier` to `className` resolution in CLI
- 116 tests covering all analyzers, generators, and builder

## 0.1.0

- Initial release
- `IntentAnalyzer` and `EntityAnalyzer` for annotation parsing
- `ShortcutAnalyzer` for `@AppShortcut` and `@AppShortcutsProvider` support
- `SwiftGenerator` for iOS 17+ App Intent Swift code generation
- `DartGenerator` for handler initialization code generation
- CLI tool `generate_swift` for Swift code output
- Integration with `build_runner` via `AppIntentsBuilder`
