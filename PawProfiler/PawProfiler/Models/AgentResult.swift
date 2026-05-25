import Foundation

/// Completion status of an agent's analysis.
public enum AgentStatus: String, Codable, Sendable {
    case completed
    case notObservable = "not_observable"
    case timedOut = "timed_out"
    case failed
}

/// Structured result from a single specialist agent.
public struct AgentResult: Codable, Equatable, Sendable {
    public let agentId: String
    public let domain: String
    public let status: AgentStatus
    public let traitScores: [String: Double]?
    public let observations: [String]
    public let flags: [String]
    public let confidence: Double
    public let reasoning: String?
    public let promptVersion: String

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

    public init(
        agentId: String,
        domain: String,
        status: AgentStatus,
        traitScores: [String: Double]? = nil,
        observations: [String] = [],
        flags: [String] = [],
        confidence: Double,
        reasoning: String? = nil,
        promptVersion: String
    ) {
        self.agentId = agentId
        self.domain = domain
        self.status = status
        self.traitScores = traitScores
        self.observations = observations
        self.flags = flags
        self.confidence = confidence
        self.reasoning = reasoning
        self.promptVersion = promptVersion
    }
}
