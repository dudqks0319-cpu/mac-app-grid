// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LaunchPadReborn",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "LaunchPadReborn"
        )
    ]
)
