import Testing
@testable import AppIntentsBridge

@Suite("AppIntentError Tests")
struct ErrorHandlingTests {

    @Test("intentNotFound error has correct description")
    func intentNotFoundErrorDescription() {
        let error = AppIntentError.intentNotFound("TestIntent")
        #expect(error.errorDescription == "Intent not found: TestIntent")
    }

    @Test("handlerFailed error has correct description")
    func handlerFailedErrorDescription() {
        let error = AppIntentError.handlerFailed("Handler execution failed")
        #expect(error.errorDescription == "Handler failed: Handler execution failed")
    }

    @Test("custom error has correct description")
    func customErrorDescription() {
        let error = AppIntentError.custom(code: "E001", message: "Custom error message")
        #expect(error.errorDescription == "[E001] Custom error message")
    }

    @Test("intentNotFound error code")
    func intentNotFoundErrorCode() {
        let error = AppIntentError.intentNotFound("TestIntent")
        #expect(error.code == "INTENT_NOT_FOUND")
    }

    @Test("handlerFailed error code")
    func handlerFailedErrorCode() {
        let error = AppIntentError.handlerFailed("Some reason")
        #expect(error.code == "HANDLER_FAILED")
    }

    @Test("custom error code")
    func customErrorCode() {
        let error = AppIntentError.custom(code: "CUSTOM_001", message: "Test")
        #expect(error.code == "CUSTOM_001")
    }
}
