import Foundation
import VLMPipeline

/// Play style and activity level agent (Hall et al. 2002).
struct PlayActivityAgent: BehaviorAnalyzing, @unchecked Sendable {
    let agentId = "play"
    let domain = "Play, Activity & Predatory Behavior"
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
