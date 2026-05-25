import Foundation
import VLMPipeline

/// Attachment style and social dynamics agent (Vitale Shreve & Udell 2017).
struct SocialBehaviorAgent: BehaviorAnalyzing, @unchecked Sendable {
    let agentId = "social"
    let domain = "Social Behavior & Human Bonding"
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
