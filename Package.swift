// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "BlakeHash",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "BlakeHash",
            targets: ["BlakeHash"]
        )
    ],
    targets: [
        .target(
            name: "BlakeHash",
            path: "ios/Sources/BlakeHash"
        ),
        .testTarget(
            name: "BlakeHashTests",
            dependencies: ["BlakeHash"],
            path: "ios/Tests/BlakeHashTests"
        )
    ]
)
