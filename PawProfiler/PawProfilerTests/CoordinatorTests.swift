import Foundation
import Testing
@testable import PawProfiler
import VLMPipeline

@Suite("ProfileCoordinator")
struct CoordinatorTests {
    let promptEngine = AgentPromptEngine()

    private func makeCompletedResult(
        agentId: String,
        domain: String,
        traitScores: [String: Double],
        confidence: Double = 0.75,
        flags: [String] = [],
        observations: [String] = ["Test observation"]
    ) -> AgentResult {
        AgentResult(
            agentId: agentId,
            domain: domain,
            status: .completed,
            traitScores: traitScores,
            observations: observations,
            flags: flags,
            confidence: confidence,
            promptVersion: "v1"
        )
    }

    private func makeCoordinatorMock() -> MockModelManager {
        let mock = MockModelManager()
        mock.setResponse(forAgent: "coordinator", response: """
        {
            "persona_description": "A playful and curious cat with boundless energy.",
            "top_observations": ["Active play behavior", "Relaxed social presence", "Healthy mobility"],
            "contextual_notes": ["Orange tabby"],
            "overall_mood": "playful"
        }
        """)
        return mock
    }

    // MARK: - Score Aggregation

    @Test("confidence-weighted score aggregation")
    func scoreAggregation() async throws {
        let mock = makeCoordinatorMock()
        let coordinator = ProfileCoordinator(modelManager: mock, promptEngine: promptEngine)

        let results = [
            makeCompletedResult(
                agentId: "personality",
                domain: "Personality",
                traitScores: ["extraversion": 0.8, "neuroticism": 0.2],
                confidence: 0.9
            ),
            makeCompletedResult(
                agentId: "play",
                domain: "Play",
                traitScores: ["extraversion": 0.6, "neuroticism": 0.4],
                confidence: 0.3
            ),
        ]

        let profile = try await coordinator.synthesize(agentResults: results, config: PawProfilerConfig())

        // Weighted: E = (0.8*0.9 + 0.6*0.3) / (0.9+0.3) = 0.9/1.2 = 0.75
        // Weighted: N = (0.2*0.9 + 0.4*0.3) / (0.9+0.3) = 0.3/1.2 = 0.25
        #expect(abs(profile.felineFiveScores.extraversion - 0.75) < 0.01)
        #expect(abs(profile.felineFiveScores.neuroticism - 0.25) < 0.01)
    }

    // MARK: - Partial Results

    @Test("partial results: skip not_observable and timed_out agents")
    func partialResults() async throws {
        let mock = makeCoordinatorMock()
        let coordinator = ProfileCoordinator(modelManager: mock, promptEngine: promptEngine)

        let results = [
            makeCompletedResult(
                agentId: "personality",
                domain: "Personality",
                traitScores: ["extraversion": 0.7],
                confidence: 0.8
            ),
            AgentResult(
                agentId: "social",
                domain: "Social",
                status: .notObservable,
                confidence: 0.0,
                promptVersion: "v1"
            ),
            AgentResult(
                agentId: "play",
                domain: "Play",
                status: .timedOut,
                confidence: 0.0,
                reasoning: "Timed out",
                promptVersion: "v1"
            ),
            makeCompletedResult(
                agentId: "stress",
                domain: "Stress",
                traitScores: ["neuroticism": 0.3],
                confidence: 0.7
            ),
            makeCompletedResult(
                agentId: "health",
                domain: "Health",
                traitScores: [:],
                confidence: 0.5
            ),
            makeCompletedResult(
                agentId: "breed",
                domain: "Breed",
                traitScores: ["extraversion": 0.6],
                confidence: 0.6
            ),
        ]

        let profile = try await coordinator.synthesize(agentResults: results, config: PawProfilerConfig())

        // Should still produce a profile — 4 out of 6 agents completed (>= 3 minimum)
        #expect(!profile.archetypeLabel.isEmpty)
        // Confidence map should include all 6 agents
        #expect(profile.confidencePerAgent.count == 6)
        // not_observable agents should have 0.0 confidence
        #expect(profile.confidencePerAgent["social"] == 0.0)
        #expect(profile.confidencePerAgent["play"] == 0.0)
    }

    // MARK: - VLM Persona Generation

    @Test("VLM persona generation with MockModelManager")
    func vlmPersona() async throws {
        let mock = makeCoordinatorMock()
        let coordinator = ProfileCoordinator(modelManager: mock, promptEngine: promptEngine)

        let results = [
            makeCompletedResult(agentId: "personality", domain: "Personality",
                              traitScores: ["extraversion": 0.8], confidence: 0.8),
            makeCompletedResult(agentId: "social", domain: "Social",
                              traitScores: ["agreeableness": 0.7], confidence: 0.7),
            makeCompletedResult(agentId: "play", domain: "Play",
                              traitScores: ["impulsiveness": 0.6], confidence: 0.7),
        ]

        let profile = try await coordinator.synthesize(agentResults: results, config: PawProfilerConfig())

        #expect(profile.archetypeDescription.contains("playful"))
        #expect(profile.topObservations.count == 3)
        #expect(profile.overallMood == "playful")
        #expect(profile.analysisVersion == "v1")
        #expect(profile.modelName == "qwen3-vl-4b")
        #expect(profile.inputType == "video")
    }

    // MARK: - Stress/Health Flags Collection

    @Test("stress indicators collected from agent flags")
    func stressCollection() async throws {
        let mock = makeCoordinatorMock()
        let coordinator = ProfileCoordinator(modelManager: mock, promptEngine: promptEngine)

        let results = [
            makeCompletedResult(
                agentId: "stress",
                domain: "Stress",
                traitScores: ["neuroticism": 0.8],
                confidence: 0.8,
                flags: ["stress_detected", "hiding_behavior"]
            ),
            makeCompletedResult(
                agentId: "health",
                domain: "Health",
                traitScores: [:],
                confidence: 0.6,
                flags: ["pain_indicator", "consider_vet_discussion"]
            ),
            makeCompletedResult(
                agentId: "personality",
                domain: "Personality",
                traitScores: ["neuroticism": 0.7],
                confidence: 0.7
            ),
        ]

        let profile = try await coordinator.synthesize(agentResults: results, config: PawProfilerConfig())

        #expect(profile.stressIndicators.contains("stress_detected"))
        #expect(profile.stressIndicators.contains("hiding_behavior"))
        #expect(profile.healthFlags.contains("pain_indicator"))
        #expect(profile.healthFlags.contains("consider_vet_discussion"))
    }

    // MARK: - Profile Mode

    @Test("quick mode sets profileMode to 'quick'")
    func quickMode() async throws {
        let mock = makeCoordinatorMock()
        let coordinator = ProfileCoordinator(modelManager: mock, promptEngine: promptEngine)
        let config = PawProfilerConfig.quick()

        let results = [
            makeCompletedResult(agentId: "personality", domain: "P", traitScores: [:], confidence: 0.5),
        ]

        let profile = try await coordinator.synthesize(agentResults: results, config: config)
        #expect(profile.profileMode == "quick")
    }

    @Test("deep mode sets profileMode to 'deep'")
    func deepMode() async throws {
        let mock = makeCoordinatorMock()
        let coordinator = ProfileCoordinator(modelManager: mock, promptEngine: promptEngine)
        let config = PawProfilerConfig.deep()

        let results = [
            makeCompletedResult(agentId: "personality", domain: "P", traitScores: [:], confidence: 0.5),
        ]

        let profile = try await coordinator.synthesize(agentResults: results, config: config)
        #expect(profile.profileMode == "deep")
    }
}
