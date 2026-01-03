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

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_intents", binaryMessenger: registrar.messenger())
        let instance = AppIntentsPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Store shared instance for App Intents access
        shared = instance
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
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
