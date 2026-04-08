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
            targets: ["AppBoxSDK"]
        ),
        .library(
            name: "AppBoxHealthSDK",
            targets: ["AppBoxHealthSDK"]
        ),
        .library(
            name: "AppBoxPushSDK",
            targets: [
                "AppBoxPushSDK",
                "AppBoxPushSDKDependencies",
                "AppBoxSDK"
            ]
        ),
        .library(
            name: "AppBoxSnsLoginSDK",
            targets: [
                "AppBoxSnsLoginSDK",
                "AppBoxSnsLoginSDKDependencies"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "11.12.0"
        ),
        .package(
            url: "https://github.com/google/GoogleSignIn-iOS",
            from: "9.0.0"
        ),
        .package(
            url: "https://github.com/kakao/kakao-ios-sdk",
            from: "2.26.0"
        ),
        .package(
            url: "https://github.com/naver/naveridlogin-sdk-ios-swift",
            from: "5.1.0"
        )
    ],
    targets: [
        .binaryTarget(
            name: "AppBoxSDK",
            path: "./Sources/AppBoxSDK/AppBoxSDK.xcframework"
        ),
        .binaryTarget(
            name: "AppBoxHealthSDK",
            path: "./Sources/AppBoxHealthSDK/AppBoxHealthSDK.xcframework"
        ),
        .binaryTarget(
            name: "AppBoxPushSDK",
            path: "./Sources/AppBoxPushSDK/AppBoxPushSDK.xcframework"
        ),
        .target(
            name: "AppBoxPushSDKDependencies",
            dependencies: [
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk")
            ],
            path: "SupportTargets/AppBoxPushSDKDependencies"
        ),
        .binaryTarget(
            name: "AppBoxSnsLoginSDK",
            path: "./Sources/AppBoxSnsLoginSDK/AppBoxSnsLoginSDK.xcframework"
        ),
        .target(
            name: "AppBoxSnsLoginSDKDependencies",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "KakaoSDKUser", package: "kakao-ios-sdk"),
                .product(name: "KakaoSDKAuth", package: "kakao-ios-sdk"),
                .product(name: "KakaoSDKCommon", package: "kakao-ios-sdk"),
                .product(name: "NidThirdPartyLogin", package: "naveridlogin-sdk-ios-swift")
            ],
            path: "SupportTargets/AppBoxSnsLoginSDKDependencies"
        )
    ]
)
