## 0.15.0

- **Fix: on the CocoaPods route the module was named `app_intents_bridge`, so `import AppIntentsBridge` did not resolve (#105).** `app_intents_bridge.podspec` now declares `s.module_name = 'AppIntentsBridge'`, so all three routes take the same import line — the one every `generate_widget_swift` output emits. The old failure was easy to misread: the import itself often reported nothing and only the types surfaced, as `Cannot find 'AppIntentsEntityCache' in scope`. Verified by reading the generated modulemap, which now says `framework module AppIntentsBridge`.
- **`AppIntentsBridge` is now a second product of the plugin's own Swift package** rather than a separate package beside it (#102 follow-up). This is what lets an app that has moved off CocoaPods reach it: Flutter's Swift Package Manager integration symlinks each plugin at `ios/Flutter/ephemeral/Packages/.packages/<plugin_name>`, which is the only stable path a downstream Xcode project can name, and Xcode normalizes local-package paths lexically so a `../` hop out of that symlink does not resolve. The recommended route is now:

  *File → Add Package Dependencies… → Add Local…* → `ios/Flutter/ephemeral/Packages/.packages/app_intents` → add the **`AppIntentsBridge`** library (not `app-intents`, which links Flutter).

  The path needs no Podfile, and it survives `app_intents` upgrades. The CocoaPods pod and the root-manifest `.package(url:)` route are unchanged and still work.

  **Migration**: if you added the package by path in 0.14.0 (`ios/.symlinks/plugins/app_intents/ios/AppIntentsBridge`), re-point it at `ios/Flutter/ephemeral/Packages/.packages/app_intents` and select the `AppIntentsBridge` library. CocoaPods and `.package(url:)` users need no change beyond the version bump.

## 0.14.0

- **Fix: `AppIntentsBridge` could not be reached from a downstream app (#102).** The Swift package now ships **inside this pub package** at `ios/AppIntentsBridge/`, so `import AppIntentsBridge` — which the `generate_widget_swift` output requires — resolves without a separately versioned dependency. Three consumption routes, all building the same sources:
  - **Local Swift package** — add `ios/.symlinks/plugins/app_intents/ios/AppIntentsBridge` via *File → Add Package Dependencies… → Add Local…*.
  - **CocoaPods** — new standalone `app_intents_bridge` podspec (no Flutter dependency, so an App Extension target can take it): `pod 'app_intents_bridge', :path => '.symlinks/plugins/app_intents/ios'`.
  - **Remote Swift package** — the repository root manifest still exposes the same `AppIntentsBridge` product for `.package(url:)`.

  `app_intents.podspec` deliberately does not include these sources, so a target may take both pods without duplicate symbols. Previously the package lived only in the repository's `ios-spm/` subdirectory, which neither pub nor CocoaPods shipped and which SPM cannot resolve over a Git URL.
- Docs: `AppIntentsEntityCacheKey.forEntity` now states that its result is the **cache key**, not the raw `UserDefaults` key — the plugin namespaces it as `app_intents.<storageIdentifier>.cache.<cacheKey>`. Reading with the un-namespaced key returns `nil` silently, which only surfaces as an empty widget configuration picker (#102). Same note added to `docs/usage.md`.

## 0.13.0

- `AppIntentsEntityCacheKey.forEntity` — Dart-side mirror of the App Group cache key used by the persisted-entity fallback, so the key is no longer an undocumented internal string that callers must hand-write (#97). Symmetric with `AppIntentsEntityCache` / `AppIntentsCachedEntity` in the `AppIntentsBridge` Swift package, which lets an App Extension (e.g. a Widget Extension, which cannot start a Flutter engine) read the cached entity list.
- Fixes the iOS podspec version, which was left at `0.11.0` during the 0.12.0 release.

## 0.12.0

- New API `AppIntents().donateIntent(identifier, params)` (#55): wraps `AppIntent.donate()` (stable iOS 16+) so the Dart side can record an executed intent for Siri / Apple Intelligence to learn from. The call is forwarded through `AppIntentsPlugin.intentDonationForwarder` (set in AppDelegate, mirroring `relevantEntitiesDonationForwarder`) to `FlutterBridge.shared.donateIntent`, which invokes the per-intent reverse-executor emitted by `@IntentSpec(donatable: true)` codegen. iOS-only; a no-op on other platforms.
- iOS native:
  - `AppIntentsPlugin.intentDonationForwarder` static hook for AppDelegate wiring. The `donateIntent` MethodChannel case returns `DONATION_NOT_CONFIGURED` when the forwarder is not set.
  - `FlutterBridge.shared.registerIntentDonator(intentIdentifier:_:)` / `donateIntent(intentIdentifier:params:)` / `hasIntentDonator(for:)`; the donators dictionary is cleared by `clearExecutors()` alongside the other executor slots.
- Docs (`docs/usage.md`): adds the `intentDonationForwarder` wiring example next to the existing `relevantEntitiesDonationForwarder` block, plus the matching `register<Intent>Donator()` call site.

## 0.11.0

- WWDC26 experimental bridges (opt-in; exercised only when experimental Swift generation is enabled):
  - IntentValueQuery (#51): `registerValueQueryHandler` + platform `queryValuesAsync` (generic inbound value query; visual variant out of scope).
  - Donations & discovery (#55): `donateRelevantEntities(id, entities, context:)` via a reverse executor, wired through `AppIntentsPlugin.relevantEntitiesDonationForwarder`.
  - Onscreen awareness scaffold (#56): `setOnscreenEntity(typeId, instanceId, title:)` / `clearOnscreenEntity()` backed by `NSUserActivity`, plus `AppIntentsPlugin.onscreenEntityBinder`.
  - Extended the platform interface, method channel, and iOS `AppIntentsPlugin.swift` accordingly.
- Docs: fix the Android setup README (`compileSdk`/`targetSdk` 37, `minSdk` 36 — the previous "36" would fail the `appfunctions:1.0.0-alpha09` AAR-metadata check) and replace the placeholder example app READMEs with real content.

## 0.10.1

- Fix Android build on Kotlin 2.3+ / AGP 9.1.0+: migrate the plugin's `android/build.gradle.kts` from the deprecated `kotlinOptions` DSL to the modern `compilerOptions` DSL (#20, thanks @cpbritton)
  - The `kotlinOptions` block now causes "Script compilation errors" with recent Kotlin Gradle Plugin / AGP toolchains; `compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }` is the supported replacement
- Maintenance: dependency bumps and OSS infrastructure hardening (CI, issue/PR templates, Dependabot)

## 0.10.0

- Add Swift Package Manager (SPM) support for the iOS plugin (#29)
  - New manifest at `ios/app_intents/Package.swift`; native sources moved to `ios/app_intents/Sources/app_intents/` (SPM-standard layout)
  - `app_intents.podspec` now points `source_files`/`resource_bundles` at the shared `Sources/` location, so CocoaPods and SPM build the same files (both remain supported during the transition)
  - Fixes Flutter reporting `app_intents` as "does not support Swift Package Manager" when host apps enable SPM
  - Host apps that enable SPM need Flutter 3.24+ (the minimum for app-side SPM); CocoaPods users are unaffected and the package's `flutter: '>=3.3.0'` constraint is unchanged
  - The privacy manifest is now actually bundled (it was previously present but commented out in the podspec)
- Declare the `NSPrivacyAccessedAPICategoryUserDefaults` required-reason API in `PrivacyInfo.xcprivacy`
  - Reason `CA92.1` (UserDefaults accessible only to the app itself — the `UserDefaults.standard` fallback) and `1C8F.1` (UserDefaults shared within the App Group — `UserDefaults(suiteName:)` used for cross-process cache/EntityQuery data)
  - Required for App Store review of downstream apps that bundle the plugin via SPM or CocoaPods

## 0.9.0

- No plugin API changes; version bump aligns with codegen `0.9.0` which adds EntityQuery cold-start fallback via App Group `UserDefaults` (#26) and the `@AppShortcutsBuilder` annotation in generated Swift (#25)

## 0.8.0

- No plugin API changes; version bump aligns with the AppFunctions alpha09 upgrade in `app_intents_codegen` (#23)
- Note for downstream Android users: bumping the generated Kotlin to alpha09 requires the host app to use AGP 9.1.0+, Gradle 9.3.1+, `compileSdk = 37`, and the `android.newDsl=false` / `android.builtInKotlin=false` shims in `gradle.properties`. See `docs/usage.md` for the full migration.

## 0.7.8

- Fix: Android `AppIntentsPlugin` now handles iOS-only cache methods as no-ops instead of throwing `MissingPluginException` (#22)
  - `getCachedValue`, `setCachedValue`, `clearCachedValue`, `configureStorage`, and `processPendingActions` return `null` on Android
  - Prevents silent failures in release builds where `PlatformDispatcher.onError` may swallow the exception
  - Cross-platform callers no longer need to wrap each invocation in try-catch or guard with `Platform.isIOS`

## 0.7.7

- Fix: Return empty list instead of throwing when entity query handler is not yet registered
  - iOS may issue entity queries (Spotlight indexing, Siri Suggestions) before Dart-side handlers are registered
  - `handleEntityQuery()` and `handleSuggestedEntitiesQuery()` now return `[]` for unregistered entities
  - The next query after handler registration returns real data

## 0.7.6

- Fix: Use App Group UserDefaults to prevent cross-process data resets on iOS
  - App Intents running in extension processes (`WFIsolatedShortcutRunner`) now share storage with the main app
  - Cache key prefix uses stable identifier instead of `Bundle.main.bundleIdentifier` (which differs across processes)
  - Added `synchronize()` after all UserDefaults read/writes for cross-process reliability
  - Added validation and error logging for invalid App Group identifiers
  - Added error logging for JSON serialization/deserialization failures in pending actions
- Add: `configureStorage(appGroupIdentifier:)` API for Dart-side App Group configuration (iOS only, no-op on other platforms)
- Add: `AppIntentsPlugin.configure(appGroupIdentifier:)` static method for Swift-side configuration
- **Note**: Existing cache keys from pre-0.7.6 are preserved when `storageIdentifier` is not set.
  If you use extension processes where `Bundle.main.bundleIdentifier` differs, set
  `storageIdentifier` explicitly in `configure()` to ensure consistent cache key prefixes.

## 0.7.5

- No API changes; version bump to align with codegen bug fix release

## 0.7.4

- No API changes; version bump to align with codegen bug fix release

## 0.7.3

- No API changes; version bump to align with codegen bug fix release

## 0.7.2

- No API changes; version bump to align with codegen bug fix release

## 0.7.1

- No API changes; version bump to align with codegen bug fix release

## 0.7.0

- No API changes; version bump to align with codegen package (xcstrings generation feature)

## 0.6.2

- Fix: Safe casts for all MethodChannel input — prevents crash on malformed native data
- Fix: Pending actions now use a queue (array) instead of single slot — no more silent drops on concurrent intents
- Fix: `processPendingActions()` now processes all queued actions in a loop
- Fix: Sanitize error messages across trust boundary — internal exception details no longer leak to native side
- Fix: Add bundle-ID-qualified prefix for UserDefaults cache keys to avoid namespace collisions
- Add: `FlutterBridge.clearExecutors()` for invalidating stale executors after Flutter engine restart

## 0.6.1

- Documentation fixes: correct outdated code examples and API references

## 0.6.0

- Version bump to align with annotations/codegen packages
- No API changes

## 0.5.2

- No API changes; version bump to align with other packages

## 0.5.1

- No API changes; version bump to align with codegen package

## 0.5.0

- Version bump to align with annotations/codegen packages
- No API changes

## 0.4.0

- Add caching API: `getCachedValue()`, `setCachedValue()`, `clearCachedValue()`
- Add `processPendingActions()` for delivering cached intent actions after Flutter startup
- Add `pendingActionsStream` via FlutterEventChannel for buffered pending action notifications
- iOS Plugin: `setPendingAction()` for caching intent params in UserDefaults
- iOS Plugin: `PendingActionStreamHandler` with thread-safe buffered push
- Fix: Return action data directly from `processPendingActions` instead of nested MethodChannel call

## 0.3.0

- Add Android AppFunctions support via `AppIntentsPlugin.kt`
- Register Android platform in `pubspec.yaml` (`com.example.app_intents`)
- MethodChannel bridge for Android AppFunctions ↔ Flutter communication
- Update documentation for cross-platform support

## 0.2.1

- Fix podspec: update iOS platform from 13.0 to 17.0
- Fix podspec: update Swift version from 5.0 to 5.9
- Documentation updates

## 0.2.0

- **BREAKING**: Raise iOS minimum to 17.0
- No API changes; version bump to align with annotations/codegen packages

## 0.1.0

- Initial release
- Intent handler registration via `registerIntentHandler`
- Entity query handlers via `registerEntityQueryHandler` and `registerSuggestedEntitiesHandler`
- Intent execution stream via `onIntentExecution`
- iOS 17+ App Intents framework integration
