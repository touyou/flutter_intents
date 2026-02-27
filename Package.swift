// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
            path: "ios-spm/AppIntentsBridge/Sources/AppIntentsBridge"
        ),
        .testTarget(
            name: "AppIntentsBridgeTests",
            dependencies: ["AppIntentsBridge"],
            path: "ios-spm/AppIntentsBridge/Tests/AppIntentsBridgeTests"
        ),
    ]
)
