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
            name: "AppBoxPush",
            targets: ["AppBoxPushWrapper"]
        )

    ],
    targets: [
        .binaryTarget(
            name: "AppBoxSDK",
            path: "./Sources/AppBoxSDK/AppBoxSDK.xcframework"
        ),
        .binaryTarget(
            name: "AppBoxPush",
            path: "./Sources/AppBoxPush/AppBoxPush.xcframework"
        ),
        .target(
            name: "AppBoxPushWrapper",
            dependencies: [], // 실질적인 의존성 없음
            path: "Sources/Dummy" // 더미 폴더 추가 (비어 있어도 됨)
        )
    ]
)
