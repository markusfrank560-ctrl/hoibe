import Foundation
import VLMPipeline

/// Health-behavior correlation agent (Robertson 2008).
struct HealthBehaviorAgent: BehaviorAnalyzing, @unchecked Sendable {
    let agentId = "health"
    let domain = "Health-Behavior Correlation"
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
