// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MacAppGrid",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MacAppGrid"
        ),
        .testTarget(
            name: "MacAppGridTests",
            dependencies: ["MacAppGrid"]
        )
    ]
)
