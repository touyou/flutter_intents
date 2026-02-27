## 0.4.0

- Add caching API: `getCachedValue()`, `setCachedValue()`, `clearCachedValue()`
- Add `processPendingActions()` for delivering cached intent actions after Flutter startup
- iOS Plugin: `setPendingAction()` for caching intent params in UserDefaults

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
