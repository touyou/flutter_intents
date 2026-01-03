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
        await FlutterBridge.shared.setIntentExecutor { identifier, params in
          guard let plugin = AppIntentsPlugin.shared else {
            throw AppIntentsError.channelNotAvailable
          }
          return try await plugin.executeIntentAsync(
            identifier: identifier,
            params: params
          )
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
