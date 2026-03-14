// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "BlakeHash",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
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
            path: "Sources/BlakeHash"
        ),
        .testTarget(
            name: "BlakeHashTests",
            dependencies: ["BlakeHash"],
            path: "Tests/BlakeHashTests"
        )
    ]
)
