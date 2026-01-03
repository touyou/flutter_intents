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

    /// Executor for delegating intent execution to Flutter via plugin
    private var intentExecutor: (@Sendable (String, [String: Any]) async throws -> Any)?

    /// Executor for querying entities from Flutter
    private var entityQueryExecutor: (@Sendable (String, [String]) async throws -> [[String: Any]])?

    /// Executor for getting suggested entities from Flutter
    private var suggestedEntitiesExecutor: (@Sendable (String) async throws -> [[String: Any]])?

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Sets the intent executor that handles communication with Flutter.
    ///
    /// This should be called during app initialization to wire FlutterBridge
    /// to the Flutter plugin (AppIntentsPlugin).
    ///
    /// - Parameter executor: An async closure that executes intents via Flutter.
    public func setIntentExecutor(
        _ executor: @escaping @Sendable (String, [String: Any]) async throws -> Any
    ) {
        intentExecutor = executor
    }

    /// Sets the entity query executor that fetches entities from Flutter.
    ///
    /// - Parameter executor: An async closure that queries entities by identifiers.
    public func setEntityQueryExecutor(
        _ executor: @escaping @Sendable (String, [String]) async throws -> [[String: Any]]
    ) {
        entityQueryExecutor = executor
    }

    /// Sets the suggested entities executor that fetches suggestions from Flutter.
    ///
    /// - Parameter executor: An async closure that fetches suggested entities.
    public func setSuggestedEntitiesExecutor(
        _ executor: @escaping @Sendable (String) async throws -> [[String: Any]]
    ) {
        suggestedEntitiesExecutor = executor
    }

    /// Invokes a registered intent handler with the given parameters.
    ///
    /// The method first checks for a locally registered handler. If none is found,
    /// it falls back to the intent executor (which communicates with Flutter).
    ///
    /// - Parameters:
    ///   - intent: The identifier of the intent to invoke
    ///   - params: Parameters to pass to the intent handler
    /// - Returns: The result returned by the intent handler
    /// - Throws: `AppIntentError.intentNotFound` if no handler is registered for the intent,
    ///           or any error thrown by the handler
    public func invoke(intent: String, params: [String: Any]) async throws -> Any {
        // Try local handler first
        if let handler = intentHandlers[intent] {
            return try await handler(params)
        }

        // Fall back to Flutter executor
        if let executor = intentExecutor {
            return try await executor(intent, params)
        }

        throw AppIntentError.intentNotFound(intent)
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

    // MARK: - Entity Queries

    /// Queries entities by their identifiers.
    ///
    /// - Parameters:
    ///   - entityIdentifier: The type identifier of the entity (e.g., "TaskEntitySpec")
    ///   - identifiers: The list of entity IDs to fetch
    /// - Returns: An array of entity dictionaries
    /// - Throws: `AppIntentError.entityQueryNotConfigured` if no executor is set
    public func queryEntities(
        entityIdentifier: String,
        identifiers: [String]
    ) async throws -> [[String: Any]] {
        guard let executor = entityQueryExecutor else {
            throw AppIntentError.entityQueryNotConfigured
        }
        return try await executor(entityIdentifier, identifiers)
    }

    /// Gets suggested entities for the given entity type.
    ///
    /// This is used by iOS to populate entity pickers in Shortcuts.
    ///
    /// - Parameter entityIdentifier: The type identifier of the entity
    /// - Returns: An array of suggested entity dictionaries
    /// - Throws: `AppIntentError.entityQueryNotConfigured` if no executor is set
    public func suggestedEntities(
        entityIdentifier: String
    ) async throws -> [[String: Any]] {
        guard let executor = suggestedEntitiesExecutor else {
            throw AppIntentError.entityQueryNotConfigured
        }
        return try await executor(entityIdentifier)
    }
}
