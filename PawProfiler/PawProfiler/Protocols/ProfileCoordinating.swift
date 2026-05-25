import Foundation
import VLMPipeline

/// Hybrid coordinator: code-based aggregation + VLM persona prose.
/// Matches the contract at specs/003-paw-profiler/contracts/ProfileCoordinating.swift.
protocol ProfileCoordinating: Sendable {
    func synthesize(
        agentResults: [AgentResult],
        config: PawProfilerConfig
    ) async throws -> CompositeProfile
}
