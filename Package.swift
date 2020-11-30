// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Cachyr",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v4)
    ],
    products: [
        .library(
            name: "Cachyr",
            targets: ["Cachyr"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Cachyr",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "CachyrTests",
            dependencies: ["Cachyr"]),
    ],
    swiftLanguageVersions: [.v5]
)
