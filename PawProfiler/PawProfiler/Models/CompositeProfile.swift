import Foundation

/// Complete profile synthesized from all agent results by the Hybrid Coordinator.
public struct CompositeProfile: Codable, Equatable, Sendable {
    public let felineFiveScores: FelineFiveScores
    public let archetypeLabel: String
    public let archetypeDescription: String
    public let overallMood: String
    public let breedEstimate: [BreedEstimate]
    public let stressIndicators: [String]
    public let healthFlags: [String]
    public let topObservations: [String]
    public let contextualNotes: [String]
    public let confidencePerAgent: [String: Double]
    public let agentResults: [AgentResult]
    public let modelName: String
    public let analysisVersion: String
    public let analyzedAt: String
    public let inputType: String
    public let profileMode: String

    enum CodingKeys: String, CodingKey {
        case felineFiveScores = "feline_five_scores"
        case archetypeLabel = "archetype_label"
        case archetypeDescription = "archetype_description"
        case overallMood = "overall_mood"
        case breedEstimate = "breed_estimate"
        case stressIndicators = "stress_indicators"
        case healthFlags = "health_flags"
        case topObservations = "top_observations"
        case contextualNotes = "contextual_notes"
        case confidencePerAgent = "confidence_per_agent"
        case agentResults = "agent_results"
        case modelName = "model_name"
        case analysisVersion = "analysis_version"
        case analyzedAt = "analyzed_at"
        case inputType = "input_type"
        case profileMode = "profile_mode"
    }

    public init(
        felineFiveScores: FelineFiveScores,
        archetypeLabel: String,
        archetypeDescription: String,
        overallMood: String,
        breedEstimate: [BreedEstimate] = [],
        stressIndicators: [String] = [],
        healthFlags: [String] = [],
        topObservations: [String],
        contextualNotes: [String] = [],
        confidencePerAgent: [String: Double],
        agentResults: [AgentResult],
        modelName: String,
        analysisVersion: String,
        analyzedAt: String,
        inputType: String = "video",
        profileMode: String
    ) {
        self.felineFiveScores = felineFiveScores
        self.archetypeLabel = archetypeLabel
        self.archetypeDescription = archetypeDescription
        self.overallMood = overallMood
        self.breedEstimate = breedEstimate
        self.stressIndicators = stressIndicators
        self.healthFlags = healthFlags
        self.topObservations = topObservations
        self.contextualNotes = contextualNotes
        self.confidencePerAgent = confidencePerAgent
        self.agentResults = agentResults
        self.modelName = modelName
        self.analysisVersion = analysisVersion
        self.analyzedAt = analyzedAt
        self.inputType = inputType
        self.profileMode = profileMode
    }
}
