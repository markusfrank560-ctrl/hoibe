import Foundation
import VLMPipeline

/// Builds chat messages for specialist agent prompts.
///
/// ## Prompt architecture (2026-05-25)
///
/// System role carries the full domain knowledge: persona, scientific
/// framework, scoring scales, observable indicators, flag vocabularies,
/// and the expected JSON response schema. User role carries only the
/// concrete task instruction and attached images/data.
///
/// Prompt text files under `Resources/Prompts/{agentId}/v1/system.txt` are
/// the single source of truth and are loaded at runtime.
struct AgentPromptEngine: AgentPromptBuilding {

    /// Load a prompt template from the bundle.
    /// Path: Prompts/{subdirectory}/system.txt
    private func loadPrompt(subdirectory: String) -> String {
        // SPM resources: Bundle.module, subdirectory under "Prompts"
        guard let url = Bundle.module.url(
            forResource: "system",
            withExtension: "txt",
            subdirectory: "Prompts/\(subdirectory)"
        ), let content = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("Missing bundled prompt: Prompts/\(subdirectory)/system.txt")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Gate

    func buildGateMessages(framesData: [Data]) -> [ChatMessage] {
        let system = loadPrompt(subdirectory: "gate/v1")
        return [
            ChatMessage(role: .system, text: system),
            ChatMessage(role: .user, text: "Analyze these frames. For each frame, determine if a cat is present. Respond with JSON only.", images: framesData)
        ]
    }

    // MARK: - Specialist Agents

    func buildAgentMessages(
        agentId: String,
        framesData: [Data],
        timestamps: [String]
    ) -> [ChatMessage] {
        let system = loadPrompt(subdirectory: "\(agentId)/v1")
        let timestampList = timestamps.joined(separator: ", ")

        let userText = "Frames at timestamps: \(timestampList)\n\nAnalyze ONLY what you see in these specific frames. Do not use generic or placeholder observations. Respond with JSON only."
        return [
            ChatMessage(role: .system, text: system),
            ChatMessage(role: .user, text: userText, images: framesData)
        ]
    }

    // MARK: - Coordinator

    func buildCoordinatorMessages(aggregatedData: Data) -> [ChatMessage] {
        let system = loadPrompt(subdirectory: "coordinator/v1")
        guard let jsonString = String(data: aggregatedData, encoding: .utf8) else {
            fatalError("Cannot encode aggregated data as UTF-8")
        }
        return [
            ChatMessage(role: .system, text: system),
            ChatMessage(role: .user, text: "Generate the persona description for this cat profile:\n\n\(jsonString)\n\nRespond with JSON only.")
        ]
    }

    // MARK: - Available Agent IDs

    /// All specialist agent identifiers in execution order.
    static let agentIds = ["personality", "social", "play", "stress", "health", "breed"]
}
