// swift-tools-version:5.6
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
            targets: ["AppBoxSDK", "AppBoxSDKWrapper"]
        ),
        .library(
            name: "AppBoxHealthSDK",
            targets: ["AppBoxHealthSDK"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "11.12.0"
        ),
         .package(url: "https://github.com/MobilePartnersCo/AppBoxNotificationSDKFramework.git", from: "1.0.2")
    ],
    targets: [
        .binaryTarget(
            name: "AppBoxSDK",
            path: "./Sources/AppBoxSDK/AppBoxSDK.xcframework"
        ),
        // AppBoxSDK와 AppBoxNotificationSDK를 연결하는 래퍼 타겟
        .target(
            name: "AppBoxSDKWrapper",
            dependencies: [
                "AppBoxSDK",
                .product(name: "AppBoxNotificationSDK", package: "AppBoxNotificationSDKFramework")
            ],
            path: "Sources/AppBoxSDKWrapper"
        ),
        .target(
            name: "AppBoxHealthSDK",
            path: "Sources/AppBoxHealthSDK",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]
        )
    ]
)

