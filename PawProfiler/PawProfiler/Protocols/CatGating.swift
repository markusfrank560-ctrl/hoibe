import Foundation
import VLMPipeline

/// Runs a cat detection gate before dispatching specialist agents.
/// Matches the contract at specs/003-paw-profiler/contracts/CatGating.swift.
protocol CatGating: Sendable {
    func runGate(
        frames: [Data],
        config: PawProfilerConfig
    ) async throws -> CatGateResult
}
