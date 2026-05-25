import Foundation
import VLMPipeline

/// Feline Five trait scoring agent (Litchfield et al. 2017).
struct PersonalityAgent: BehaviorAnalyzing, @unchecked Sendable {
    let agentId = "personality"
    let domain = "Personality & Traits"
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
