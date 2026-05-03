import CoreImage
import Foundation
import MLXLMCommon
import MLXVLM

/// Manages VLM model download, caching, and inference using MLX Swift.
final class ModelManager: ModelManaging, @unchecked Sendable {

    private let modelId = "lmstudio-community/Qwen3-VL-4B-Instruct-MLX-4bit"
    private var container: ModelContainer?
    private let lock = NSLock()

    @Published private(set) var state: ModelDownloadState = .notDownloaded

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// Progress callback set by the caller before starting download.
    var onProgress: (@Sendable (Double) -> Void)?

    /// Try to load model from local cache (no download). Returns true if cached and ready.
    /// Try to load model from local cache (no download). Returns true if cached and ready.
    func tryLoadCached() async -> Bool {
        // Quick filesystem check: if huggingface dir doesn't exist, model isn't cached
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelDir = documents.appendingPathComponent("huggingface/models/\(modelId)")
        guard FileManager.default.fileExists(atPath: modelDir.path) else {
            print("[ModelManager] No cache at \(modelDir.path)")
            return false
        }
        do {
            print("[ModelManager] Cache dir found, loading model…")
            let container = try await loadModelContainer(id: modelId) { _ in }
            lock.lock()
            self.container = container
            lock.unlock()
            state = .ready
            print("[ModelManager] Model loaded from cache ✓")
            return true
        } catch {
            print("[ModelManager] tryLoadCached failed: \(error)")
            return false
        }
    }

    func startDownload(allowCellular: Bool) async throws {
        state = .downloading(progress: 0)

        let onProgress = self.onProgress
        let container = try await loadModelContainer(id: modelId) { progress in
            let frac = progress.fractionCompleted
            onProgress?(frac)
        }

        lock.lock()
        self.container = container
        lock.unlock()

        state = .ready
    }

    func pauseDownload() {
        // Hub API doesn't expose pause; no-op for now
    }

    func deleteModel() throws {
        lock.lock()
        container = nil
        lock.unlock()
        state = .notDownloaded
        // Hub caches in ~/Library/Caches/huggingface; clearing requires file ops
    }

    func generate(messages: [ChatMessage], maxTokens: Int, temperature: Double) async throws -> String {
        guard let container else {
            throw ModelManagerError.modelNotReady
        }

        let chatMessages: [Chat.Message] = messages.map { msg in
            let role: Chat.Message.Role = switch msg.role {
            case .system: .system
            case .user: .user
            case .assistant: .assistant
            }
            let images: [UserInput.Image] = msg.images.compactMap { data in
                guard let ciImage = CIImage(data: data) else { return nil }
                return .ciImage(ciImage)
            }
            return Chat.Message(role: role, content: msg.text, images: images)
        }

        let params = GenerateParameters(maxTokens: maxTokens, temperature: Float(temperature))
        let session = ChatSession(container, generateParameters: params)

        // Build the user message (last in array) for respond()
        guard let userMsg = chatMessages.last, userMsg.role == .user else {
            throw ModelManagerError.invalidMessages
        }

        // Set system instruction from messages
        let systemText = messages.first { $0.role == .system }?.text

        let freshSession = ChatSession(
            container,
            instructions: systemText,
            generateParameters: params
        )

        return try await freshSession.respond(to: userMsg.content, images: userMsg.images, videos: [])
    }
}

enum ModelManagerError: LocalizedError {
    case modelNotReady
    case invalidMessages

    var errorDescription: String? {
        switch self {
        case .modelNotReady: "Model not downloaded or loaded"
        case .invalidMessages: "Messages must end with a user message"
        }
    }
}
