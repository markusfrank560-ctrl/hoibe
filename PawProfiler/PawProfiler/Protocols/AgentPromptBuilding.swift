import Foundation
import VLMPipeline

/// Protocol for building agent-specific prompt messages.
/// Matches the contract at specs/003-paw-profiler/contracts/AgentPromptBuilding.swift.
protocol AgentPromptBuilding: Sendable {
    func buildGateMessages(imageData: Data) -> [ChatMessage]
    func buildAgentMessages(agentId: String, framesData: [Data], timestamps: [String]) -> [ChatMessage]
    func buildCoordinatorMessages(aggregatedData: Data) -> [ChatMessage]
}
