import Foundation

/// Manages model download, caching, and inference lifecycle.
public protocol ModelManaging: AnyObject, Sendable {
    var state: ModelDownloadState { get }
    var isReady: Bool { get }
    func tryLoadCached() async -> Bool
    func startDownload(allowCellular: Bool) async throws
    func pauseDownload()
    func deleteModel() throws
    func generate(messages: [ChatMessage], maxTokens: Int, temperature: Double) async throws -> String
}
