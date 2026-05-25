import Foundation

/// Breed estimate with confidence from the Breed & Archetype Agent.
public struct BreedEstimate: Codable, Equatable, Sendable {
    public let breed: String
    public let confidence: Double
    public let traits: [String]

    public init(breed: String, confidence: Double, traits: [String] = []) {
        self.breed = breed
        self.confidence = confidence
        self.traits = traits
    }
}
