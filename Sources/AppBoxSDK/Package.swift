// swift-tools-version: 5.4
import PackageDescription

let package = Package(
    name: "AppBoxSDK",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "AppBoxSDK", targets: ["AppBoxSDKWrapper"])
    ],
    dependencies: [
        // Firebase
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .exact("11.12.0")),
        // Google Sign-In
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "9.0.0"),
        // Kakao SDK
        .package(url: "https://github.com/kakao/kakao-ios-sdk", from: "2.26.0"),
        // Naver SDK (SPM)
        .package(url: "https://github.com/naver/naveridlogin-sdk-ios-swift", from: "5.1.0")
    ],
    targets: [
        // xcframework (바이너리 - 코드 숨김)
        .binaryTarget(
            name: "AppBoxSDK",
            path: "AppBoxSDK.xcframework"
        ),
        // Wrapper 타겟 (의존성 연결용)
        .target(
            name: "AppBoxSDKWrapper",
            dependencies: [
                "AppBoxSDK",
                // Firebase
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                // Google
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                // Kakao
                .product(name: "KakaoSDKUser", package: "kakao-ios-sdk"),
                .product(name: "KakaoSDKAuth", package: "kakao-ios-sdk"),
                // Naver
                .product(name: "NidThirdPartyLogin", package: "naveridlogin-sdk-ios-swift")
            ],
            path: "Sources/AppBoxSDKWrapper"
        )
    ]
)
