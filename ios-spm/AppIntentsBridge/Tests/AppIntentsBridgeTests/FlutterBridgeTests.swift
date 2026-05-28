import Testing
import Foundation
@testable import AppIntentsBridge

@Suite("FlutterBridge Tests")
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
}
