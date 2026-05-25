// SPDX-License-Identifier: MIT
// Contract: ProfileCoordinating protocol — Hybrid Coordinator

import Foundation

/// Aggregated Feline Five personality scores.
struct FelineFiveScores: Codable, Equatable, Sendable {
    let neuroticism: Double      // 0.0–1.0
    let extraversion: Double     // 0.0–1.0
    let dominance: Double        // 0.0–1.0
    let impulsiveness: Double    // 0.0–1.0
    let agreeableness: Double    // 0.0–1.0
}

/// Breed estimate with confidence.
struct BreedEstimate: Codable, Equatable, Sendable {
    let breed: String
    let confidence: Double
    let traits: [String]
}

/// Complete profile synthesized from all agent results.
struct CompositeProfile: Codable, Equatable, Sendable {
    let felineFiveScores: FelineFiveScores
    let archetypeLabel: String
    let archetypeDescription: String
    let overallMood: String
    let breedEstimate: [BreedEstimate]
    let stressIndicators: [String]
    let healthFlags: [String]
    let topObservations: [String]
    let contextualNotes: [String]
    let confidencePerAgent: [String: Double]
    let agentResults: [AgentResult]
    let modelName: String
    let analysisVersion: String
    let analyzedAt: String
    let inputType: String
    let profileMode: String

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
}

/// Hybrid coordinator: code-based aggregation + VLM persona prose.
protocol ProfileCoordinating: Sendable {

    /// Synthesize a composite profile from agent results.
    ///
    /// Code-based steps (deterministic):
    /// 1. Aggregate Feline-Five scores (confidence-weighted average)
    /// 2. Look up archetype from score pattern
    /// 3. Collect stress indicators and health flags
    ///
    /// VLM-based step (1 inference call):
    /// 4. Generate persona description, top observations, contextual notes
    ///
    /// - Parameters:
    ///   - agentResults: Results from all completed agents.
    ///   - config: Pipeline configuration.
    /// - Returns: CompositeProfile with full synthesis.
    func synthesize(
        agentResults: [AgentResult],
        config: PawProfilerConfig
    ) async throws -> CompositeProfile
}
