// SPDX-License-Identifier: MIT
// Contract: CatGating protocol — Cat detection gate for PawProfiler

import Foundation

/// Result status of the cat detection gate.
enum CatGateStatus: String, Codable, Sendable {
    case catDetected = "cat_detected"
    case noCatDetected = "no_cat_detected"
    case notACat = "not_a_cat"
}

/// Result of the cat detection gate (majority vote over N frames).
struct CatGateResult: Codable, Equatable, Sendable {
    let catDetected: Bool
    let status: CatGateStatus
    let speciesGuess: String?
    let confidence: Double
    let multipleCats: Bool
    let modelName: String

    enum CodingKeys: String, CodingKey {
        case catDetected = "cat_detected"
        case status
        case speciesGuess = "species_guess"
        case confidence
        case multipleCats = "multiple_cats"
        case modelName = "model_name"
    }
}

/// Runs a cat detection gate before dispatching specialist agents.
protocol CatGating: Sendable {

    /// Run the cat detection gate on extracted frames.
    /// Uses majority-vote over `gateVotes` frames (default 3).
    /// - Parameters:
    ///   - frames: JPEG-encoded frames to evaluate.
    ///   - config: Pipeline configuration with gate parameters.
    /// - Returns: CatGateResult with detection status.
    func runGate(
        frames: [Data],
        config: PawProfilerConfig
    ) async throws -> CatGateResult
}
