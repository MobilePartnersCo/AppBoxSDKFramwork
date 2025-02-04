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
            dependencies: [],
            path: "./Sources/AppBoxPushWrap"
        )
    ]
)
