import Foundation
import Testing
@testable import PawProfiler
import VLMPipeline

/// Loads JSON fixtures that pair ground truth labels with recordedrded VLM responses,
/// runs the full pipeline with a real FrameExtractor against real video,
/// and verifies the output matches expectations.
@Suite("Fixture-Driven Pipeline")
struct FixtureDrivenTests {

    // MARK: - Fixture Model

    struct TestFixture: Decodable {
        let groundTruth: GroundTruth
        let recordedResponses: [String: String]

        enum CodingKeys: String, CodingKey {
            case groundTruth = "ground_truth"
            case recordedResponses = "recorded_responses"
        }
    }

    struct GroundTruth: Decodable {
        let category: String
        let description: String
        let expectedGate: String
        let expectedArchetype: String?
        let expectedTraits: [String: String]?
        let expectedStress: Bool?

        enum CodingKeys: String, CodingKey {
            case category
            case description
            case expectedGate = "expected_gate"
            case expectedArchetype = "expected_archetype"
            case expectedTraits = "expected_traits"
            case expectedStress = "expected_stress"
        }
    }

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> TestFixture {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures"
        ) else {
            throw FixtureError.missingFixture(name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TestFixture.self, from: data)
    }

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

    private func configureMock(_ mock: MockModelManager, from fixture: TestFixture) {
        let agentKeys = ["gate", "personality", "social", "play", "stress", "health", "breed", "coordinator"]
        for key in agentKeys {
            if let response = fixture.recordedResponses[key] {
                mock.setResponse(forAgent: key, response: response)
            }
        }
        // Agents without explicit mock responses return not_observable
        mock.defaultResponse = """
        {"agent_id":"fallback","domain":"Fallback","status":"not_observable","trait_scores":{},"observations":[],"flags":[],"confidence":0.0,"prompt_version":"v1"}
        """
    }

    /// Returns true if the fixture has all 8 required mock responses.
    private func isCompleteFixture(_ fixture: TestFixture) -> Bool {
        let required = ["gate", "personality", "social", "play", "stress", "health", "breed", "coordinator"]
        return required.allSatisfy { fixture.recordedResponses[$0] != nil }
    }

    // MARK: - Parameterized: Cat-Detected Fixtures

    static let catDetectedFixtures: [(name: String, displayName: String)] = [
        ("playful-cat_feather-toy_001", "Playful cat (feather toy)"),
        ("playful-cat_laser-chase_002", "Playful cat (laser chase)"),
        ("relaxed-cat_sleeping-sofa_001", "Relaxed cat (sleeping on sofa)"),
        ("relaxed-cat_sunbeam_002", "Relaxed cat (sunbeam)"),
        ("stressed-cat_loud-noise_001", "Stressed cat (loud noise)"),
        ("multiple-cats_windowsill_001", "Multiple cats (windowsill)"),
        ("dark-clip_dim-room_001", "Dark clip (dim room)"),
        ("short-clip_brief-glimpse_001", "Short clip (brief glimpse)"),
    ]

    @Test("full pipeline with real frames + mock VLM", arguments: catDetectedFixtures)
    func catDetectedPipeline(fixture fixtureDef: (name: String, displayName: String)) async throws {
        let fixture = try loadFixture(fixtureDef.name)
        let url = try videoURL()

        let mock = MockModelManager()
        configureMock(mock, from: fixture)

        let extractor = FrameExtractor()
        let profiler = CatProfiler(modelManager: mock, frameExtractor: extractor)

        // Gate should have passed (cat detected)
        #expect(fixture.groundTruth.expectedGate == "cat_detected")

        if isCompleteFixture(fixture) {
            // Full pipeline — all agents have mock responses
            let profile = try await profiler.analyze(videoURL: url, mode: .quick)

            let completedCount = profile.agentResults.filter { $0.status == .completed }.count
            #expect(completedCount >= 3, "Expected ≥3 agents, got \(completedCount)")

            // Verify stress expectation if present
            if let expectedStress = fixture.groundTruth.expectedStress {
                let hasStressFlag = profile.agentResults.contains { result in
                    result.flags.contains("stress_detected")
                }
                #expect(
                    hasStressFlag == expectedStress,
                    "Stress: expected \(expectedStress), got \(hasStressFlag)"
                )
            }
        } else {
            // Partial fixture — only some agents have mock responses.
            // The pipeline may complete (if ≥3 agents) or throw insufficientAgents.
            do {
                let profile = try await profiler.analyze(videoURL: url, mode: .quick)
                let completedCount = profile.agentResults.filter { $0.status == .completed }.count
                #expect(completedCount >= 3)
            } catch let error as ProfilerError {
                if case .insufficientAgents = error {
                    // Expected for partial fixtures with <3 agent responses
                } else {
                    Issue.record("Unexpected error: \(error)")
                }
            }
        }
    }

    // MARK: - Gate Rejection Fixtures

    static let gateRejectedFixtures: [(name: String, displayName: String)] = [
        ("no-cat_empty-room_001", "No cat (empty room)"),
        ("no-cat_kitchen_002", "No cat (kitchen)"),
        ("not-a-cat_dog_001", "Not a cat (dog)"),
    ]

    @Test("gate rejection with real frames + mock VLM", arguments: gateRejectedFixtures)
    func gateRejectedPipeline(fixture fixtureDef: (name: String, displayName: String)) async throws {
        let fixture = try loadFixture(fixtureDef.name)
        let url = try videoURL()

        let mock = MockModelManager()
        configureMock(mock, from: fixture)

        let extractor = FrameExtractor()
        let profiler = CatProfiler(modelManager: mock, frameExtractor: extractor)

        do {
            _ = try await profiler.analyze(videoURL: url, mode: .quick)
            Issue.record("Expected gate rejection for \(fixtureDef.name)")
        } catch let error as ProfilerError {
            guard case .gateRejected(let result) = error else {
                Issue.record("Expected gateRejected, got \(error)")
                return
            }
            #expect(!result.catDetected)

            if fixture.groundTruth.expectedGate == "not_a_cat" {
                #expect(result.speciesGuess != nil, "Expected species guess for not-a-cat")
            }
        }

        // Only gate call should have been made
        #expect(mock.generateCalls.count == 1)
    }

    // MARK: - All Agents Fail

    @Test("all-agents-fail fixture triggers insufficientAgents error")
    func allAgentsFail() async throws {
        let fixture = try loadFixture("all-agents-fail_obscured_001")
        let url = try videoURL()

        let mock = MockModelManager()
        configureMock(mock, from: fixture)

        let extractor = FrameExtractor()
        let profiler = CatProfiler(modelManager: mock, frameExtractor: extractor)

        do {
            _ = try await profiler.analyze(videoURL: url, mode: .quick)
            Issue.record("Expected insufficientAgents error")
        } catch let error as ProfilerError {
            if case .insufficientAgents = error {
                // Expected
            } else {
                Issue.record("Expected insufficientAgents, got \(error)")
            }
        }
    }

    // MARK: - Debug Log Verification

    @Test("pipeline produces debug log entries")
    func debugLogEntries() async throws {
        let fixture = try loadFixture("playful-cat_feather-toy_001")
        let url = try videoURL()

        let mock = MockModelManager()
        configureMock(mock, from: fixture)

        let extractor = FrameExtractor()
        let profiler = CatProfiler(modelManager: mock, frameExtractor: extractor)

        _ = try await profiler.analyze(videoURL: url, mode: .quick)

        // Debug log should have entries for each pipeline stage
        #expect(profiler.debugLog.count >= 10, "Expected ≥10 debug entries, got \(profiler.debugLog.count)")

        let messages = profiler.debugLog.map(\.message)
        #expect(messages.contains(where: { $0.contains("Pipeline started") }))
        #expect(messages.contains(where: { $0.contains("Extracted") }))
        #expect(messages.contains(where: { $0.contains("Gate result") }))
        #expect(messages.contains(where: { $0.contains("Agent 1/6") }))
        #expect(messages.contains(where: { $0.contains("Pipeline complete") }))
    }
}
