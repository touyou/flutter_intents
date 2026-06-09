# AppIntentsTesting scaffold (WWDC26, issue #57)

`AppIntentsTesting` (WWDC26-295) runs your generated App Intents through the
full App Intents stack — no mocks — inside a standard test bundle. It loads
intent definitions from the **built app** by bundle identifier, so the test
code does not import the app's Swift.

`GeneratedAppIntentsTests.swift` is a **compile-verified scaffold** for the
example app's generated intents (`CreateTaskIntentSpec`,
`CompleteTaskIntentSpec`) and entity (`TaskEntitySpec`).

## Status

- **Compile-checked** against the Xcode 27 beta `AppIntentsTesting.framework`
  (`swiftc -typecheck`, simulator SDK). It is **not** wired into a test target
  or run in CI — running it requires building the whole example app under
  Xcode 27 beta on an iOS 27 simulator, which is intentionally out of scope
  (the example app is verified under the stable Xcode toolchain).
- The file is guarded by `#if canImport(AppIntentsTesting)` and
  `@available(iOS 27.0, *)`, so it is inert on a stable Xcode and harmless if
  added to a target that also builds for older toolchains.

## Wiring it up (Xcode 27 beta + iOS 27 simulator)

1. In Xcode 27, add a **Unit Testing Bundle** target (e.g. `AppIntentsTests`)
   to `Runner.xcworkspace`, with the host application set to `Runner`.
2. Add `GeneratedAppIntentsTests.swift` to that target.
3. Link the `AppIntentsTesting.framework` (it lives under
   `<Platform>.platform/Developer/Library/Frameworks`; Xcode adds it
   automatically when you `import AppIntentsTesting` in a test target).
4. Set the test target's minimum deployment to iOS 27.0.
5. Run on an iOS 27 simulator: `⌘U`, or
   `xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
     -destination 'platform=iOS Simulator,OS=27.0,name=iPhone 16'`.

## Identifiers

- `IntentDefinitions(bundleIdentifier:)` uses the app's bundle id —
  `com.example.app` here.
- `definitions.intents["…"]` / `definitions.entities["…"]` are keyed by the
  **generated Swift struct name** (e.g. `CreateTaskIntentSpec`,
  `TaskEntitySpec`), not the reverse-DNS `identifier` from `@IntentSpec`.

## Future

`codegen` could emit this scaffold automatically from the analyzed intents
(one `makeIntent(...).run()` per intent, with sample parameter values). Tracked
under #57.
