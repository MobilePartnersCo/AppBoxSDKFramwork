// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppBoxSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "AppBoxSDK",
            targets: ["AppBoxSDK"]
        ),
        .library(
            name: "AppBoxHealthSDK",
            targets: ["AppBoxHealthSDK"]
        ),
        .library(
            name: "AppBoxPushSDK",
            targets: ["AppBoxPushSDK"]
        )
    ],
    dependencies: [
    ],
    targets: [
        .binaryTarget(
            name: "AppBoxSDK",
            path: "./Sources/AppBoxSDK/AppBoxSDK.xcframework"
        ),
        .target(
            name: "AppBoxHealthSDK",
            path: "Sources/AppBoxHealthSDK",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "AppBoxPushSDK",
            dependencies: [
                "AppBoxSDK"
            ],
            path: "Sources/AppBoxPushSDK",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-private-imports"])
            ]
        )
    ]
)

