import Foundation

/// A bridge actor that facilitates communication between Flutter and App Intents framework.
///
/// `FlutterBridge` provides a thread-safe way to register intent handlers from Flutter
/// and invoke them when App Intents are triggered by the system.
///
/// Usage:
/// ```swift
/// // Register a handler from Flutter side
/// await FlutterBridge.shared.registerHandler("MyIntent") { params in
///     // Handle the intent
///     return result
/// }
///
/// // Invoke from App Intent
/// let result = try await FlutterBridge.shared.invoke(intent: "MyIntent", params: ["key": "value"])
/// ```
@available(iOS 16.0, *)
public actor FlutterBridge {
    /// The shared singleton instance of FlutterBridge
    public static let shared = FlutterBridge()

    /// Registered intent handlers keyed by intent identifier
    private var intentHandlers: [String: @Sendable (Any) async throws -> Any] = [:]

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Invokes a registered intent handler with the given parameters.
    ///
    /// - Parameters:
    ///   - intent: The identifier of the intent to invoke
    ///   - params: Parameters to pass to the intent handler
    /// - Returns: The result returned by the intent handler
    /// - Throws: `AppIntentError.intentNotFound` if no handler is registered for the intent,
    ///           or any error thrown by the handler
    public func invoke(intent: String, params: [String: Any]) async throws -> Any {
        guard let handler = intentHandlers[intent] else {
            throw AppIntentError.intentNotFound(intent)
        }

        return try await handler(params)
    }

    /// Registers a handler for the specified intent identifier.
    ///
    /// If a handler is already registered for the given identifier, it will be replaced.
    ///
    /// - Parameters:
    ///   - identifier: The unique identifier for the intent
    ///   - handler: An async closure that processes intent parameters and returns a result
    public func registerHandler(
        _ identifier: String,
        handler: @escaping @Sendable (Any) async throws -> Any
    ) {
        intentHandlers[identifier] = handler
    }

    /// Checks if a handler is registered for the specified intent identifier.
    ///
    /// - Parameter identifier: The intent identifier to check
    /// - Returns: `true` if a handler is registered, `false` otherwise
    public func hasHandler(for identifier: String) -> Bool {
        return intentHandlers[identifier] != nil
    }

    /// Unregisters the handler for the specified intent identifier.
    ///
    /// - Parameter identifier: The intent identifier to unregister
    public func unregisterHandler(_ identifier: String) {
        intentHandlers.removeValue(forKey: identifier)
    }
}
