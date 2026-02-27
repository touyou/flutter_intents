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

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_intents", binaryMessenger: registrar.messenger())
        let instance = AppIntentsPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        let eventChannel = FlutterEventChannel(name: "app_intents/pending_actions", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(notifier)

        // Store shared instance for App Intents access
        shared = instance
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "getCachedValue":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "key is required", details: nil))
                return
            }
            result(AppIntentsPlugin.getCached(forKey: key))
        case "setCachedValue":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "key is required", details: nil))
                return
            }
            let value = args["value"]
            AppIntentsPlugin.setCached(value, forKey: key)
            result(nil)
        case "clearCachedValue":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "key is required", details: nil))
                return
            }
            AppIntentsPlugin.setCached(nil, forKey: key)
            result(nil)
        case "processPendingActions":
            if let data = UserDefaults.standard.data(forKey: "app_intents_pending_action"),
               let action = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                UserDefaults.standard.removeObject(forKey: "app_intents_pending_action")
                // Return the action data directly instead of nested invokeMethod("executeIntent").
                // The Dart side will call handleIntentExecution internally.
                result(action)
            } else {
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Caching API

    /// Caches a value for later retrieval.
    public static func setCached(_ value: Any?, forKey key: String) {
        let prefixedKey = "app_intents_cache_\(key)"
        if let value {
            UserDefaults.standard.set(value, forKey: prefixedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: prefixedKey)
        }
    }

    /// Retrieves a cached value.
    public static func getCached(forKey key: String) -> Any? {
        return UserDefaults.standard.object(forKey: "app_intents_cache_\(key)")
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

        if let data = try? JSONSerialization.data(withJSONObject: action) {
            UserDefaults.standard.set(data, forKey: "app_intents_pending_action")
        }

        // Notify Dart via EventChannel (buffered if Dart isn't listening yet)
        notifier.push(identifier)
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
    public func push(_ value: String) {
        buffer.append(value)
        if let sink {
            flushBuffer(sink)
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
