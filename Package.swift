// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hoibe",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", from: "2.29.1"),
    ],
    targets: [
        .executableTarget(
            name: "Hoibe",
            dependencies: [
                .product(name: "MLXVLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
            ],
            path: "ios/Hoibe",
            exclude: ["Hoibe.entitlements"],
            resources: [
                .copy("Resources/Prompts")
            ]
        ),
        .testTarget(
            name: "HoibeTests",
            dependencies: ["Hoibe"],
            path: "ios/HoibeTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
