import Foundation
import Testing
@testable import PawProfiler
import VLMPipeline

@Suite("Frame Extraction (Real Video)")
struct FrameExtractionTests {

    private func videoURL() throws -> URL {
        guard let url = Bundle.module.url(
            forResource: "happy-cat",
            withExtension: "mp4",
            subdirectory: "Fixtures/Videos"
        ) else {
            throw FixtureError.missingVideo("happy-cat.mp4")
        }
        return url
    }

    // MARK: - Basic Extraction

    @Test("extracts requested number of frames from real video")
    func extractsFrames() async throws {
        let extractor = FrameExtractor()
        let url = try videoURL()

        let frameData = try await extractor.extractFrames(
            from: url,
            count: 6,
            window: (start: 0.0, end: 1.0),
            maxWidth: 960,
            jpegQuality: 0.85
        )

        #expect(frameData.framesJPEG.count == 6)
        #expect(frameData.timestamps.count == 6)
        #expect(frameData.sharpnessScores.count == 6)
    }

    // MARK: - Sharpest Frame Selection

    @Test("extractSharpestFrames returns sorted by sharpness")
    func sharpestFrames() async throws {
        let extractor = FrameExtractor()
        let url = try videoURL()

        let frameData = try await extractor.extractSharpestFrames(
            from: url,
            topN: 4,
            candidateCount: 8,
            window: (start: 0.0, end: 1.0),
            maxWidth: 960,
            jpegQuality: 0.85
        )

        #expect(frameData.framesJPEG.count == 4)
        let topIndices = frameData.indicesBySharpness
        // First index should point to the sharpest frame
        let sharpest = frameData.sharpnessScores[topIndices[0]]
        let secondSharpest = frameData.sharpnessScores[topIndices[1]]
        #expect(sharpest >= secondSharpest)
    }

    // MARK: - JPEG Validity

    @Test("extracted frames are valid JPEG data")
    func framesAreValidJPEG() async throws {
        let extractor = FrameExtractor()
        let url = try videoURL()

        let frameData = try await extractor.extractFrames(
            from: url,
            count: 3,
            window: (start: 0.0, end: 1.0),
            maxWidth: 960,
            jpegQuality: 0.85
        )

        for (i, jpeg) in frameData.framesJPEG.enumerated() {
            // JPEG magic bytes: FF D8 FF
            #expect(jpeg.count > 100, "Frame \(i) too small: \(jpeg.count) bytes")
            #expect(jpeg[0] == 0xFF, "Frame \(i) missing JPEG SOI marker")
            #expect(jpeg[1] == 0xD8, "Frame \(i) missing JPEG SOI marker")
        }
    }

    // MARK: - Timestamps

    @Test("timestamps are monotonically increasing")
    func timestampsMonotonic() async throws {
        let extractor = FrameExtractor()
        let url = try videoURL()

        let frameData = try await extractor.extractFrames(
            from: url,
            count: 6,
            window: (start: 0.0, end: 1.0),
            maxWidth: 960,
            jpegQuality: 0.85
        )

        for i in 1..<frameData.timestamps.count {
            #expect(
                frameData.timestamps[i] > frameData.timestamps[i - 1],
                "Timestamp \(i) (\(frameData.timestamps[i])) not after \(i-1) (\(frameData.timestamps[i-1]))"
            )
        }
    }

    // MARK: - Sharpness Scores

    @Test("sharpness scores are positive")
    func sharpnessPositive() async throws {
        let extractor = FrameExtractor()
        let url = try videoURL()

        let frameData = try await extractor.extractFrames(
            from: url,
            count: 4,
            window: (start: 0.0, end: 1.0),
            maxWidth: 960,
            jpegQuality: 0.85
        )

        for (i, score) in frameData.sharpnessScores.enumerated() {
            #expect(score > 0, "Sharpness score \(i) should be positive, got \(score)")
        }
    }

    // MARK: - Windowed Extraction

    @Test("window parameter limits extraction to temporal range")
    func windowedExtraction() async throws {
        let extractor = FrameExtractor()
        let url = try videoURL()

        // Extract from first half only
        let firstHalf = try await extractor.extractFrames(
            from: url,
            count: 3,
            window: (start: 0.0, end: 0.5),
            maxWidth: 960,
            jpegQuality: 0.85
        )

        // Extract from second half only
        let secondHalf = try await extractor.extractFrames(
            from: url,
            count: 3,
            window: (start: 0.5, end: 1.0),
            maxWidth: 960,
            jpegQuality: 0.85
        )

        // First half timestamps should all be before second half
        if let lastFirst = firstHalf.timestamps.last, let firstSecond = secondHalf.timestamps.first {
            #expect(lastFirst <= firstSecond, "First half should not exceed second half")
        }
    }
}

// MARK: - Errors

enum FixtureError: Error, CustomStringConvertible {
    case missingVideo(String)
    case missingFixture(String)

    var description: String {
        switch self {
        case .missingVideo(let name): "Video fixture not found: \(name)"
        case .missingFixture(let name): "JSON fixture not found: \(name)"
        }
    }
}
