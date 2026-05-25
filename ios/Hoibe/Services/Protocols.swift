import Foundation
import VLMPipeline

/// Builds chat messages from prompt templates for Hoibe sip detection.
protocol SipPromptBuilding: Sendable {
    func buildFillLevelMessages(imageData: Data, think: Bool) -> [ChatMessage]
    func buildSipDetectionMessages(framesData: [Data], timestamps: [String], think: Bool) -> [ChatMessage]
}

/// Orchestrates the full detection pipeline.
protocol SipDetecting: AnyObject {
    var analysisState: AnalysisState { get }
    func analyze(videoURL: URL) async throws -> AnalysisResult
    func cancel()
}
