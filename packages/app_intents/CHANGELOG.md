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
