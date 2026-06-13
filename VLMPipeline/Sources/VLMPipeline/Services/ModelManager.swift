import CoreImage
import Foundation
import MLX
import MLXLMCommon
import MLXVLM

/// Manages VLM model download, caching, and inference using MLX Swift.
public final class ModelManager: ModelManaging, @unchecked Sendable {

    private let modelId: String
    private var container: ModelContainer?
    private let lock = NSLock()

    @Published public private(set) var state: ModelDownloadState = .notDownloaded

    public var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// Progress callback set by the caller before starting download.
    public var onProgress: (@Sendable (Double) -> Void)?

    public init(modelId: String = "lmstudio-community/Qwen3-VL-4B-Instruct-MLX-4bit") {
        self.modelId = modelId
    }

    /// Try to load model from local cache (no download). Returns true if cached and ready.
    public func tryLoadCached() async -> Bool {
        do {
            let container = try await loadModelContainer(id: modelId) { _ in }
            lock.lock()
            self.container = container
            lock.unlock()
            state = .ready
            return true
        } catch {
            return false
        }
    }

    public func startDownload(allowCellular: Bool) async throws {
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

    public func pauseDownload() {
        // Hub API doesn't expose pause; no-op for now
    }

    public func deleteModel() throws {
        lock.lock()
        container = nil
        lock.unlock()
        state = .notDownloaded
        // Hub caches in ~/Library/Caches/huggingface; clearing requires file ops
    }

    public func generate(messages: [ChatMessage], maxTokens: Int, temperature: Double, imageResizeSize: Int?) async throws -> String {
        guard let container else {
            throw ModelManagerError.modelNotReady
        }

        let imageCount = messages.reduce(0) { $0 + $1.images.count }
        let resizeStr = imageResizeSize.map(String.init) ?? "nil"
        print("[ModelManager] generate() start — \(messages.count) msgs, \(imageCount) images, maxTokens=\(maxTokens), temp=\(temperature), imageResize=\(resizeStr)")
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("[ModelManager] generate() done — \(String(format: "%.1f", elapsed))s")
        }

        // Build Chat.Message array preserving system + user roles
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

        let processing: UserInput.Processing
        if let size = imageResizeSize {
            processing = .init(resize: CGSize(width: size, height: size))
        } else {
            processing = .init()
        }

        // Build UserInput directly — bypasses ChatSession which drops system messages
        let userInput = UserInput(
            chat: chatMessages,
            processing: processing
        )

        let params = GenerateParameters(maxTokens: maxTokens, temperature: Float(temperature))

        let raw: String = try await container.perform { context in
            let input = try await context.processor.prepare(input: userInput)
            let result: GenerateResult = try MLXLMCommon.generate(
                input: input,
                parameters: params,
                context: context
            ) { (_: [Int]) in .more }
            return result.output
        }

        print("[ModelManager] generate returned \(raw.count) chars:\n\(raw)")
        // Defensive: strip any <think> blocks if model unexpectedly emits them
        return Self.stripThinkBlocks(raw)
    }

    /// Remove <think>...</think> reasoning blocks from model output.
    private static func stripThinkBlocks(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"<think>[\s\S]*?</think>"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum ModelManagerError: LocalizedError {
    case modelNotReady
    case invalidMessages

    public var errorDescription: String? {
        switch self {
        case .modelNotReady: "Model not downloaded or loaded"
        case .invalidMessages: "Messages must end with a user message"
        }
    }
}
