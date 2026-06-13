import Foundation
import VLMPipeline

/// Hybrid coordinator: confidence-weighted score aggregation (code) + VLM persona prose.
struct ProfileCoordinator: ProfileCoordinating {
    let modelManager: any ModelManaging
    let promptEngine: any AgentPromptBuilding

    func synthesize(
        agentResults: [AgentResult],
        config: PawProfilerConfig
    ) async throws -> CompositeProfile {
        // 1. Filter to completed agents only
        let completed = agentResults.filter { $0.status == .completed }

        // 2. Aggregate Feline Five scores (confidence-weighted)
        let felineFive = aggregateScores(completed)

        // 3. Deterministic archetype lookup
        let archetypeLabel = ArchetypeResolver.resolve(felineFive)

        // 4. Collect stress indicators and health flags
        let stressIndicators = completed
            .flatMap(\.flags)
            .filter { $0.contains("stress") || $0.contains("fear") || $0.contains("anxiety") ||
                      $0.contains("hiding") || $0.contains("overgrooming") }
        let healthFlags = completed
            .flatMap(\.flags)
            .filter { $0.contains("pain") || $0.contains("mobility") || $0.contains("grooming_anomaly") ||
                      $0.contains("activity_change") || $0.contains("vet") }

        // 5. Extract breed estimates from breed agent
        let breedEstimates = extractBreedEstimates(from: agentResults)

        // 6. Build confidence-per-agent map
        let confidencePerAgent = Dictionary(
            uniqueKeysWithValues: agentResults.map { ($0.agentId, $0.confidence) }
        )

        // 7. VLM call for persona prose
        let coordinatorInput = buildCoordinatorInput(
            felineFive: felineFive,
            archetypeLabel: archetypeLabel,
            completedResults: completed,
            stressIndicators: stressIndicators,
            healthFlags: healthFlags,
            breedEstimates: breedEstimates
        )
        let coordinatorData = try JSONSerialization.data(withJSONObject: coordinatorInput)
        let messages = promptEngine.buildCoordinatorMessages(aggregatedData: coordinatorData)

        let vlmResponse = try await modelManager.generate(
            messages: messages,
            maxTokens: config.coordinatorMaxTokens,
            temperature: config.temperature,
            imageResizeSize: nil
        )

        let personaOutput = parseCoordinatorResponse(vlmResponse)

        // 8. Build CompositeProfile
        let now = ISO8601DateFormatter().string(from: Date())
        return CompositeProfile(
            felineFiveScores: felineFive,
            archetypeLabel: archetypeLabel,
            archetypeDescription: personaOutput.personaDescription,
            overallMood: personaOutput.overallMood,
            breedEstimate: breedEstimates,
            stressIndicators: stressIndicators,
            healthFlags: healthFlags,
            topObservations: personaOutput.topObservations,
            contextualNotes: personaOutput.contextualNotes,
            confidencePerAgent: confidencePerAgent,
            agentResults: agentResults,
            modelName: "qwen3-vl-4b",
            analysisVersion: "v1",
            analyzedAt: now,
            profileMode: config.windowsPerAgent == 1 ? "quick" : "deep"
        )
    }

    // MARK: - Score Aggregation

    /// Confidence-weighted average of Feline Five scores across completed agents.
    private func aggregateScores(_ results: [AgentResult]) -> FelineFiveScores {
        let traitKeys = ["neuroticism", "extraversion", "dominance", "impulsiveness", "agreeableness"]
        var weightedSums: [String: Double] = [:]
        var weightTotals: [String: Double] = [:]

        for result in results {
            guard let scores = result.traitScores else { continue }
            let weight = max(result.confidence, 0.01) // avoid zero weight

            for key in traitKeys {
                if let value = scores[key] {
                    weightedSums[key, default: 0] += value * weight
                    weightTotals[key, default: 0] += weight
                }
            }
        }

        func score(for key: String) -> Double {
            guard let total = weightTotals[key], total > 0 else { return 0.5 }
            return weightedSums[key, default: 0] / total
        }

        return FelineFiveScores(
            neuroticism: score(for: "neuroticism"),
            extraversion: score(for: "extraversion"),
            dominance: score(for: "dominance"),
            impulsiveness: score(for: "impulsiveness"),
            agreeableness: score(for: "agreeableness")
        )
    }

    // MARK: - Breed Estimates

    private func extractBreedEstimates(from results: [AgentResult]) -> [BreedEstimate] {
        // Breed estimates come embedded in the breed agent's raw JSON response
        // For now, extract from observations if breed agent completed
        guard let breedResult = results.first(where: { $0.agentId == "breed" && $0.status == .completed }) else {
            return []
        }

        // The breed agent's observations contain breed info; the actual breed_estimates
        // field is in the raw VLM JSON but not in AgentResult. Return a basic estimate
        // from agent observations.
        let breedObs = breedResult.observations.first ?? "Unknown breed"
        return [BreedEstimate(breed: breedObs, confidence: breedResult.confidence)]
    }

    // MARK: - Coordinator Input

    private func buildCoordinatorInput(
        felineFive: FelineFiveScores,
        archetypeLabel: String,
        completedResults: [AgentResult],
        stressIndicators: [String],
        healthFlags: [String],
        breedEstimates: [BreedEstimate]
    ) -> [String: Any] {
        var agentObservations: [String: [String]] = [:]
        for result in completedResults {
            agentObservations[result.agentId] = result.observations
        }

        return [
            "feline_five_scores": [
                "neuroticism": felineFive.neuroticism,
                "extraversion": felineFive.extraversion,
                "dominance": felineFive.dominance,
                "impulsiveness": felineFive.impulsiveness,
                "agreeableness": felineFive.agreeableness
            ],
            "archetype_label": archetypeLabel,
            "agent_observations": agentObservations,
            "stress_indicators": stressIndicators,
            "health_flags": healthFlags,
            "breed_estimates": breedEstimates.map { ["breed": $0.breed, "confidence": $0.confidence] },
            "overall_mood": inferMood(from: completedResults)
        ]
    }

    private func inferMood(from results: [AgentResult]) -> String {
        // Simple mood inference from stress/activity observations
        let hasStress = results.contains { $0.flags.contains(where: { $0.contains("stress") }) }
        if hasStress { return "anxious" }

        let avgExtraversion = results
            .compactMap { $0.traitScores?["extraversion"] }
            .reduce(0, +) / max(Double(results.count), 1)

        if avgExtraversion > 0.7 { return "playful" }
        if avgExtraversion < 0.3 { return "relaxed" }
        return "content"
    }

    // MARK: - VLM Persona Response Parsing

    private struct CoordinatorOutput {
        let personaDescription: String
        let topObservations: [String]
        let contextualNotes: [String]
        let overallMood: String
    }

    private func parseCoordinatorResponse(_ raw: String) -> CoordinatorOutput {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CoordinatorOutput(
                personaDescription: "A unique cat with their own special personality.",
                topObservations: ["Analysis completed"],
                contextualNotes: [],
                overallMood: "content"
            )
        }

        return CoordinatorOutput(
            personaDescription: json["persona_description"] as? String ?? "A unique cat with their own special personality.",
            topObservations: json["top_observations"] as? [String] ?? ["Analysis completed"],
            contextualNotes: json["contextual_notes"] as? [String] ?? [],
            overallMood: json["overall_mood"] as? String ?? "content"
        )
    }
}
