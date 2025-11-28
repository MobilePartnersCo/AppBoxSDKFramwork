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
            targets: ["AppBoxSDKWrapper"]
        ),
        .library(
            name: "AppBoxHealthSDK",
            targets: ["AppBoxHealthSDK"]
        )
    ],
    dependencies: [
        // Firebase
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.12.0"),
        // Google Sign-In
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "9.0.0"),
        // Kakao SDK
        .package(url: "https://github.com/kakao/kakao-ios-sdk", from: "2.26.0"),
        // Naver SDK
        .package(url: "https://github.com/naver/naveridlogin-sdk-ios-swift", from: "5.1.0")
    ],
    targets: [
        // 바이너리
        .binaryTarget(
            name: "AppBoxSDK",
            path: "Sources/AppBoxSDK/AppBoxSDK.xcframework"
        ),
        // Wrapper
        .target(
            name: "AppBoxSDKWrapper",
            dependencies: [
                "AppBoxSDK",
                // Firebase
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                // Google
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                // Kakao
                .product(name: "KakaoSDKCommon", package: "kakao-ios-sdk"),
                .product(name: "KakaoSDKAuth", package: "kakao-ios-sdk"),
                .product(name: "KakaoSDKUser", package: "kakao-ios-sdk"),
                // Naver
                .product(name: "NidThirdPartyLogin", package: "naveridlogin-sdk-ios-swift")
            ],
            path: "Sources/AppBoxSDK/Sources/AppBoxSDKWrapper"
        ),
        .target(
            name: "AppBoxHealthSDK",
            path: "Sources/AppBoxHealthSDK",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]
        )
    ]
)
