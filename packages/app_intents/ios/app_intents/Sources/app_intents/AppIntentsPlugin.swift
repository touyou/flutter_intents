import Flutter
import UIKit

/// Flutter plugin for iOS App Intents integration.
///
/// This plugin enables Flutter apps to integrate with iOS App Intents,
/// allowing them to be controlled via Siri and Shortcuts.
public class AppIntentsPlugin: NSObject, FlutterPlugin {
    /// The method channel for communicating with Dart.
    private var channel: FlutterMethodChannel?

    /// Shared instance for accessing from App Intents.
    public static var shared: AppIntentsPlugin?

    /// Event stream for notifying Dart about pending intent actions.
    /// Uses a buffer to hold events until Dart starts listening.
    public static let notifier = PendingActionStreamHandler()

    // MARK: - Storage Configuration

    /// The App Group identifier for shared UserDefaults between the main app
    /// and App Intent extension processes (e.g., `WFIsolatedShortcutRunner`).
    ///
    /// **Must be set before any cache/pending action operations.**
    /// Without this, data written by App Intent extensions is invisible to the
    /// main app (and vice versa), causing apparent "data resets."
    ///
    /// Example (in AppDelegate):
    /// ```swift
    /// AppIntentsPlugin.configure(appGroupIdentifier: "group.com.example.app")
    /// ```
    private static var _appGroupIdentifier: String?

    /// A fixed identifier used for cache key prefixes, ensuring consistency
    /// across processes. Defaults to `"app_intents"` if not explicitly set.
    ///
    /// Unlike `Bundle.main.bundleIdentifier`, this value is stable regardless
    /// of whether code runs in the main app or an extension process.
    private static var _storageIdentifier: String?

    /// Configures shared storage for cross-process App Intents communication.
    ///
    /// - Parameters:
    ///   - appGroupIdentifier: The App Group identifier (e.g., `"group.com.example.app"`).
    ///     Required for data to persist correctly when App Intents run in extension processes.
    ///   - storageIdentifier: Optional fixed identifier for cache key prefixes.
    ///     Defaults to the main bundle identifier or `"app_intents"`.
    /// Returns `false` if validation fails (empty string).
    @discardableResult
    public static func configure(
        appGroupIdentifier: String,
        storageIdentifier: String? = nil
    ) -> Bool {
        guard !appGroupIdentifier.isEmpty else {
            NSLog("[AppIntentsPlugin] ERROR: appGroupIdentifier must not be empty.")
            assertionFailure("[AppIntentsPlugin] appGroupIdentifier must not be empty.")
            return false
        }

        // Eagerly validate that the App Group is accessible
        if UserDefaults(suiteName: appGroupIdentifier) == nil {
            NSLog("[AppIntentsPlugin] WARNING: UserDefaults(suiteName: \"%@\") returned nil. " +
                  "Verify the App Group entitlement is added in Xcode Signing & Capabilities " +
                  "and matches this identifier exactly.", appGroupIdentifier)
        }

        _appGroupIdentifier = appGroupIdentifier
        _storageIdentifier = storageIdentifier
        return true
    }

    /// The UserDefaults instance used for all storage operations.
    ///
    /// Returns the App Group suite when configured, falling back to `.standard`.
    /// Using `.standard` without App Group will cause data isolation between
    /// the main app and extension processes.
    static var storage: UserDefaults {
        if let groupId = _appGroupIdentifier {
            if let groupDefaults = UserDefaults(suiteName: groupId) {
                return groupDefaults
            }
            // The developer called configure() but the App Group is invalid.
            NSLog("[AppIntentsPlugin] ERROR: UserDefaults(suiteName: \"%@\") returned nil. " +
                  "Verify the App Group entitlement is added in Xcode Signing & Capabilities " +
                  "and matches this identifier exactly. Falling back to UserDefaults.standard, " +
                  "which will NOT share data across processes.", groupId)
            assertionFailure(
                "[AppIntentsPlugin] Invalid App Group identifier: \(groupId). " +
                "UserDefaults(suiteName:) returned nil."
            )
        } else {
            // Log once when configure() was never called
            struct Once { static var logged = false }
            if !Once.logged {
                Once.logged = true
                NSLog("[AppIntentsPlugin] WARNING: App Group not configured. " +
                      "Call AppIntentsPlugin.configure(appGroupIdentifier:) before " +
                      "using cache or pending action APIs. Without this, data will " +
                      "not be shared between the main app and extension processes.")
            }
        }
        return .standard
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_intents", binaryMessenger: registrar.messenger())
        let instance = AppIntentsPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        let eventChannel = FlutterEventChannel(name: "app_intents/pending_actions", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(notifier)

        shared = instance
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "getCachedValue":
            guard let key = Self.extractKey(from: call, result: result) else { return }
            result(AppIntentsPlugin.getCached(forKey: key))
        case "setCachedValue":
            guard let key = Self.extractKey(from: call, result: result) else { return }
            let value = (call.arguments as? [String: Any])?["value"]
            AppIntentsPlugin.setCached(value, forKey: key)
            result(nil)
        case "clearCachedValue":
            guard let key = Self.extractKey(from: call, result: result) else { return }
            AppIntentsPlugin.setCached(nil, forKey: key)
            result(nil)
        case "processPendingActions":
            result(Self.consumePendingAction())
        case "configureStorage":
            guard let args = call.arguments as? [String: Any],
                  let appGroupIdentifier = args["appGroupIdentifier"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "appGroupIdentifier is required", details: nil))
                return
            }
            let storageIdentifier = args["storageIdentifier"] as? String
            let success = AppIntentsPlugin.configure(
                appGroupIdentifier: appGroupIdentifier,
                storageIdentifier: storageIdentifier
            )
            if success {
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "appGroupIdentifier must not be empty", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Extracts the "key" argument from a method call, sending an error result if missing.
    /// Returns `nil` when the key is absent (the error result is already sent).
    private static func extractKey(from call: FlutterMethodCall, result: FlutterResult) -> String? {
        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "key is required", details: nil))
            return nil
        }
        return key
    }

    /// Key for the pending actions queue in UserDefaults.
    private static let pendingActionsKey = "app_intents_pending_actions"

    /// Reads and removes the first pending action from the queue, returning it if present.
    private static func consumePendingAction() -> [String: Any]? {
        let defaults = storage
        // Ensure we read the latest cross-process state from disk.
        // While Apple considers synchronize() unnecessary for single-process use,
        // it helps flush pending writes in the App Group cross-process scenario
        // where the extension process writes and the main app reads shortly after.
        defaults.synchronize()
        guard var pending = defaults.array(forKey: pendingActionsKey) as? [Data],
              !pending.isEmpty else {
            return nil
        }
        let data = pending.removeFirst()
        if pending.isEmpty {
            defaults.removeObject(forKey: pendingActionsKey)
        } else {
            defaults.set(pending, forKey: pendingActionsKey)
        }
        defaults.synchronize()

        guard let deserialized = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            NSLog("[AppIntentsPlugin] ERROR: Failed to deserialize pending action (data size: %d bytes). " +
                  "The action has been removed from the queue and is lost.", data.count)
            return nil
        }
        return deserialized
    }

    // MARK: - Caching API

    /// Process-stable prefix for cache keys to avoid namespace collisions.
    ///
    /// Fallback order: `_storageIdentifier` (explicit) → `Bundle.main.bundleIdentifier`
    /// (preserves pre-0.7.6 key format) → `_appGroupIdentifier` → `"app_intents"`.
    ///
    /// Note: `Bundle.main.bundleIdentifier` is preferred over `_appGroupIdentifier`
    /// to maintain backward compatibility with cache keys written before 0.7.6.
    /// In extension processes where `bundleIdentifier` differs, set `storageIdentifier`
    /// explicitly via `configure()` to ensure a consistent prefix.
    private static var cachePrefix: String {
        let id = _storageIdentifier
            ?? Bundle.main.bundleIdentifier
            ?? _appGroupIdentifier
            ?? "app_intents"
        return "app_intents.\(id).cache."
    }

    /// Caches a value for later retrieval.
    public static func setCached(_ value: Any?, forKey key: String) {
        let defaults = storage
        let prefixedKey = "\(cachePrefix)\(key)"
        if let value {
            defaults.set(value, forKey: prefixedKey)
        } else {
            defaults.removeObject(forKey: prefixedKey)
        }
        // Flush to disk for cross-process visibility (App Group UserDefaults).
        defaults.synchronize()
    }

    /// Retrieves a cached value.
    public static func getCached(forKey key: String) -> Any? {
        let defaults = storage
        // Ensure we read the latest cross-process state from disk.
        defaults.synchronize()
        return defaults.object(forKey: "\(cachePrefix)\(key)")
    }

    /// Stores a pending intent action and notifies Dart via EventChannel.
    ///
    /// Parameters are cached to UserDefaults, then `notifier.push(identifier)`
    /// sends an event to Dart. If Dart isn't listening yet, the event is
    /// buffered and delivered when the stream subscription starts.
    public static func setPendingAction(
        identifier: String,
        params: [String: Any]
    ) {
        let action: [String: Any] = [
            "identifier": identifier,
            "params": params
        ]

        let defaults = storage
        do {
            let data = try JSONSerialization.data(withJSONObject: action)
            var pending = (defaults.array(forKey: pendingActionsKey) as? [Data]) ?? []
            pending.append(data)
            defaults.set(pending, forKey: pendingActionsKey)
            // Flush to disk for cross-process visibility (App Group UserDefaults).
            defaults.synchronize()

            // Only notify Dart if the action was successfully queued.
            // Notifying on failure would cause Dart to poll for a non-existent action.
            notifier.push(identifier)
        } catch {
            NSLog("[AppIntentsPlugin] ERROR: Failed to serialize pending action '%@': %@. " +
                  "The action will NOT be queued.", identifier, error.localizedDescription)
        }
    }

    // MARK: - Flutter Bridge Integration

    /// Executes an intent asynchronously for use with FlutterBridge.
    ///
    /// This method wraps `executeIntent` with async/await support for integration
    /// with FlutterBridge actor.
    ///
    /// - Parameters:
    ///   - identifier: The unique identifier of the intent.
    ///   - params: The parameters to pass to the intent handler.
    /// - Returns: The result from the Dart handler.
    /// - Throws: An error if the intent execution fails.
    @available(iOS 13.0, *)
    @MainActor
    public func executeIntentAsync(
        identifier: String,
        params: [String: Any]
    ) async throws -> Any {
        return try await withCheckedThrowingContinuation { continuation in
            executeIntent(identifier: identifier, params: params) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Queries entities asynchronously for use with FlutterBridge.
    ///
    /// - Parameters:
    ///   - entityIdentifier: The type identifier of the entity.
    ///   - identifiers: The list of entity identifiers to query.
    /// - Returns: The list of entities from the Dart handler.
    /// - Throws: An error if the query fails.
    @available(iOS 13.0, *)
    @MainActor
    public func queryEntitiesAsync(
        entityIdentifier: String,
        identifiers: [String]
    ) async throws -> [[String: Any]] {
        return try await withCheckedThrowingContinuation { continuation in
            queryEntities(entityIdentifier: entityIdentifier, identifiers: identifiers) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Gets suggested entities asynchronously for use with FlutterBridge.
    ///
    /// - Parameters:
    ///   - entityIdentifier: The type identifier of the entity.
    /// - Returns: The list of suggested entities from the Dart handler.
    /// - Throws: An error if the query fails.
    @available(iOS 13.0, *)
    @MainActor
    public func getSuggestedEntitiesAsync(
        entityIdentifier: String
    ) async throws -> [[String: Any]] {
        return try await withCheckedThrowingContinuation { continuation in
            getSuggestedEntities(entityIdentifier: entityIdentifier) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Runs an IntentValueQuery asynchronously for use with FlutterBridge (#51).
    ///
    /// - Parameters:
    ///   - entityIdentifier: The type identifier of the entity to return.
    ///   - input: A serializable search input (e.g. `["query": "text"]`).
    /// - Returns: The list of entities from the Dart value-query handler.
    /// - Throws: An error if the query fails.
    @available(iOS 13.0, *)
    @MainActor
    public func queryValuesAsync(
        entityIdentifier: String,
        input: [String: Any]
    ) async throws -> [[String: Any]] {
        return try await withCheckedThrowingContinuation { continuation in
            queryValues(entityIdentifier: entityIdentifier, input: input) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Intent Execution

    /// Executes an intent by invoking the Dart handler.
    ///
    /// - Parameters:
    ///   - identifier: The unique identifier of the intent.
    ///   - params: The parameters to pass to the intent handler.
    ///   - completion: Called with the result or error from the Dart handler.
    public func executeIntent(
        identifier: String,
        params: [String: Any],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let channel = channel else {
            completion(.failure(AppIntentsError.channelNotAvailable))
            return
        }

        let arguments: [String: Any] = [
            "identifier": identifier,
            "params": params
        ]

        channel.invokeMethod("executeIntent", arguments: arguments) { result in
            if let error = result as? FlutterError {
                completion(.failure(AppIntentsError.flutterError(
                    code: error.code,
                    message: error.message ?? "Unknown error",
                    details: error.details
                )))
            } else if let resultMap = result as? [String: Any] {
                completion(.success(resultMap))
            } else if result == nil || result is NSNull {
                completion(.success([:]))
            } else {
                completion(.failure(AppIntentsError.invalidResult))
            }
        }
    }

    // MARK: - Entity Queries

    /// Queries entities by their identifiers.
    ///
    /// - Parameters:
    ///   - entityIdentifier: The type identifier of the entity.
    ///   - identifiers: The list of entity identifiers to query.
    ///   - completion: Called with the list of entities or an error.
    public func queryEntities(
        entityIdentifier: String,
        identifiers: [String],
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        guard let channel = channel else {
            completion(.failure(AppIntentsError.channelNotAvailable))
            return
        }

        let arguments: [String: Any] = [
            "entityIdentifier": entityIdentifier,
            "identifiers": identifiers
        ]

        channel.invokeMethod("queryEntities", arguments: arguments) { result in
            if let error = result as? FlutterError {
                completion(.failure(AppIntentsError.flutterError(
                    code: error.code,
                    message: error.message ?? "Unknown error",
                    details: error.details
                )))
            } else if let resultList = result as? [[String: Any]] {
                completion(.success(resultList))
            } else if result == nil || result is NSNull {
                completion(.success([]))
            } else {
                completion(.failure(AppIntentsError.invalidResult))
            }
        }
    }

    /// Gets suggested entities for the given entity type.
    ///
    /// - Parameters:
    ///   - entityIdentifier: The type identifier of the entity.
    ///   - completion: Called with the list of suggested entities or an error.
    public func getSuggestedEntities(
        entityIdentifier: String,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        guard let channel = channel else {
            completion(.failure(AppIntentsError.channelNotAvailable))
            return
        }

        let arguments: [String: Any] = [
            "entityIdentifier": entityIdentifier
        ]

        channel.invokeMethod("getSuggestedEntities", arguments: arguments) { result in
            if let error = result as? FlutterError {
                completion(.failure(AppIntentsError.flutterError(
                    code: error.code,
                    message: error.message ?? "Unknown error",
                    details: error.details
                )))
            } else if let resultList = result as? [[String: Any]] {
                completion(.success(resultList))
            } else if result == nil || result is NSNull {
                completion(.success([]))
            } else {
                completion(.failure(AppIntentsError.invalidResult))
            }
        }
    }

    // MARK: - Value Queries (#51)

    /// Runs an IntentValueQuery by invoking the Dart handler.
    ///
    /// - Parameters:
    ///   - entityIdentifier: The type identifier of the entity to return.
    ///   - input: A serializable search input (e.g. `["query": "text"]`).
    ///   - completion: Called with the list of entities or an error.
    public func queryValues(
        entityIdentifier: String,
        input: [String: Any],
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        guard let channel = channel else {
            completion(.failure(AppIntentsError.channelNotAvailable))
            return
        }

        let arguments: [String: Any] = [
            "entityIdentifier": entityIdentifier,
            "input": input
        ]

        channel.invokeMethod("queryValues", arguments: arguments) { result in
            if let error = result as? FlutterError {
                completion(.failure(AppIntentsError.flutterError(
                    code: error.code,
                    message: error.message ?? "Unknown error",
                    details: error.details
                )))
            } else if let resultList = result as? [[String: Any]] {
                completion(.success(resultList))
            } else if result == nil || result is NSNull {
                completion(.success([]))
            } else {
                completion(.failure(AppIntentsError.invalidResult))
            }
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during App Intents operations.
public enum AppIntentsError: Error, LocalizedError {
    /// The Flutter method channel is not available.
    case channelNotAvailable

    /// The result from Flutter was invalid or unexpected.
    case invalidResult

    /// An error occurred in the Flutter handler.
    case flutterError(code: String, message: String, details: Any?)

    /// The handler for the specified intent was not found.
    case handlerNotFound(identifier: String)

    /// The entity query handler was not found.
    case entityQueryHandlerNotFound(entityIdentifier: String)

    public var errorDescription: String? {
        switch self {
        case .channelNotAvailable:
            return "Flutter method channel is not available"
        case .invalidResult:
            return "Invalid result received from Flutter"
        case .flutterError(let code, let message, _):
            return "Flutter error (\(code)): \(message)"
        case .handlerNotFound(let identifier):
            return "No handler registered for intent: \(identifier)"
        case .entityQueryHandlerNotFound(let entityIdentifier):
            return "No entity query handler registered for: \(entityIdentifier)"
        }
    }
}

// MARK: - Pending Action Stream Handler

/// A push-only stream handler that buffers events until Dart listens.
///
/// When `push()` is called before Dart subscribes, events are buffered.
/// Once Dart calls `listen()`, all buffered events are flushed immediately.
public class PendingActionStreamHandler: NSObject, FlutterStreamHandler {
    private var sink: FlutterEventSink?
    private var buffer: [String] = []

    /// Pushes an event to Dart. Buffers if Dart isn't listening yet.
    /// Dispatches to the main thread to ensure thread safety with FlutterEventSink.
    public func push(_ value: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.buffer.append(value)
            if let sink = self.sink {
                self.flushBuffer(sink)
            }
        }
    }

    private func flushBuffer(_ sink: FlutterEventSink) {
        for item in buffer {
            sink(item)
        }
        buffer = []
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        flushBuffer(events)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}
