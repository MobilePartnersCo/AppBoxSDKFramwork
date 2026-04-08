// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "AppBoxSDKBinary",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "AppBoxSDK",
            targets: ["AppBoxSDK"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "AppBoxSDK",
            path: "../../Sources/AppBoxSDK/AppBoxSDK.xcframework/AppBoxSDK.xcframework"
        )
    ]
)
