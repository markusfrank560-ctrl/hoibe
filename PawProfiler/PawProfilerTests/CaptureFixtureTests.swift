import Foundation
import Testing
@testable import PawProfiler
import VLMPipeline

/// Captures real VLM responses and merges them into an existing ground-truth fixture.
///
/// **Workflow:**
/// 1. Create a fixture JSON with `ground_truth` filled in and `recorded_responses: {}`
/// 2. Add a capture method below referencing the fixture + video
/// 3. Create marker and run:
///    `touch PawProfiler/.capture_fixtures && swift test --filter captureHappyCat`
/// 4. Review the updated fixture — VLM responses are merged in
/// 5. Clean up: `rm PawProfiler/.capture_fixtures`
@Suite("Capture Fixture")
struct CaptureFixtureTests {

    @Test("capture happy-cat relaxing fixture from real VLM")
    func captureHappyCatRelaxing() async throws {
        guard isCaptureEnabled() else { return }
        try await captureFixture(fixtureName: "happy-cat_relaxing_001", videoName: "happy-cat")
    }

    // MARK: - Guard

    /// Returns true only if `.capture_fixtures` marker file exists in PawProfiler/.
    private func isCaptureEnabled() -> Bool {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // PawProfilerTests/
            .deletingLastPathComponent()  // PawProfiler/
        let marker = projectRoot.appendingPathComponent(".capture_fixtures")
        let exists = FileManager.default.fileExists(atPath: marker.path)
        if !exists {
            print("⏭️ Skipping capture test — create PawProfiler/.capture_fixtures to enable")
        }
        return exists
    }

    // MARK: - Capture Engine

    private func captureFixture(fixtureName: String, videoName: String) async throws {
        let fixtureURL = fixturesSourceDir().appendingPathComponent("\(fixtureName).json")
        let videoURL = try fixtureVideoURL(videoName)

        // 1. Load existing ground truth
        let existingData = try Data(contentsOf: fixtureURL)
        var fixtureJSON = try JSONSerialization.jsonObject(with: existingData) as! [String: Any]
        let groundTruth = fixtureJSON["ground_truth"] as? [String: Any] ?? [:]

        print("🐱 Capturing VLM responses for: \(fixtureName)")
        print("   Ground truth: \(groundTruth["category"] ?? "?") — \(groundTruth["description"] ?? "?")")
        print("   Model will auto-download if not cached (~2.5 GB)")

        // 2. Run real pipeline with recording
        let recorder = RecordingModelManager()
        let extractor = FrameExtractor()
        let profiler = CatProfiler(modelManager: recorder, frameExtractor: extractor)

        let profile = try await profiler.analyze(videoURL: videoURL, mode: .quick)

        // 3. Print debug log
        print("\n📋 Debug Log:")
        for entry in profiler.debugLog {
            print("   \(entry.elapsed) \(entry.message)")
        }

        // 4. Merge recorded responses into fixture
        let responses = recorder.exportRecordedResponses()
        fixtureJSON["recorded_responses"] = responses

        // 5. If archetype was null in ground truth, fill it from VLM output
        if var gt = fixtureJSON["ground_truth"] as? [String: Any] {
            if gt["expected_archetype"] is NSNull || gt["expected_archetype"] == nil {
                gt["expected_archetype"] = profile.archetypeLabel
                gt["labeler"] = "vlm_capture+manual"
                fixtureJSON["ground_truth"] = gt
            }
        }

        // 6. Write updated fixture
        let outputData = try JSONSerialization.data(
            withJSONObject: fixtureJSON,
            options: [.prettyPrinted, .sortedKeys]
        )
        try outputData.write(to: fixtureURL)

        print("\n✅ Fixture updated: \(fixtureURL.path)")
        print("   Archetype: \(profile.archetypeLabel)")
        print("   Agents completed: \(profile.agentResults.filter { $0.status == .completed }.count)/6")
        print("   VLM calls recorded: \(recorder.recordings.count)")
        print("   Responses: \(responses.keys.sorted().joined(separator: ", "))")

        // Sanity checks
        #expect(!profile.archetypeLabel.isEmpty)
        #expect(profile.agentResults.count == 6)
        #expect(recorder.recordings.count == 8, "Expected 8 VLM calls (gate + 6 agents + coordinator)")
    }

    // MARK: - Helpers

    private func fixtureVideoURL(_ name: String) throws -> URL {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "mp4",
            subdirectory: "Fixtures/Videos"
        ) else {
            throw FixtureError.missingVideo("\(name).mp4")
        }
        return url
    }

    /// Returns the source tree Fixtures directory (not the build copy).
    private func fixturesSourceDir() -> URL {
        let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        return testDir.appendingPathComponent("Fixtures")
    }
}
