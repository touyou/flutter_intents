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
@available(iOS 17.0, *)
public actor FlutterBridge {
    /// The shared singleton instance of FlutterBridge
    public static let shared = FlutterBridge()

    /// Registered intent handlers keyed by intent identifier
    private var intentHandlers: [String: @Sendable (sending Any) async throws -> sending Any] = [:]

    /// Executor for delegating intent execution to Flutter via plugin
    private var intentExecutor: (@Sendable (sending String, sending [String: Any]) async throws -> sending Any)?

    /// Executor for querying entities from Flutter
    private var entityQueryExecutor: (@Sendable (sending String, sending [String]) async throws -> sending [[String: Any]])?

    /// Executor for getting suggested entities from Flutter
    private var suggestedEntitiesExecutor: (@Sendable (sending String) async throws -> sending [[String: Any]])?

    /// Executor for running an IntentValueQuery in Flutter (#51).
    ///
    /// The closure is intentionally generic — it forwards the entity identifier
    /// and a serializable input dictionary to Flutter and returns entity maps.
    /// It never names an iOS-27 `IntentValueQuery` symbol, so this plugin
    /// compiles against the stable SDK; the iOS-27 type lives only in the
    /// `#if`-gated generated `IntentValueQuery` struct that calls `queryValues`.
    private var valueQueryExecutor: (@Sendable (sending String, sending [String: Any]) async throws -> sending [[String: Any]])?

    /// Reverse executors for RelevantEntities donation, keyed by entity
    /// identifier (#55).
    ///
    /// Unlike the forward executors (which are single, type-agnostic
    /// forwarders), a donator must construct *concrete* `AppEntity` instances
    /// before calling `RelevantEntities.shared.updateEntities`. That concrete
    /// type is per-entity and lives in `#if`-gated generated Swift, so each
    /// generated entity registers its own closure here. The closure type stays
    /// generic (dicts only) so this plugin names no iOS-27 symbol. See ADR 0003.
    /// The closure's first argument is the operation — `"update"`, `"remove"`
    /// or `"removeAll"` (#133). `RelevantEntities` gained explicit removal in
    /// the Xcode 27 SDK; before that the only way to drop a donation was to
    /// update with an empty list, which cannot express "clear everything".
    private var relevantEntitiesDonators: [String: @Sendable (sending String, sending [[String: Any]], sending String?) async throws -> Void] = [:]

    /// Applies a whole set of relevant-intent donations (#55).
    ///
    /// One slot, not one per widget configuration, because
    /// `RelevantIntentManager.updateRelevantIntents` replaces the app's entire
    /// set in a single call — per-configuration appliers would each wipe out
    /// the others. The generated closure knows every configuration in the
    /// project, builds the concrete intents for all of them, and performs that
    /// one update.
    private var relevantIntentDonator: (@Sendable (sending [[String: Any]]) async throws -> Void)?

    /// Reverse executors for intent donation (#55), keyed by intent identifier.
    ///
    /// Same shape as `relevantEntitiesDonators` but per-intent. The closure
    /// reconstructs the concrete `AppIntent` struct from the dict and calls
    /// `intent.donate()` (stable iOS 16+). The bridge never names that symbol;
    /// it lives only inside the `#if`-gated generated closure.
    private var intentDonators: [String: @Sendable (sending [String: Any]) async throws -> Void] = [:]

    /// Per-execution progress sinks, keyed by execution id (#130).
    ///
    /// A long-running intent's `progress` object lives in the generated
    /// `perform()`, not here: `ProgressReportingIntent` is an iOS 27 symbol and
    /// this module must keep compiling against the released SDK. So the
    /// generated code registers a closure that writes into its own `progress`,
    /// and the bridge only routes numbers to it.
    private var progressSinks: [String: @Sendable (Int64, Int64) -> Void] = [:]

    /// Per-execution parameter-value requesters, keyed by execution id (#131).
    ///
    /// The closure captures the running intent instance, which is the only
    /// thing that can call `$param.requestValue()` — the call has to happen on
    /// the same intent whose `perform()` is currently suspended.
    private var valueRequesters:
        [String: @Sendable (sending String) async throws -> sending Any?] = [:]

    /// Forwards a cancellation to Dart (#130). Wired in AppDelegate, mirroring
    /// the forward executors: this module cannot see the plugin.
    private var cancellationNotifier: (@Sendable (sending String, sending String) async -> Void)?

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Clears all registered executors.
    ///
    /// Call this when the Flutter engine is torn down (e.g., in
    /// `detachFromEngineForRegistrar`) to prevent stale closures from
    /// being invoked after a hot restart.
    public func clearExecutors() {
        intentExecutor = nil
        entityQueryExecutor = nil
        suggestedEntitiesExecutor = nil
        valueQueryExecutor = nil
        relevantEntitiesDonators.removeAll()
        relevantIntentDonator = nil
        intentDonators.removeAll()
        progressSinks.removeAll()
        valueRequesters.removeAll()
        cancellationNotifier = nil
    }

    /// Sets the intent executor that handles communication with Flutter.
    ///
    /// This should be called during app initialization to wire FlutterBridge
    /// to the Flutter plugin (AppIntentsPlugin).
    ///
    /// - Parameter executor: An async closure that executes intents via Flutter.
    public func setIntentExecutor(
        _ executor: @escaping @Sendable (sending String, sending [String: Any]) async throws -> sending Any
    ) {
        intentExecutor = executor
    }

    /// Sets the entity query executor that fetches entities from Flutter.
    ///
    /// - Parameter executor: An async closure that queries entities by identifiers.
    public func setEntityQueryExecutor(
        _ executor: @escaping @Sendable (sending String, sending [String]) async throws -> sending [[String: Any]]
    ) {
        entityQueryExecutor = executor
    }

    /// Sets the suggested entities executor that fetches suggestions from Flutter.
    ///
    /// - Parameter executor: An async closure that fetches suggested entities.
    public func setSuggestedEntitiesExecutor(
        _ executor: @escaping @Sendable (sending String) async throws -> sending [[String: Any]]
    ) {
        suggestedEntitiesExecutor = executor
    }

    /// Sets the value query executor that runs an IntentValueQuery in Flutter (#51).
    ///
    /// - Parameter executor: An async closure that takes the entity identifier
    ///   and a serializable input dictionary and returns entity dictionaries.
    public func setValueQueryExecutor(
        _ executor: @escaping @Sendable (sending String, sending [String: Any]) async throws -> sending [[String: Any]]
    ) {
        valueQueryExecutor = executor
    }

    /// Maximum time to wait for executor to be set (in seconds)
    private let executorWaitTimeout: Double = 5.0

    /// Invokes a registered intent handler with the given parameters.
    ///
    /// The method first checks for a locally registered handler. If none is found,
    /// it falls back to the intent executor (which communicates with Flutter).
    /// If the executor is not yet set, waits up to `executorWaitTimeout` seconds.
    ///
    /// - Parameters:
    ///   - intent: The identifier of the intent to invoke
    ///   - params: Parameters to pass to the intent handler
    /// - Returns: The result returned by the intent handler
    /// - Throws: `AppIntentError.intentNotFound` if no handler is registered for the intent,
    ///           or any error thrown by the handler
    public func invoke(intent: String, params: sending [String: Any]) async throws -> sending Any {
        // Try local handler first
        if let handler = intentHandlers[intent] {
            return try await handler(params)
        }

        // Wait for Flutter executor to be set
        let executor = try await waitForIntentExecutor()
        return try await executor(intent, params)
    }

    /// Waits for the intent executor to be set with timeout
    private func waitForIntentExecutor() async throws -> @Sendable (sending String, sending [String: Any]) async throws -> sending Any {
        // Try immediately first
        if let executor = intentExecutor {
            return executor
        }

        // Wait with retries (50 x 100ms = 5 seconds max)
        let maxRetries = Int(executorWaitTimeout * 10)
        for _ in 0..<maxRetries {
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            if let executor = intentExecutor {
                return executor
            }
        }

        throw AppIntentError.custom(code: "EXECUTOR_NOT_SET", message: "Intent executor was not set within timeout")
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
        handler: @escaping @Sendable (sending Any) async throws -> sending Any
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
    /// - Throws: `AppIntentError.entityQueryNotConfigured` if no executor is set within timeout
    public func queryEntities(
        entityIdentifier: String,
        identifiers: sending [String]
    ) async throws -> sending [[String: Any]] {
        let executor = try await waitForEntityQueryExecutor()
        return try await executor(entityIdentifier, identifiers)
    }

    /// Gets suggested entities for the given entity type.
    ///
    /// This is used by iOS to populate entity pickers in Shortcuts.
    ///
    /// - Parameter entityIdentifier: The type identifier of the entity
    /// - Returns: An array of suggested entity dictionaries
    /// - Throws: `AppIntentError.entityQueryNotConfigured` if no executor is set within timeout
    public func suggestedEntities(
        entityIdentifier: String
    ) async throws -> sending [[String: Any]] {
        let executor = try await waitForSuggestedEntitiesExecutor()
        return try await executor(entityIdentifier)
    }

    /// Waits for the entity query executor to be set with timeout
    private func waitForEntityQueryExecutor() async throws -> @Sendable (sending String, sending [String]) async throws -> sending [[String: Any]] {
        if let executor = entityQueryExecutor {
            return executor
        }

        let maxRetries = Int(executorWaitTimeout * 10)
        for _ in 0..<maxRetries {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let executor = entityQueryExecutor {
                return executor
            }
        }

        throw AppIntentError.entityQueryNotConfigured
    }

    /// Waits for the suggested entities executor to be set with timeout
    private func waitForSuggestedEntitiesExecutor() async throws -> @Sendable (sending String) async throws -> sending [[String: Any]] {
        if let executor = suggestedEntitiesExecutor {
            return executor
        }

        let maxRetries = Int(executorWaitTimeout * 10)
        for _ in 0..<maxRetries {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let executor = suggestedEntitiesExecutor {
                return executor
            }
        }

        throw AppIntentError.entityQueryNotConfigured
    }

    // MARK: - Value Queries (#51)

    /// Runs an IntentValueQuery for the given entity type.
    ///
    /// - Parameters:
    ///   - queryIdentifier: The type identifier of the entity to return.
    ///   - input: A serializable search input (e.g. `["query": "text"]`).
    /// - Returns: An array of entity dictionaries.
    /// - Throws: `AppIntentError.entityQueryNotConfigured` if no executor is set within timeout.
    public func queryValues(
        queryIdentifier: String,
        input: sending [String: Any]
    ) async throws -> sending [[String: Any]] {
        let executor = try await waitForValueQueryExecutor()
        return try await executor(queryIdentifier, input)
    }

    /// Waits for the value query executor to be set with timeout
    private func waitForValueQueryExecutor() async throws -> @Sendable (sending String, sending [String: Any]) async throws -> sending [[String: Any]] {
        if let executor = valueQueryExecutor {
            return executor
        }

        let maxRetries = Int(executorWaitTimeout * 10)
        for _ in 0..<maxRetries {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let executor = valueQueryExecutor {
                return executor
            }
        }

        throw AppIntentError.entityQueryNotConfigured
    }

    // MARK: - RelevantEntities Donation (#55)

    /// Registers a donator closure for the given entity type.
    ///
    /// Called from `#if`-gated generated Swift at startup. The closure builds
    /// concrete `AppEntity` instances from the dictionaries and calls
    /// `RelevantEntities.shared.updateEntities(_:for:)`.
    ///
    /// - Parameters:
    ///   - entityIdentifier: The entity type identifier.
    ///   - donator: Builds entities from dicts and donates them for `context`.
    public func registerRelevantEntitiesDonator(
        entityIdentifier: String,
        _ donator: @escaping @Sendable (sending String, sending [[String: Any]], sending String?) async throws -> Void
    ) {
        relevantEntitiesDonators[entityIdentifier] = donator
    }

    /// Donates relevant entities for the given entity type.
    ///
    /// Invoked by the plugin when Dart calls `donateRelevantEntities`. Looks up
    /// the registered donator (which knows the concrete entity type) and calls
    /// it. Each call is a stateful overwrite for the given context.
    ///
    /// - Parameters:
    ///   - entityIdentifier: The entity type identifier.
    ///   - operation: `"update"`, `"remove"` or `"removeAll"` (#133).
    ///   - entities: Entity dictionaries to donate or remove. Ignored by
    ///     `"removeAll"`.
    ///   - context: An opaque context token (e.g. `"audio.nowPlaying"`), or nil.
    /// - Throws: `AppIntentError.custom("DONATOR_NOT_REGISTERED", ...)` when no
    ///           generated donator is registered for `entityIdentifier`.
    public func donateRelevantEntities(
        entityIdentifier: String,
        operation: String = "update",
        entities: sending [[String: Any]],
        context: String?
    ) async throws {
        guard let donator = relevantEntitiesDonators[entityIdentifier] else {
            throw AppIntentError.custom(
                code: "DONATOR_NOT_REGISTERED",
                message: "No RelevantEntities donator registered for \(entityIdentifier). "
                    + "Call the generated register…RelevantEntitiesDonator() at startup."
            )
        }
        try await donator(operation, entities, context)
    }

    /// Whether a donator is registered for the given entity type.
    public func hasRelevantEntitiesDonator(for entityIdentifier: String) -> Bool {
        return relevantEntitiesDonators[entityIdentifier] != nil
    }

    // MARK: - Intent Donation (#55)

    /// Registers a donator closure for the given intent identifier.
    ///
    /// Called from `#if`-gated generated Swift at startup. The closure
    /// reconstructs the concrete `AppIntent` from the param dict and calls
    /// `intent.donate()`.
    ///
    /// - Parameters:
    ///   - intentIdentifier: The intent identifier (matches `@IntentSpec.identifier`).
    ///   - donator: Reconstructs and donates the intent from `params`.
    public func registerIntentDonator(
        intentIdentifier: String,
        _ donator: @escaping @Sendable (sending [String: Any]) async throws -> Void
    ) {
        intentDonators[intentIdentifier] = donator
    }

    /// Donates an intent.
    ///
    /// Invoked by the plugin when Dart calls `donateIntent`. Looks up the
    /// registered donator (which knows the concrete intent type) and calls it.
    ///
    /// - Parameters:
    ///   - intentIdentifier: The intent identifier.
    ///   - params: The parameter map used to reconstruct the intent.
    /// - Throws: `AppIntentError.custom("DONATOR_NOT_REGISTERED", ...)` when no
    ///           generated donator is registered for `intentIdentifier`.
    public func donateIntent(
        intentIdentifier: String,
        params: sending [String: Any]
    ) async throws {
        guard let donator = intentDonators[intentIdentifier] else {
            throw AppIntentError.custom(
                code: "DONATOR_NOT_REGISTERED",
                message: "No intent donator registered for \(intentIdentifier). "
                    + "Call the generated register…IntentDonator() at startup."
            )
        }
        try await donator(params)
    }

    /// Whether a donator is registered for the given intent identifier.
    public func hasIntentDonator(for intentIdentifier: String) -> Bool {
        return intentDonators[intentIdentifier] != nil
    }

    // MARK: - Relevant Intents (#55)

    /// Registers the closure that turns donation dictionaries into
    /// `RelevantIntent` values and pushes them to `RelevantIntentManager`.
    ///
    /// Called once at startup from generated Swift. This module deliberately
    /// imports only Foundation — so an App Extension can link it without
    /// pulling anything else in — which is why the closure, not this actor,
    /// names `RelevantIntent` and `RelevantContext`.
    public func setRelevantIntentDonator(
        _ donator: @escaping @Sendable (sending [[String: Any]]) async throws -> Void
    ) {
        relevantIntentDonator = donator
    }

    /// Donates the given relevant intents, replacing the app's previous set.
    ///
    /// Invoked by the plugin when Dart calls `donateRelevantIntents`. An empty
    /// list clears every previously donated intent.
    ///
    /// - Parameter donations: One dictionary per donation, each carrying
    ///   `configurationIdentifier`, `widgetKind`, `parameters` and `relevance`.
    /// - Throws: `AppIntentError.custom("DONATOR_NOT_REGISTERED", ...)` when the
    ///           generated registration has not run.
    public func donateRelevantIntents(
        _ donations: sending [[String: Any]]
    ) async throws {
        guard let donator = relevantIntentDonator else {
            throw AppIntentError.custom(
                code: "DONATOR_NOT_REGISTERED",
                message: "No relevant-intent donator registered. Call the generated "
                    + "registerRelevantIntentDonator() at startup."
            )
        }
        try await donator(donations)
    }

    /// Whether the generated relevant-intent donator has been registered.
    public func hasRelevantIntentDonator() -> Bool {
        return relevantIntentDonator != nil
    }

    // MARK: - Execution Context (#130 progress / cancellation, #131 value requests)

    /// Opens an execution scope for one `perform()` call.
    ///
    /// The execution id travels to Dart in the params dictionary under
    /// `_executionId`, which is how a Dart handler names the execution it wants
    /// to report progress for or request a value from. Always pair with
    /// [endExecution] — a leaked sink keeps the intent instance alive.
    ///
    /// - Parameters:
    ///   - executionId: Identifies this `perform()` call.
    ///   - progress: Receives `(completed, total)` unit counts from Dart.
    ///   - valueRequester: Asks the running intent for a parameter value.
    public func beginExecution(
        _ executionId: String,
        progress: (@Sendable (Int64, Int64) -> Void)? = nil,
        valueRequester: (@Sendable (sending String) async throws -> sending Any?)? = nil
    ) {
        if let progress {
            progressSinks[executionId] = progress
        }
        if let valueRequester {
            valueRequesters[executionId] = valueRequester
        }
    }

    /// Closes an execution scope opened by [beginExecution].
    public func endExecution(_ executionId: String) {
        progressSinks.removeValue(forKey: executionId)
        valueRequesters.removeValue(forKey: executionId)
    }

    /// Whether an execution scope is currently open.
    public func hasExecution(_ executionId: String) -> Bool {
        return progressSinks[executionId] != nil || valueRequesters[executionId] != nil
    }

    /// Routes a progress report from Dart to the running intent (#130).
    ///
    /// - Throws: `AppIntentError.custom("EXECUTION_NOT_ACTIVE", …)` when the
    ///           intent already finished — reporting into a closed execution is
    ///           a programming error worth surfacing, not a silent no-op.
    public func updateProgress(
        executionId: String,
        completed: Int64,
        total: Int64
    ) throws {
        guard let sink = progressSinks[executionId] else {
            throw AppIntentError.custom(
                code: "EXECUTION_NOT_ACTIVE",
                message: "No long-running intent execution \(executionId) is reporting progress. "
                    + "Progress can only be reported while the handler is running, and only by "
                    + "an intent declared @IntentSpec(longRunning: true)."
            )
        }
        sink(completed, total)
    }

    /// Asks the running intent to prompt the user for a parameter value (#131).
    ///
    /// - Returns: The value the user supplied, or nil when the parameter is not
    ///            one the intent offers.
    public func requestValue(
        executionId: String,
        parameter: sending String
    ) async throws -> sending Any? {
        guard let requester = valueRequesters[executionId] else {
            throw AppIntentError.custom(
                code: "EXECUTION_NOT_ACTIVE",
                message: "No intent execution \(executionId) can request values. Values can only "
                    + "be requested while the handler is running, and only for a parameter "
                    + "declared @IntentParam(requestValue: true)."
            )
        }
        return try await requester(parameter)
    }

    /// Sets the closure that tells Dart an intent was cancelled (#130).
    ///
    /// Wired in AppDelegate to `AppIntentsPlugin.notifyIntentCancellation`.
    public func setCancellationNotifier(
        _ notifier: @escaping @Sendable (sending String, sending String) async -> Void
    ) {
        cancellationNotifier = notifier
    }

    /// Tells Dart that the system cancelled the given execution (#130).
    ///
    /// Best-effort by nature: the system may suspend or kill the process
    /// shortly after cancelling, so an unwired notifier is not an error.
    public func reportCancellation(executionId: String, reason: String) async {
        await cancellationNotifier?(executionId, reason)
    }
}
