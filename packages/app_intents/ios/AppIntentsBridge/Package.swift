// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// This manifest ships inside the published `app_intents` pub package, so an app
// that depends on `app_intents` can add the bridge to a target — a Widget
// Extension in particular — without a second, separately versioned dependency:
//
//     File → Add Package Dependencies… → Add Local…
//     ios/.symlinks/plugins/app_intents/ios/AppIntentsBridge
//
// CocoaPods users get the same sources through `app_intents_bridge.podspec`
// one directory up. See `docs/usage.md` → "Consuming AppIntentsBridge".
//
// The repository root carries a second manifest with the same product name so
// that `.package(url:)` keeps resolving; both point at these sources.
let package = Package(
    name: "AppIntentsBridge",
    platforms: [
        .iOS(.v17),
        // Only so `swift test` can build the package on a Mac host; the
        // package itself is iOS-facing.
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AppIntentsBridge",
            targets: ["AppIntentsBridge"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AppIntentsBridge"
        ),
        .testTarget(
            name: "AppIntentsBridgeTests",
            dependencies: ["AppIntentsBridge"]
        ),
    ]
)
