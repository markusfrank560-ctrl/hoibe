import Foundation
import VLMPipeline

/// A specialist behavior analysis agent.
/// Matches the contract at specs/003-paw-profiler/contracts/BehaviorAnalyzing.swift.
protocol BehaviorAnalyzing: Sendable {
    var agentId: String { get }
    var domain: String { get }

    func analyze(
        frames: [Data],
        timestamps: [Double],
        config: PawProfilerConfig
    ) async throws -> AgentResult
}
