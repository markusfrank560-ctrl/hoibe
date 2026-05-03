import Foundation

/// Manages model download, caching, and inference lifecycle.
protocol ModelManaging: AnyObject, Sendable {
    var state: ModelDownloadState { get }
    var isReady: Bool { get }
    func tryLoadCached() async -> Bool
    func startDownload(allowCellular: Bool) async throws
    func pauseDownload()
    func deleteModel() throws
    func generate(messages: [ChatMessage], maxTokens: Int, temperature: Double) async throws -> String
}

/// Extracts and ranks video frames for analysis.
protocol FrameExtracting: Sendable {
    func extractFrames(
        from url: URL,
        count: Int,
        window: (start: Double, end: Double),
        maxWidth: Int,
        jpegQuality: Double
    ) async throws -> FrameData

    func extractSharpestFrames(
        from url: URL,
        topN: Int,
        candidateCount: Int,
        window: (start: Double, end: Double),
        maxWidth: Int,
        jpegQuality: Double
    ) async throws -> FrameData
}

/// Builds chat messages from prompt templates for VLM inference.
protocol PromptBuilding: Sendable {
    func buildFillLevelMessages(imageData: Data, think: Bool) -> [ChatMessage]
    func buildSipDetectionMessages(framesData: [Data], timestamps: [String], think: Bool) -> [ChatMessage]
}

/// Orchestrates the full detection pipeline.
protocol SipDetecting: AnyObject {
    var analysisState: AnalysisState { get }
    func analyze(videoURL: URL) async throws -> AnalysisResult
    func cancel()
}
