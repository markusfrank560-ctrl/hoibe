import Foundation
import VLMPipeline

/// Cat-Stress-Score indicators agent (Kessler & Turner 1997).
struct StressWelfareAgent: BehaviorAnalyzing, @unchecked Sendable {
    let agentId = "stress"
    let domain = "Stress, Anxiety & Welfare"
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
