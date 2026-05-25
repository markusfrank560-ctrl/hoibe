import Foundation
import VLMPipeline

/// Orchestrates the full cat profiling pipeline.
/// Matches the contract at specs/003-paw-profiler/contracts/CatProfiling.swift.
protocol CatProfiling: AnyObject {
    var analysisState: CatAnalysisState { get }

    func analyze(
        videoURL: URL,
        mode: ProfileMode
    ) async throws -> CompositeProfile

    func cancel()
}
