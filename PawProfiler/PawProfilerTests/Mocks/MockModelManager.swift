import Foundation
import VLMPipeline

/// Mock implementation of ModelManaging for deterministic testing.
/// Returns pre-recorded VLM responses instead of real inference.
final class MockModelManager: ModelManaging, @unchecked Sendable {
    var state: ModelDownloadState = .ready
    var isReady: Bool = true

    /// Map of response keys to pre-recorded responses.
    /// Keys are matched against the system prompt content to route responses.
    var responses: [String: String] = [:]

    /// Default response if no key matches.
    var defaultResponse: String = "{}"

    /// Track calls for verification.
    private(set) var generateCalls: [(messages: [ChatMessage], maxTokens: Int, temperature: Double)] = []

    func tryLoadCached() async -> Bool { true }
    func startDownload(allowCellular: Bool) async throws {}
    func pauseDownload() {}
    func deleteModel() throws {}

    func generate(messages: [ChatMessage], maxTokens: Int, temperature: Double) async throws -> String {
        generateCalls.append((messages, maxTokens, temperature))

        // Route response based on system prompt content
        let systemContent = messages.first(where: { $0.role == .system })?.text ?? ""

        for (key, response) in responses {
            if systemContent.contains(key) {
                return response
            }
        }

        return defaultResponse
    }

    /// Configure a response for a specific agent by embedding a keyword in routing.
    func setResponse(forAgent agentId: String, response: String) {
        // Agent system prompts contain their domain name
        let routingKeys: [String: String] = [
            "gate": "cat detection specialist",
            "personality": "feline personality specialist",
            "social": "feline social behavior specialist",
            "play": "feline play and activity specialist",
            "stress": "feline stress and welfare specialist",
            "health": "feline health-behavior correlation specialist",
            "breed": "feline breed and archetype specialist",
            "coordinator": "cat persona writer"
        ]

        if let key = routingKeys[agentId] {
            responses[key] = response
        }
    }
}
