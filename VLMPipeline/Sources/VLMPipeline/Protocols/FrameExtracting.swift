import Foundation

/// Extracts and ranks video frames for analysis.
public protocol FrameExtracting: Sendable {
    func extractFrames(
        from url: URL,
        count: Int,
        window: (start: Double, end: Double),
        maxWidth: Int,
        jpegQuality: Double
    ) async throws -> FrameData

    func extractSharpestFrames(
        from url: URL,
        topN: Int,
        candidateCount: Int,
        window: (start: Double, end: Double),
        maxWidth: Int,
        jpegQuality: Double
    ) async throws -> FrameData
}
