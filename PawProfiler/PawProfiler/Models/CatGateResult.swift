import Foundation

/// Result status of the cat detection gate.
public enum CatGateStatus: String, Codable, Sendable {
    case catDetected = "cat_detected"
    case noCatDetected = "no_cat_detected"
    case notACat = "not_a_cat"
}

/// Result of the cat detection gate (1 VLM call with 3 frames, majority vote in JSON output).
public struct CatGateResult: Codable, Equatable, Sendable {
    public let catDetected: Bool
    public let status: CatGateStatus
    public let speciesGuess: String?
    public let confidence: Double
    public let multipleCats: Bool
    public let modelName: String

    enum CodingKeys: String, CodingKey {
        case catDetected = "cat_detected"
        case status
        case speciesGuess = "species_guess"
        case confidence
        case multipleCats = "multiple_cats"
        case modelName = "model_name"
    }

    public init(
        catDetected: Bool,
        status: CatGateStatus,
        speciesGuess: String? = nil,
        confidence: Double,
        multipleCats: Bool,
        modelName: String
    ) {
        self.catDetected = catDetected
        self.status = status
        self.speciesGuess = speciesGuess
        self.confidence = confidence
        self.multipleCats = multipleCats
        self.modelName = modelName
    }
}
