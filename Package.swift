// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Root manifest so that `.package(url: "https://github.com/touyou/flutter_intents", ...)`
// resolves — Swift Package Manager only ever looks at the repository root.
//
// The sources themselves live inside the plugin's own Swift package
// (`packages/app_intents/ios/app_intents`), which ships in the published pub
// package. That placement is what lets an SPM-only Flutter app reach the
// `AppIntentsBridge` product at the stable, Podfile-free path
// `ios/Flutter/ephemeral/Packages/.packages/app_intents`. This manifest just
// points at that one copy — see `docs/usage.md` → "Consuming AppIntentsBridge".
let package = Package(
    name: "AppIntentsBridge",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AppIntentsBridge",
            targets: ["AppIntentsBridge"]
        ),
    ],
    targets: [
        .target(
            name: "AppIntentsBridge",
            path: "packages/app_intents/ios/app_intents/Sources/AppIntentsBridge"
        ),
        .testTarget(
            name: "AppIntentsBridgeTests",
            dependencies: ["AppIntentsBridge"],
            path: "packages/app_intents/ios/app_intents/Tests/AppIntentsBridgeTests"
        ),
    ]
)
