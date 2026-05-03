// SPDX-License-Identifier: MIT
// Contract: ModelManaging protocol

import Foundation

/// State of the on-device ML model.
enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case paused(bytesDownloaded: Int64)
    case ready
    case error(message: String)
}

/// Manages model download, caching, and lifecycle.
protocol ModelManaging: AnyObject, Sendable {

    /// Current download/readiness state. Observable for UI binding.
    var state: ModelDownloadState { get }

    /// Whether the model is loaded and ready for inference.
    var isReady: Bool { get }

    /// Start or resume model download from HuggingFace.
    /// - Parameter allowCellular: If true, allows download over cellular.
    func startDownload(allowCellular: Bool) async throws

    /// Pause an active download.
    func pauseDownload()

    /// Delete cached model to free storage.
    func deleteModel() throws

    /// Generate text from a chat message array with images.
    /// - Parameters:
    ///   - messages: Chat messages (system + user with images).
    ///   - maxTokens: Maximum tokens to generate.
    ///   - temperature: Sampling temperature.
    /// - Returns: Generated text response.
    func generate(
        messages: [ChatMessage],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String
}

/// A single chat message for the VLM.
struct ChatMessage: Sendable {
    enum Role: String, Sendable {
        case system
        case user
        case assistant
    }

    let role: Role
    let text: String
    let images: [Data]  // JPEG-encoded image data
}
