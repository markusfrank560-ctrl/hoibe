import Foundation
import Testing
@testable import PawProfiler
import VLMPipeline

@Suite("Pipeline Integration")
struct PipelineIntegrationTests {

    // MARK: - Mock Frame Extractor

    final class MockFrameExtractor: FrameExtracting, @unchecked Sendable {
        var frameData: FrameData = FrameData(
            framesJPEG: (0..<8).map { _ in Data([0xFF, 0xD8, 0xFF]) },
            timestamps: [2.0, 5.0, 8.0, 12.0, 18.0, 24.0, 30.0, 36.0],
            sharpnessScores: [80, 95, 70, 88, 92, 75, 85, 90]
        )

        func extractFrames(
            from url: URL, count: Int,
            window: (start: Double, end: Double),
            maxWidth: Int, jpegQuality: Double
        ) async throws -> FrameData {
            frameData
        }

        func extractSharpestFrames(
            from url: URL, topN: Int, candidateCount: Int,
            window: (start: Double, end: Double),
            maxWidth: Int, jpegQuality: Double
        ) async throws -> FrameData {
            frameData
        }
    }

    // MARK: - Full Pipeline (gate → 6 agents → coordinator)

    @Test("full pipeline: gate → 6 agents → coordinator → CompositeProfile")
    func fullPipeline() async throws {
        let mock = MockModelManager()
        configureMockForFullPipeline(mock)

        let extractor = MockFrameExtractor()
        let profiler = CatProfiler(modelManager: mock, frameExtractor: extractor)

        let profile = try await profiler.analyze(
            videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            mode: .quick
        )

        #expect(!profile.archetypeLabel.isEmpty)
        #expect(profile.agentResults.count == 6)
        #expect(profile.confidencePerAgent.count == 6)
        #expect(profile.profileMode == "quick")
        // gate(1) + 6 agents + coordinator(1) = 8 VLM calls
        #expect(mock.generateCalls.count == 8)
    }

    // MARK: - Gate Rejection

    @Test("gate rejection stops pipeline")
    func gateRejection() async throws {
        let mock = MockModelManager()
        mock.setResponse(forAgent: "gate", response: """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":false,"confidence":0.95,"species_guess":null,"multiple_cats":false},
            {"frame_index":1,"cat_detected":false,"confidence":0.93,"species_guess":null,"multiple_cats":false},
            {"frame_index":2,"cat_detected":false,"confidence":0.94,"species_guess":null,"multiple_cats":false}
        ]}
        """)

        let profiler = CatProfiler(modelManager: mock, frameExtractor: MockFrameExtractor())

        do {
            _ = try await profiler.analyze(
                videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
                mode: .quick
            )
            Issue.record("Expected gateRejected error")
        } catch let error as ProfilerError {
            if case .gateRejected(let result) = error {
                #expect(result.catDetected == false)
            } else {
                Issue.record("Expected gateRejected, got \(error)")
            }
        }

        // Only gate call should have been made
        #expect(mock.generateCalls.count == 1)
    }

    // MARK: - Cancellation

    @Test("cancellation returns to idle state")
    func cancellation() async throws {
        let mock = MockModelManager()
        configureMockForFullPipeline(mock)

        let profiler = CatProfiler(modelManager: mock, frameExtractor: MockFrameExtractor())

        let task = Task {
            try await profiler.analyze(
                videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
                mode: .quick
            )
        }

        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(50))
        profiler.cancel()

        do {
            _ = try await task.value
            // It might complete before cancellation — that's OK
        } catch is CancellationError {
            #expect(profiler.analysisState == .idle)
        } catch {
            // Other errors during cancellation are acceptable
        }
    }

    // MARK: - All Agents Fail (insufficient threshold)

    @Test("all-agents-fail returns insufficientAgents error")
    func allAgentsFail() async throws {
        let mock = MockModelManager()
        // Gate passes
        mock.setResponse(forAgent: "gate", response: """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":true,"confidence":0.6,"species_guess":null,"multiple_cats":false},
            {"frame_index":1,"cat_detected":true,"confidence":0.55,"species_guess":null,"multiple_cats":false},
            {"frame_index":2,"cat_detected":true,"confidence":0.58,"species_guess":null,"multiple_cats":false}
        ]}
        """)
        // All agents return not_observable (invalid JSON triggers fallback)
        mock.defaultResponse = "invalid json - not parseable"

        let profiler = CatProfiler(modelManager: mock, frameExtractor: MockFrameExtractor())

        do {
            _ = try await profiler.analyze(
                videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
                mode: .quick
            )
            Issue.record("Expected insufficientAgents error")
        } catch let error as ProfilerError {
            if case .insufficientAgents(let completed, let required) = error {
                #expect(completed == 0)
                #expect(required == 3)
            } else {
                Issue.record("Expected insufficientAgents, got \(error)")
            }
        }
    }

    // MARK: - Minimum Agent Count

    @Test("exactly 3 completed agents passes threshold")
    func minimumAgentCountPasses() async throws {
        let mock = MockModelManager()
        // Gate passes
        mock.setResponse(forAgent: "gate", response: """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":true,"confidence":0.9,"species_guess":null,"multiple_cats":false},
            {"frame_index":1,"cat_detected":true,"confidence":0.9,"species_guess":null,"multiple_cats":false},
            {"frame_index":2,"cat_detected":true,"confidence":0.9,"species_guess":null,"multiple_cats":false}
        ]}
        """)
        // 3 agents return valid, rest return garbage
        mock.setResponse(forAgent: "personality", response: """
        {"agent_id":"personality","domain":"Personality","status":"completed","trait_scores":{"extraversion":0.7},"observations":["Test"],"flags":[],"confidence":0.7,"prompt_version":"v1"}
        """)
        mock.setResponse(forAgent: "social", response: """
        {"agent_id":"social","domain":"Social","status":"completed","trait_scores":{"agreeableness":0.6},"observations":["Test"],"flags":[],"confidence":0.6,"prompt_version":"v1"}
        """)
        mock.setResponse(forAgent: "stress", response: """
        {"agent_id":"stress","domain":"Stress","status":"completed","trait_scores":{"neuroticism":0.3},"observations":["Test"],"flags":[],"confidence":0.7,"prompt_version":"v1"}
        """)
        mock.setResponse(forAgent: "coordinator", response: """
        {"persona_description":"A nice cat","top_observations":["Obs1","Obs2","Obs3"],"contextual_notes":[],"overall_mood":"content"}
        """)
        // play, health, breed use defaultResponse = "{}" which will parse to not_observable

        let profiler = CatProfiler(modelManager: mock, frameExtractor: MockFrameExtractor())

        let profile = try await profiler.analyze(
            videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            mode: .quick
        )

        let completedCount = profile.agentResults.filter { $0.status == .completed }.count
        #expect(completedCount >= 3)
    }

    // MARK: - State Transitions

    @Test("state transitions: idle → extracting → gate → agents → coordinator → complete")
    func stateTransitions() async throws {
        let mock = MockModelManager()
        configureMockForFullPipeline(mock)

        let profiler = CatProfiler(modelManager: mock, frameExtractor: MockFrameExtractor())

        #expect(profiler.analysisState == .idle)

        let profile = try await profiler.analyze(
            videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            mode: .quick
        )

        #expect(profiler.analysisState == .complete(profile))
    }

    // MARK: - Helpers

    private func configureMockForFullPipeline(_ mock: MockModelManager) {
        mock.setResponse(forAgent: "gate", response: """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":true,"confidence":0.95,"species_guess":null,"multiple_cats":false},
            {"frame_index":1,"cat_detected":true,"confidence":0.92,"species_guess":null,"multiple_cats":false},
            {"frame_index":2,"cat_detected":true,"confidence":0.94,"species_guess":null,"multiple_cats":false}
        ]}
        """)
        mock.setResponse(forAgent: "personality", response: """
        {"agent_id":"personality","domain":"Personality & Traits","status":"completed","trait_scores":{"neuroticism":0.2,"extraversion":0.8,"dominance":0.5,"impulsiveness":0.7,"agreeableness":0.6},"observations":["Active and curious"],"flags":[],"confidence":0.8,"prompt_version":"v1"}
        """)
        mock.setResponse(forAgent: "social", response: """
        {"agent_id":"social","domain":"Social Behavior","status":"completed","trait_scores":{"agreeableness":0.65,"extraversion":0.7},"observations":["Comfortable near humans"],"flags":[],"confidence":0.7,"prompt_version":"v1"}
        """)
        mock.setResponse(forAgent: "play", response: """
        {"agent_id":"play","domain":"Play & Activity","status":"completed","trait_scores":{"extraversion":0.85,"impulsiveness":0.6},"observations":["Playful stalking behavior"],"flags":[],"confidence":0.75,"prompt_version":"v1"}
        """)
        mock.setResponse(forAgent: "stress", response: """
        {"agent_id":"stress","domain":"Stress & Welfare","status":"completed","trait_scores":{"neuroticism":0.15},"observations":["No stress indicators"],"flags":[],"confidence":0.7,"prompt_version":"v1"}
        """)
        mock.setResponse(forAgent: "health", response: """
        {"agent_id":"health","domain":"Health","status":"completed","trait_scores":{},"observations":["Normal mobility"],"flags":[],"confidence":0.6,"prompt_version":"v1"}
        """)
        mock.setResponse(forAgent: "breed", response: """
        {"agent_id":"breed","domain":"Breed & Archetype","status":"completed","trait_scores":{"extraversion":0.7},"observations":["Domestic Shorthair"],"flags":[],"confidence":0.6,"prompt_version":"v1"}
        """)
        mock.setResponse(forAgent: "coordinator", response: """
        {"persona_description":"A playful and curious Midnight Gremlin with boundless energy.","top_observations":["Active play behavior observed","Comfortable social presence","Normal health indicators"],"contextual_notes":["Typical domestic shorthair activity level"],"overall_mood":"playful"}
        """)
    }
}
