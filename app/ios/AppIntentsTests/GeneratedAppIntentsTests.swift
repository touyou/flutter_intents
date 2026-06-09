// WWDC26 AppIntentsTesting scaffold (issue #57).
//
// `AppIntentsTesting` runs generated App Intents through the full stack with no
// mocks, inside a standard test bundle. This file is a compile-verified
// scaffold for the example app's generated intents/entities — see README.md in
// this folder for how to wire it into a test target and run it.
//
// Guarded by `#if canImport(AppIntentsTesting)` so it is inert on a stable
// Xcode (the framework ships only with Xcode 27 beta), and by
// `@available(iOS 27.0, *)` because the whole framework is iOS 27+.
#if canImport(AppIntentsTesting)
import AppIntentsTesting
import XCTest

@available(iOS 27.0, *)
final class GeneratedAppIntentsTests: XCTestCase {
    // Loads intent definitions from the built app by bundle identifier — no
    // need to import the app's code. Matches the example app's bundle id.
    private let definitions = IntentDefinitions(bundleIdentifier: "com.example.app")

    // Intent definitions are keyed by their Swift type name (the generated
    // struct), e.g. `CreateTaskIntentSpec`.

    func testCreateTaskIntentRuns() async throws {
        let createTask = definitions.intents["CreateTaskIntentSpec"]
        // `makeIntent` takes the intent's @Parameter values as keyword
        // arguments; `run()` drives the intent through the real stack.
        try await createTask.makeIntent(title: "Buy milk").run()
    }

    func testCompleteTaskIntentRuns() async throws {
        let completeTask = definitions.intents["CompleteTaskIntentSpec"]
        try await completeTask.makeIntent(title: "Buy milk").run()
    }

    func testTaskEntitySpotlightQuery() async throws {
        // Entity definitions are keyed by their generated struct name too.
        let taskEntity = definitions.entities["TaskEntitySpec"]
        // Verifies the entity is queryable through Spotlight indexing.
        _ = try await taskEntity.spotlightQuery()
    }
}
#endif
