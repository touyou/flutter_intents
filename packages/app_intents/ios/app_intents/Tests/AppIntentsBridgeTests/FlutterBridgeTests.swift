import Testing
import Foundation
@testable import AppIntentsBridge

// Run serially: all tests share `FlutterBridge.shared` (a singleton actor),
// and several tests need to call `clearExecutors()` to start from a known
// state. Parallel execution lets one test's `clearExecutors()` wipe another
// test's freshly registered executor mid-run. Serializing is the simplest
// robust fix and matches how the bridge is used at runtime.
@Suite("FlutterBridge Tests", .serialized)
struct FlutterBridgeTests {

    @Test("FlutterBridge shared instance is singleton")
    func sharedInstanceIsSingleton() async {
        let bridge1 = FlutterBridge.shared
        let bridge2 = FlutterBridge.shared

        // Actor identity check - they should be the same instance
        #expect(bridge1 === bridge2)
    }

    @Test("Register and invoke handler successfully")
    func registerAndInvokeHandler() async throws {
        let bridge = FlutterBridge.shared

        // Register a simple handler
        await bridge.registerHandler("TestIntent") { params in
            guard let input = params as? [String: Any],
                  let value = input["value"] as? Int else {
                throw AppIntentError.handlerFailed("Invalid params")
            }
            return value * 2
        }

        // Invoke the handler
        let result = try await bridge.invoke(intent: "TestIntent", params: ["value": 10])
        let resultValue = result as? Int
        #expect(resultValue == 20)
    }

    @Test("Invoke unregistered intent without executor times out")
    func invokeUnregisteredIntentThrowsError() async {
        // With no local handler and no Flutter executor set, `invoke` waits
        // up to `executorWaitTimeout` (5s) for an executor to appear and then
        // surfaces an EXECUTOR_NOT_SET custom error. This documents that
        // contract — it's important for callers (and the iOS App Intent
        // extension process) to know that "not yet ready" is distinguishable
        // from a permanent "intent doesn't exist".
        let bridge = FlutterBridge.shared

        do {
            _ = try await bridge.invoke(intent: "NonExistentIntent", params: [:])
            Issue.record("Expected EXECUTOR_NOT_SET error")
        } catch let error as AppIntentError {
            if case .custom(let code, _) = error {
                #expect(code == "EXECUTOR_NOT_SET")
            } else {
                Issue.record("Expected custom(EXECUTOR_NOT_SET) error, got: \(error)")
            }
        } catch {
            Issue.record("Expected AppIntentError, got: \(error)")
        }
    }

    @Test("Handler failure propagates error")
    func handlerFailurePropagatesError() async throws {
        let bridge = FlutterBridge.shared

        await bridge.registerHandler("FailingIntent") { _ in
            throw AppIntentError.handlerFailed("Intentional failure")
        }

        do {
            _ = try await bridge.invoke(intent: "FailingIntent", params: [:])
            Issue.record("Expected handler to throw error")
        } catch let error as AppIntentError {
            if case .handlerFailed(let reason) = error {
                #expect(reason == "Intentional failure")
            } else {
                Issue.record("Expected handlerFailed error")
            }
        } catch {
            Issue.record("Expected AppIntentError")
        }
    }

    @Test("Multiple handlers can be registered")
    func multipleHandlersRegistration() async throws {
        let bridge = FlutterBridge.shared

        await bridge.registerHandler("IntentA") { _ in "ResultA" }
        await bridge.registerHandler("IntentB") { _ in "ResultB" }

        let resultA = try await bridge.invoke(intent: "IntentA", params: [:])
        let resultB = try await bridge.invoke(intent: "IntentB", params: [:])

        #expect(resultA as? String == "ResultA")
        #expect(resultB as? String == "ResultB")
    }

    @Test("Handler can be overwritten")
    func handlerCanBeOverwritten() async throws {
        let bridge = FlutterBridge.shared

        await bridge.registerHandler("OverwriteIntent") { _ in "Original" }
        await bridge.registerHandler("OverwriteIntent") { _ in "Updated" }

        let result = try await bridge.invoke(intent: "OverwriteIntent", params: [:])
        #expect(result as? String == "Updated")
    }

    @Test("Check if handler is registered")
    func checkHandlerRegistered() async {
        let bridge = FlutterBridge.shared

        await bridge.registerHandler("RegisteredIntent") { _ in "Result" }

        let isRegistered = await bridge.hasHandler(for: "RegisteredIntent")
        let isNotRegistered = await bridge.hasHandler(for: "UnregisteredIntent")

        #expect(isRegistered == true)
        #expect(isNotRegistered == false)
    }

    @Test("Unregister handler")
    func unregisterHandler() async {
        let bridge = FlutterBridge.shared

        await bridge.registerHandler("ToBeRemoved") { _ in "Result" }
        #expect(await bridge.hasHandler(for: "ToBeRemoved") == true)

        await bridge.unregisterHandler("ToBeRemoved")
        #expect(await bridge.hasHandler(for: "ToBeRemoved") == false)
    }

    @Test("Value query executor forwards input and returns entity dicts (#51)")
    func valueQueryExecutorForwardsInput() async throws {
        let bridge = FlutterBridge.shared

        await bridge.setValueQueryExecutor { entityIdentifier, input in
            #expect(entityIdentifier == "com.example.product")
            let query = input["query"] as? String
            return [["id": "p1", "title": "Matched: \(query ?? "")"]]
        }

        let results = try await bridge.queryValues(
            queryIdentifier: "com.example.product",
            input: ["query": "shoes"]
        )

        #expect(results.count == 1)
        #expect(results.first?["title"] as? String == "Matched: shoes")

        // Reset shared singleton so later tests see a clean executor slot.
        await bridge.clearExecutors()
    }

    @Test("RelevantEntities donator receives dicts and context (#55)")
    func relevantEntitiesDonatorReceivesInput() async throws {
        let bridge = FlutterBridge.shared

        let box = DonationBox()
        await bridge.registerRelevantEntitiesDonator(
            entityIdentifier: "com.example.song"
        ) { operation, dicts, context in
            await box.record(operation: operation, count: dicts.count, context: context)
        }

        #expect(await bridge.hasRelevantEntitiesDonator(for: "com.example.song"))

        try await bridge.donateRelevantEntities(
            entityIdentifier: "com.example.song",
            entities: [["id": "s1", "title": "Track"]],
            context: "audio.nowPlaying"
        )

        #expect(await box.count == 1)
        #expect(await box.context == "audio.nowPlaying")
        // An absent operation keeps the pre-#133 behaviour.
        #expect(await box.operation == "update")

        await bridge.clearExecutors()
    }

    @Test("RelevantEntities donator receives the remove operation (#133)")
    func relevantEntitiesDonatorReceivesOperation() async throws {
        let bridge = FlutterBridge.shared

        let box = DonationBox()
        await bridge.registerRelevantEntitiesDonator(
            entityIdentifier: "com.example.song"
        ) { operation, dicts, context in
            await box.record(operation: operation, count: dicts.count, context: context)
        }

        try await bridge.donateRelevantEntities(
            entityIdentifier: "com.example.song",
            operation: "removeAll",
            entities: [],
            context: nil
        )

        #expect(await box.operation == "removeAll")
        #expect(await box.count == 0)

        await bridge.clearExecutors()
    }

    @Test("donateRelevantEntities throws when no donator registered (#55)")
    func donateWithoutDonatorThrows() async {
        let bridge = FlutterBridge.shared
        await bridge.clearExecutors()

        do {
            try await bridge.donateRelevantEntities(
                entityIdentifier: "com.example.unregistered",
                entities: [],
                context: nil
            )
            Issue.record("Expected DONATOR_NOT_REGISTERED error")
        } catch let error as AppIntentError {
            if case .custom(let code, _) = error {
                #expect(code == "DONATOR_NOT_REGISTERED")
            } else {
                Issue.record("Expected custom(DONATOR_NOT_REGISTERED), got: \(error)")
            }
        } catch {
            Issue.record("Expected AppIntentError, got: \(error)")
        }
    }

    @Test("Intent donator receives params (#55)")
    func intentDonatorReceivesParams() async throws {
        // Do NOT clearExecutors() at start: the singleton is shared across
        // tests that run in parallel under Swift Testing, and a clear here
        // would race with other tests' registrations. Use a per-test unique
        // intent identifier instead.
        let bridge = FlutterBridge.shared
        let id = "com.example.test.intentDonator.receivesParams"

        let box = IntentDonationBox()
        await bridge.registerIntentDonator(intentIdentifier: id) { params in
            await box.record(params: params)
        }

        #expect(await bridge.hasIntentDonator(for: id))

        try await bridge.donateIntent(
            intentIdentifier: id,
            params: ["title": "Buy milk", "count": 3]
        )

        #expect(await box.lastTitle == "Buy milk")
        #expect(await box.lastCount == 3)
    }

    @Test("donateIntent throws when no donator registered (#55)")
    func donateIntentWithoutDonatorThrows() async {
        // Use a per-test unique identifier so no other test could have
        // registered a donator for it (and so we don't need to clearExecutors).
        let bridge = FlutterBridge.shared
        let id = "com.example.test.intentDonator.unregistered"

        do {
            try await bridge.donateIntent(
                intentIdentifier: id,
                params: [:]
            )
            Issue.record("Expected DONATOR_NOT_REGISTERED error")
        } catch let error as AppIntentError {
            if case .custom(let code, _) = error {
                #expect(code == "DONATOR_NOT_REGISTERED")
            } else {
                Issue.record("Expected custom(DONATOR_NOT_REGISTERED), got: \(error)")
            }
        } catch {
            Issue.record("Expected AppIntentError, got: \(error)")
        }
    }

    @Test("Relevant-intent donator receives the whole donation set (#55)")
    func relevantIntentDonatorReceivesAllDonations() async throws {
        // The underlying RelevantIntentManager call replaces everything, so the
        // bridge deliberately hands over all donations in one go rather than
        // one registration per widget configuration.
        let bridge = FlutterBridge.shared
        await bridge.clearExecutors()
        let box = RelevantIntentDonationBox()

        await bridge.setRelevantIntentDonator { donations in
            await box.record(donations)
        }

        try await bridge.donateRelevantIntents([
            ["configurationIdentifier": "a", "widgetKind": "W1"],
            ["configurationIdentifier": "b", "widgetKind": "W2"],
        ])

        let received = await box.lastIdentifiers
        #expect(received == ["a", "b"])
    }

    @Test("Donating an empty set still reaches the donator (#55)")
    func relevantIntentEmptyDonationReachesDonator() async throws {
        // An empty list is the documented way to clear previous donations, so
        // it must not be short-circuited as "nothing to do".
        let bridge = FlutterBridge.shared
        await bridge.clearExecutors()
        let box = RelevantIntentDonationBox()

        await bridge.setRelevantIntentDonator { donations in
            await box.record(donations)
        }

        try await bridge.donateRelevantIntents([])

        let called = await box.callCount
        let received = await box.lastIdentifiers
        #expect(called == 1)
        #expect(received == [])
    }

    @Test("donateRelevantIntents throws when no donator registered (#55)")
    func donateRelevantIntentsWithoutDonatorThrows() async {
        let bridge = FlutterBridge.shared
        await bridge.clearExecutors()

        do {
            try await bridge.donateRelevantIntents([])
            Issue.record("Expected DONATOR_NOT_REGISTERED error")
        } catch let error as AppIntentError {
            if case .custom(let code, _) = error {
                #expect(code == "DONATOR_NOT_REGISTERED")
            } else {
                Issue.record("Expected custom(DONATOR_NOT_REGISTERED), got: \(error)")
            }
        } catch {
            Issue.record("Expected AppIntentError, got: \(error)")
        }
    }
    // MARK: - Execution context (#130 / #131)

    @Test("Progress reports reach the registered sink")
    func progressReachesSink() async throws {
        let bridge = FlutterBridge.shared
        await bridge.clearExecutors()

        // A box, not a captured local: the sink is @Sendable and runs on the
        // actor, so the value has to live somewhere both sides can reach.
        actor Recorder {
            var updates: [(Int64, Int64)] = []
            func record(_ completed: Int64, _ total: Int64) {
                updates.append((completed, total))
            }
        }
        let recorder = Recorder()

        await bridge.beginExecution("exec-1") { completed, total in
            Task { await recorder.record(completed, total) }
        }
        try await bridge.updateProgress(executionId: "exec-1", completed: 3, total: 10)

        // The sink hops through a Task, so give it a turn to land.
        try await Task.sleep(nanoseconds: 50_000_000)
        let updates = await recorder.updates
        #expect(updates.count == 1)
        #expect(updates.first?.0 == 3)
        #expect(updates.first?.1 == 10)

        await bridge.endExecution("exec-1")
        #expect(await bridge.hasExecution("exec-1") == false)
    }

    @Test("Reporting progress for a finished execution throws")
    func progressAfterEndThrows() async throws {
        let bridge = FlutterBridge.shared
        await bridge.clearExecutors()

        await bridge.beginExecution("exec-2") { _, _ in }
        await bridge.endExecution("exec-2")

        // Silently ignoring this would hide a handler reporting progress for an
        // intent that already returned.
        await #expect(throws: AppIntentError.self) {
            try await bridge.updateProgress(executionId: "exec-2", completed: 1, total: 2)
        }
    }

    @Test("Value requests are routed to the running intent")
    func valueRequestRouted() async throws {
        let bridge = FlutterBridge.shared
        await bridge.clearExecutors()

        await bridge.beginExecution("exec-3", valueRequester: { parameter in
            parameter == "note" ? "typed by the user" : nil
        })

        let value = try await bridge.requestValue(executionId: "exec-3", parameter: "note")
        #expect(value as? String == "typed by the user")

        let unknown = try await bridge.requestValue(executionId: "exec-3", parameter: "other")
        #expect(unknown == nil)

        await bridge.endExecution("exec-3")
    }

    @Test("Cancellation is forwarded to the notifier")
    func cancellationForwarded() async throws {
        let bridge = FlutterBridge.shared
        await bridge.clearExecutors()

        actor Recorder {
            var seen: [String] = []
            func record(_ value: String) { seen.append(value) }
        }
        let recorder = Recorder()

        await bridge.setCancellationNotifier { executionId, reason in
            await recorder.record("\(executionId):\(reason)")
        }
        await bridge.reportCancellation(executionId: "exec-4", reason: "userCancelled")

        let seen = await recorder.seen
        #expect(seen == ["exec-4:userCancelled"])
    }

    @Test("Reporting a cancellation with no notifier wired is harmless")
    func cancellationWithoutNotifier() async {
        let bridge = FlutterBridge.shared
        await bridge.clearExecutors()

        // The system can cancel at any time, including before AppDelegate has
        // wired anything up; that must not be an error.
        await bridge.reportCancellation(executionId: "exec-5", reason: "whatever")
    }

}

/// Actor box for relevant-intent donation tests.
private actor RelevantIntentDonationBox {
    var lastIdentifiers: [String] = []
    var callCount = 0

    func record(_ donations: [[String: Any]]) {
        callCount += 1
        lastIdentifiers = donations.compactMap {
            $0["configurationIdentifier"] as? String
        }
    }
}

/// Actor box for intent donation tests.
private actor IntentDonationBox {
    var lastTitle: String?
    var lastCount: Int?
    func record(params: [String: Any]) {
        lastTitle = params["title"] as? String
        lastCount = params["count"] as? Int
    }
}

/// Actor box to capture donator invocations across the Sendable closure boundary.
private actor DonationBox {
    var count = 0
    var context: String?
    var operation: String?
    func record(operation: String, count: Int, context: String?) {
        self.operation = operation
        self.count = count
        self.context = context
    }
}
