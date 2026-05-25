import Foundation
import VLMPipeline

/// Breed and archetype visual estimation agent (Salonen et al. 2019).
struct BreedArchetypeAgent: BehaviorAnalyzing, @unchecked Sendable {
    let agentId = "breed"
    let domain = "Breed & Archetype"
    private let base: BaseAgent

    init(modelManager: any ModelManaging, promptEngine: any AgentPromptBuilding) {
        self.base = BaseAgent(
            agentId: agentId,
            domain: domain,
            modelManager: modelManager,
            promptEngine: promptEngine
        )
    }

    func analyze(frames: [Data], timestamps: [Double], config: PawProfilerConfig) async throws -> AgentResult {
        try await base.analyze(frames: frames, timestamps: timestamps, config: config)
    }
}
