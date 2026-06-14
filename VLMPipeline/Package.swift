// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VLMPipeline",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "VLMPipeline", targets: ["VLMPipeline"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", exact: "2.29.1"),
        .package(url: "https://github.com/huggingface/swift-transformers.git", .upToNextMinor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "VLMPipeline",
            dependencies: [
                .product(name: "MLXVLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
                .product(name: "Hub", package: "swift-transformers"),
            ],
            path: "Sources/VLMPipeline"
        ),
    ]
)
