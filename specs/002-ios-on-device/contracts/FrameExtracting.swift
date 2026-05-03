// SPDX-License-Identifier: MIT
// Contract: FrameExtracting protocol

import CoreGraphics
import Foundation

/// Result of frame extraction from a video.
struct FrameData: Sendable {
    /// Extracted frames as JPEG data.
    let framesJPEG: [Data]

    /// Timestamps of extracted frames in seconds.
    let timestamps: [Double]

    /// Sharpness score (Laplacian variance) per frame.
    let sharpnessScores: [Double]
}

/// Extracts and ranks video frames for analysis.
protocol FrameExtracting: Sendable {

    /// Extract frames from a video within a time window.
    /// - Parameters:
    ///   - url: Local video file URL.
    ///   - count: Number of frames to extract.
    ///   - window: Normalized time window (0.0–1.0 start, 0.0–1.0 end).
    ///   - maxWidth: Maximum pixel width for output (height scaled proportionally).
    ///   - jpegQuality: JPEG compression quality (0.0–1.0).
    /// - Returns: FrameData with extracted frames ranked by sharpness.
    func extractFrames(
        from url: URL,
        count: Int,
        window: (start: Double, end: Double),
        maxWidth: Int,
        jpegQuality: Double
    ) async throws -> FrameData

    /// Extract the sharpest N frames from a time window.
    /// Extracts more candidates than needed, ranks by sharpness, returns top N.
    /// - Parameters:
    ///   - url: Local video file URL.
    ///   - topN: Number of sharpest frames to return.
    ///   - candidateCount: Number of candidate frames to extract before ranking.
    ///   - window: Normalized time window.
    ///   - maxWidth: Maximum pixel width.
    ///   - jpegQuality: JPEG compression quality.
    /// - Returns: FrameData with the sharpest frames only.
    func extractSharpestFrames(
        from url: URL,
        topN: Int,
        candidateCount: Int,
        window: (start: Double, end: Double),
        maxWidth: Int,
        jpegQuality: Double
    ) async throws -> FrameData
}
