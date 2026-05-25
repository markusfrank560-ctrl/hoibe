// SPDX-License-Identifier: MIT
// Contract: CatProfiling protocol — Pipeline orchestrator

import Foundation

/// Pipeline analysis state for UI observation.
enum CatAnalysisState: Equatable {
    case idle
    case extractingFrames
    case runningGate
    case gateRejected(CatGateResult)
    case runningAgent(agent: Int, of: Int, name: String)
    case runningCoordinator
    case complete(CompositeProfile)
    case error(String)
}

/// Profile analysis mode.
enum ProfileMode: String, Codable, Sendable {
    case quick  // windowsPerAgent = 1
    case deep   // windowsPerAgent = 3
}

/// Orchestrates the full cat profiling pipeline.
protocol CatProfiling: AnyObject {

    /// Current analysis state. Observable for UI binding.
    var analysisState: CatAnalysisState { get }

    /// Run the full profiling pipeline on a video clip.
    /// Pipeline: extract frames → cat gate → 6 agents → coordinator → profile.
    /// - Parameters:
    ///   - videoURL: Local URL to a 15–90s video clip.
    ///   - mode: Quick (1 window/agent) or Deep (3 windows/agent).
    /// - Returns: The composite profile.
    /// - Throws: On timeout, invalid video, gate rejection, or model not ready.
    func analyze(
        videoURL: URL,
        mode: ProfileMode
    ) async throws -> CompositeProfile

    /// Cancel a running analysis.
    func cancel()
}
