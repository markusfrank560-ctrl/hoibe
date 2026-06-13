import Foundation
import VLMPipeline

/// Wraps a real ModelManager, delegates all calls, and records every
/// generate() request/response for fixture capture.
final class RecordingModelManager: ModelManaging, @unchecked Sendable {
    private let wrapped: ModelManager
    private let lock = NSLock()

    /// Recorded (agentKey, response) pairs in call order.
    private(set) var recordings: [(agentKey: String, response: String)] = []

    var state: ModelDownloadState { wrapped.state }
    var isReady: Bool { wrapped.isReady }
    var onProgress: (@Sendable (Double) -> Void)? {
        get { wrapped.onProgress }
        set { wrapped.onProgress = newValue }
    }

    init(wrapped: ModelManager = ModelManager()) {
        self.wrapped = wrapped
    }

    func tryLoadCached() async -> Bool { await wrapped.tryLoadCached() }
    func startDownload(allowCellular: Bool) async throws { try await wrapped.startDownload(allowCellular: allowCellular) }
    func pauseDownload() { wrapped.pauseDownload() }
    func deleteModel() throws { try wrapped.deleteModel() }

    func generate(messages: [ChatMessage], maxTokens: Int, temperature: Double, imageResizeSize: Int?) async throws -> String {
        let response = try await wrapped.generate(messages: messages, maxTokens: maxTokens, temperature: temperature, imageResizeSize: imageResizeSize)

        // Identify which agent this call belongs to
        let systemContent = messages.first(where: { $0.role == .system })?.text ?? ""
        let agentKey = Self.identifyAgent(from: systemContent)

        lock.lock()
        recordings.append((agentKey: agentKey, response: response))
        lock.unlock()

        return response
    }

    /// Map system prompt keywords to agent fixture keys.
    private static let routingKeys: [(keyword: String, agent: String)] = [
        ("cat detection specialist", "gate"),
        ("feline personality specialist", "personality"),
        ("feline social behavior specialist", "social"),
        ("feline play and activity specialist", "play"),
        ("feline stress and welfare specialist", "stress"),
        ("feline health-behavior correlation specialist", "health"),
        ("feline breed and archetype specialist", "breed"),
        ("cat persona writer", "coordinator"),
    ]

    private static func identifyAgent(from systemPrompt: String) -> String {
        for (keyword, agent) in routingKeys {
            if systemPrompt.contains(keyword) {
                return agent
            }
        }
        return "unknown"
    }

    /// Export recordings as a fixture-ready dictionary.
    func exportRecordedResponses() -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        var dict: [String: String] = [:]
        for recording in recordings {
            dict[recording.agentKey] = recording.response
        }
        return dict
    }
}
