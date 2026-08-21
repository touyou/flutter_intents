// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Root manifest so that `.package(url: "https://github.com/touyou/flutter_intents", ...)`
// resolves — Swift Package Manager only ever looks at the repository root.
//
// The sources themselves live inside the published pub package
// (`packages/app_intents/ios/AppIntentsBridge`) so that apps installing
// `app_intents` from pub.dev can reach them without a second dependency, via
// either the local Swift package or the `app_intents_bridge` podspec next to
// it. This manifest just points at that one copy — see
// `docs/usage.md` → "Consuming AppIntentsBridge".
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
            path: "packages/app_intents/ios/AppIntentsBridge/Sources/AppIntentsBridge"
        ),
        .testTarget(
            name: "AppIntentsBridgeTests",
            dependencies: ["AppIntentsBridge"],
            path: "packages/app_intents/ios/AppIntentsBridge/Tests/AppIntentsBridgeTests"
        ),
    ]
)
