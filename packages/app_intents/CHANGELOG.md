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
