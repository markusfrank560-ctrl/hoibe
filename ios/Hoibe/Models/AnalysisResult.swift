import Foundation

/// Structured output from the first-sip detection pipeline.
struct AnalysisResult: Codable, Equatable, Sendable {
    let firstSipDetected: Bool
    let confidence: Double
    let reasonShort: String
    let faceVisible: Bool
    let drinkingObjectVisible: Bool
    let mouthContactLikely: Bool
    let beerLikely: String
    let beerFillLevel: BeerFillLevel
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
