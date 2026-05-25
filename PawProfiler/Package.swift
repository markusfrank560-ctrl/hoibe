// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PawProfiler",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../VLMPipeline"),
    ],
    targets: [
        .executableTarget(
            name: "PawProfiler",
            dependencies: [
                .product(name: "VLMPipeline", package: "VLMPipeline"),
            ],
            path: "PawProfiler",
            exclude: ["PawProfiler.entitlements"],
            resources: [
                .copy("Resources/Prompts")
            ]
        ),
        .testTarget(
            name: "PawProfilerTests",
            dependencies: ["PawProfiler"],
            path: "PawProfilerTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
