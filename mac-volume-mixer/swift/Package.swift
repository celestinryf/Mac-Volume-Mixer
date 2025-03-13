// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AudioControl",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-nio-extras.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AudioControl",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras")
            ]),
        .testTarget(
            name: "AudioControlTests",
            dependencies: ["AudioControl"]),
    ]
)