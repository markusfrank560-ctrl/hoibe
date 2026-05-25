import Foundation
import VLMPipeline

/// Builds chat messages for specialist agent prompts.
/// Each agent has its own system prompt with embedded research context,
/// loaded from bundled Resources/Prompts/{agentId}/v{N}/system.txt.
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

    func buildGateMessages(imageData: Data) -> [ChatMessage] {
        let system = loadPrompt(subdirectory: "gate/v1")
        return [
            ChatMessage(role: .system, text: system),
            ChatMessage(role: .user, text: "Analyze these frames. Is there a cat? Respond with JSON only.\n/no_think", images: [imageData])
        ]
    }

    func buildGateMessages(framesData: [Data]) -> [ChatMessage] {
        let system = loadPrompt(subdirectory: "gate/v1")
        return [
            ChatMessage(role: .system, text: system),
            ChatMessage(role: .user, text: "Analyze these frames. For each frame, determine if a cat is present. Respond with JSON only.\n/no_think", images: framesData)
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
        let userText = "Analyze this cat's behavior from the following frames (timestamps: \(timestampList)). Respond with JSON only.\n/no_think"
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
            ChatMessage(role: .user, text: "Generate the persona description and contextual observations for this cat profile:\n\n\(jsonString)\n\nRespond with JSON only.\n/no_think")
        ]
    }

    // MARK: - Available Agent IDs

    /// All specialist agent identifiers in execution order.
    static let agentIds = ["personality", "social", "play", "stress", "health", "breed"]
}
