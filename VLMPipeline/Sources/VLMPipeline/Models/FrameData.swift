import Foundation

/// Extracted video frames with metadata for pipeline consumption.
public struct FrameData: Sendable {
    /// JPEG-encoded frame data, ordered by timestamp.
    public let framesJPEG: [Data]
    /// Timestamps (seconds) of each extracted frame.
    public let timestamps: [Double]
    /// Sharpness score (Laplacian variance) for each frame.
    public let sharpnessScores: [Double]

    public init(framesJPEG: [Data], timestamps: [Double], sharpnessScores: [Double]) {
        self.framesJPEG = framesJPEG
        self.timestamps = timestamps
        self.sharpnessScores = sharpnessScores
    }

    /// Returns indices sorted by sharpness (highest first).
    public var indicesBySharpness: [Int] {
        sharpnessScores.enumerated()
            .sorted { $0.element > $1.element }
            .map(\.offset)
    }
}
