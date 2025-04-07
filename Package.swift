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
            targets: ["AppBoxPushSDKTarget"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            "10.15.0" ..< "12.0.0"
        )
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
            name: "AppBoxPushSDKTarget",
            dependencies: [.target(name: "AppBoxPushSDKWrapper",
                                   condition: .when(platforms: [.iOS]))],
            path:"Sources/SwiftPM-PlatformExclude/AppBoxPushSDKWrap"
        ),
        .target(
            name: "AppBoxPushSDKWrapper",
            dependencies: [
                "AppBoxSDK",
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk")
            ],
            path: "Sources/AppBoxPushSDK",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-private-imports"])
            ]
        )
    ]
)

