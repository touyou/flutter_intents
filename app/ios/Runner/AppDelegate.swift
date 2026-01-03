import Flutter
import UIKit
import app_intents

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Flag to track if executors have been set up
  private static var executorsConfigured = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Wire FlutterBridge to AppIntentsPlugin for intent execution
    if #available(iOS 16.0, *) {
      Self.setupFlutterBridgeExecutorsIfNeeded()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @available(iOS 16.0, *)
  static func setupFlutterBridgeExecutorsIfNeeded() {
    guard !executorsConfigured else { return }
    executorsConfigured = true

    Task { @MainActor in
      // Intent executor
      await FlutterBridge.shared.setIntentExecutor { identifier, params in
        // Wait for plugin to be available (up to 2 seconds)
        let plugin = try await waitForPlugin()
        return try await plugin.executeIntentAsync(
          identifier: identifier,
          params: params
        )
      }

      // Entity query executor
      await FlutterBridge.shared.setEntityQueryExecutor { entityIdentifier, identifiers in
        let plugin = try await waitForPlugin()
        return try await plugin.queryEntitiesAsync(
          entityIdentifier: entityIdentifier,
          identifiers: identifiers
        )
      }

      // Suggested entities executor
      await FlutterBridge.shared.setSuggestedEntitiesExecutor { entityIdentifier in
        let plugin = try await waitForPlugin()
        return try await plugin.getSuggestedEntitiesAsync(
          entityIdentifier: entityIdentifier
        )
      }
    }
  }

  /// Waits for AppIntentsPlugin to become available with timeout
  @available(iOS 16.0, *)
  private static func waitForPlugin() async throws -> AppIntentsPlugin {
    // Try immediately first
    if let plugin = AppIntentsPlugin.shared {
      return plugin
    }

    // Wait with retries
    for _ in 0..<20 {  // 20 x 100ms = 2 seconds max
      try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
      if let plugin = AppIntentsPlugin.shared {
        return plugin
      }
    }

    throw AppIntentsError.channelNotAvailable
  }
}
