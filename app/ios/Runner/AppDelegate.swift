import Flutter
import UIKit
import app_intents

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Wire FlutterBridge to AppIntentsPlugin for intent execution
    if #available(iOS 16.0, *) {
      Task {
        // Intent executor
        await FlutterBridge.shared.setIntentExecutor { identifier, params in
          guard let plugin = AppIntentsPlugin.shared else {
            throw AppIntentsError.channelNotAvailable
          }
          return try await plugin.executeIntentAsync(
            identifier: identifier,
            params: params
          )
        }

        // Entity query executor
        await FlutterBridge.shared.setEntityQueryExecutor { entityIdentifier, identifiers in
          guard let plugin = AppIntentsPlugin.shared else {
            throw AppIntentsError.channelNotAvailable
          }
          return try await plugin.queryEntitiesAsync(
            entityIdentifier: entityIdentifier,
            identifiers: identifiers
          )
        }

        // Suggested entities executor
        await FlutterBridge.shared.setSuggestedEntitiesExecutor { entityIdentifier in
          guard let plugin = AppIntentsPlugin.shared else {
            throw AppIntentsError.channelNotAvailable
          }
          return try await plugin.getSuggestedEntitiesAsync(
            entityIdentifier: entityIdentifier
          )
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
