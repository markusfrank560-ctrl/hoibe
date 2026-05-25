// SPDX-License-Identifier: MIT
// Contract: AgentPromptBuilding protocol — Domain-specific prompt construction

import Foundation

/// Builds chat messages for specialist agent prompts.
/// Each agent has its own system prompt with embedded research context.
protocol AgentPromptBuilding: Sendable {

    /// Build messages for the cat detection gate prompt.
    /// - Parameter imageData: Single JPEG-encoded frame.
    /// - Returns: Chat messages for gate inference.
    func buildGateMessages(imageData: Data) -> [ChatMessage]

    /// Build messages for a specialist agent prompt.
    /// - Parameters:
    ///   - agentId: Agent identifier (e.g., "personality", "stress").
    ///   - framesData: JPEG-encoded frames for analysis.
    ///   - timestamps: Formatted timestamp strings.
    /// - Returns: Chat messages with domain-specific system prompt + frames.
    func buildAgentMessages(
        agentId: String,
        framesData: [Data],
        timestamps: [String]
    ) -> [ChatMessage]

    /// Build messages for the coordinator VLM prompt.
    /// - Parameter aggregatedData: JSON-encoded aggregated scores and observations.
    /// - Returns: Chat messages for persona prose generation.
    func buildCoordinatorMessages(
        aggregatedData: String
    ) -> [ChatMessage]
}
