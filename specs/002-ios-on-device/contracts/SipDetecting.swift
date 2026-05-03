// SPDX-License-Identifier: MIT
// Contract: SipDetecting protocol

import Foundation

/// Pipeline analysis state for UI observation.
enum AnalysisState: Equatable {
    case idle
    case validating
    case extractingFrames
    case runningGate(vote: Int, of: Int)
    case runningWindows(window: Int, of: Int)
    case complete(AnalysisResult)
    case error(String)
}

/// The analysis result — mirrors Python AnalysisResult schema.
struct AnalysisResult: Codable, Equatable, Sendable {
    let firstSipDetected: Bool
    let confidence: Double
    let reasonShort: String
    let faceVisible: Bool
    let drinkingObjectVisible: Bool
    let mouthContactLikely: Bool
    let beerLikely: String        // "true" | "false" | "unknown"
    let beerFillLevel: String     // BeerFillLevel raw value
    let modelName: String
    let analysisVersion: String
    let analyzedAt: String?
    let sourceVideo: String?

    enum CodingKeys: String, CodingKey {
        case firstSipDetected = "first_sip_detected"
        case confidence
        case reasonShort = "reason_short"
        case faceVisible = "face_visible"
        case drinkingObjectVisible = "drinking_object_visible"
        case mouthContactLikely = "mouth_contact_likely"
        case beerLikely = "beer_likely"
        case beerFillLevel = "beer_fill_level"
        case modelName = "model_name"
        case analysisVersion = "analysis_version"
        case analyzedAt = "analyzed_at"
        case sourceVideo = "source_video"
    }
}

/// Orchestrates the full detection pipeline.
protocol SipDetecting: AnyObject {

    /// Current analysis state. Observable for UI binding.
    var analysisState: AnalysisState { get }

    /// Run the full detection pipeline on a video clip.
    /// - Parameter videoURL: Local URL to a 5–15s video clip.
    /// - Returns: The analysis result.
    /// - Throws: On timeout, invalid video, or model not ready.
    func analyze(videoURL: URL) async throws -> AnalysisResult

    /// Cancel a running analysis.
    func cancel()
}
