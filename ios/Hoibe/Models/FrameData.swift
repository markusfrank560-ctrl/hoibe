import Foundation

/// Extracted video frames with metadata for pipeline consumption.
struct FrameData: Sendable {
    /// JPEG-encoded frame data, ordered by timestamp.
    let framesJPEG: [Data]
    /// Timestamps (seconds) of each extracted frame.
    let timestamps: [Double]
    /// Sharpness score (Laplacian variance) for each frame.
    let sharpnessScores: [Double]

    /// Returns indices sorted by sharpness (highest first).
    var indicesBySharpness: [Int] {
        sharpnessScores.enumerated()
            .sorted { $0.element > $1.element }
            .map(\.offset)
    }
}
