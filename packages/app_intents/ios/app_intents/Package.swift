// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "app_intents",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        // The library name uses "-" because Swift Package Manager does not allow
        // "_" in product names (Flutter maps the plugin name accordingly).
        .library(name: "app-intents", targets: ["app_intents"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "app_intents",
            dependencies: [],
            resources: [
                // Bundles the privacy manifest. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
