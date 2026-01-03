// COPIED FROM ios-spm/AppIntentsBridge
// Local copy for Example App integration

import Foundation

/// Errors that can occur during App Intent execution
public enum AppIntentError: LocalizedError {
    /// The requested intent was not found
    case intentNotFound(String)
    /// The intent handler failed with a reason
    case handlerFailed(String)
    /// A custom error with code and message
    case custom(code: String, message: String)
    /// Entity query executor is not configured
    case entityQueryNotConfigured

    public var errorDescription: String? {
        switch self {
        case .intentNotFound(let intentName):
            return "Intent not found: \(intentName)"
        case .handlerFailed(let reason):
            return "Handler failed: \(reason)"
        case .custom(let code, let message):
            return "[\(code)] \(message)"
        case .entityQueryNotConfigured:
            return "Entity query executor is not configured"
        }
    }

    /// Error code for programmatic handling
    public var code: String {
        switch self {
        case .intentNotFound:
            return "INTENT_NOT_FOUND"
        case .handlerFailed:
            return "HANDLER_FAILED"
        case .custom(let code, _):
            return code
        case .entityQueryNotConfigured:
            return "ENTITY_QUERY_NOT_CONFIGURED"
        }
    }
}
