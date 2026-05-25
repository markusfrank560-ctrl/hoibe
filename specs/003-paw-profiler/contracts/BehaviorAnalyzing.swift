// SPDX-License-Identifier: MIT
// Contract: BehaviorAnalyzing protocol — Single specialist agent

import Foundation

/// Completion status of an agent's analysis.
enum AgentStatus: String, Codable, Sendable {
    case completed
    case notObservable = "not_observable"
    case timedOut = "timed_out"
    case failed
}

/// Structured result from a single specialist agent.
struct AgentResult: Codable, Equatable, Sendable {
    let agentId: String
    let domain: String
    let status: AgentStatus
    let traitScores: [String: Double]?
    let observations: [String]
    let flags: [String]
    let confidence: Double
    let reasoning: String?
    let promptVersion: String

    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case domain
        case status
        case traitScores = "trait_scores"
        case observations
        case flags
        case confidence
        case reasoning
        case promptVersion = "prompt_version"
    }
}

/// A specialist behavior analysis agent.
/// Each agent focuses on a single domain of cat behavior.
protocol BehaviorAnalyzing: Sendable {

    /// Unique agent identifier (e.g., "personality", "stress").
    var agentId: String { get }

    /// Human-readable domain name (e.g., "Personality & Traits").
    var domain: String { get }

    /// Analyze cat behavior from extracted frames.
    /// - Parameters:
    ///   - frames: JPEG-encoded frames (shared across all agents).
    ///   - timestamps: Frame timestamps in seconds.
    ///   - config: Pipeline configuration.
    /// - Returns: AgentResult with domain-specific assessment.
    func analyze(
        frames: [Data],
        timestamps: [Double],
        config: PawProfilerConfig
    ) async throws -> AgentResult
}
