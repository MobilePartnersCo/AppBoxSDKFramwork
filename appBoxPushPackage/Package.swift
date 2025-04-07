// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppBoxPushSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "AppBoxPushSDK",
            targets: ["AppBoxPushSDK"]
        )
    ],
    dependencies: [
//        .package(url: "https://github.com/MobilePartnersCo/AppBoxSDKFramwork", exact: "1.0.0"),
        .package(url: "https://github.com/MobilePartnersCo/AppBoxSDKFramwork", revision: "d25d2fb740e484c0555a2407ec456830c98c5aa5"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git",
                 "11.0.0" ..< "12.0.0"
                )
    ],
    targets: [
        .target(
            name: "AppBoxPushSDK",
            dependencies: [
                .product(name: "AppBoxSDK", package: "AppBoxSDK"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk")
            ],
            path: "../Sources/AppBoxPushSDK",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-private-imports"])
            ]
        )
    ]
)

