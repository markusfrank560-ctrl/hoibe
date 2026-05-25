import Foundation

/// Aggregated Feline Five personality scores (Litchfield et al. 2017).
/// All scores normalized to 0.0–1.0: 0.0 = not observed/minimal, 0.5 = average, 1.0 = strongly expressed.
public struct FelineFiveScores: Codable, Equatable, Sendable {
    public let neuroticism: Double
    public let extraversion: Double
    public let dominance: Double
    public let impulsiveness: Double
    public let agreeableness: Double

    public init(
        neuroticism: Double,
        extraversion: Double,
        dominance: Double,
        impulsiveness: Double,
        agreeableness: Double
    ) {
        self.neuroticism = neuroticism
        self.extraversion = extraversion
        self.dominance = dominance
        self.impulsiveness = impulsiveness
        self.agreeableness = agreeableness
    }

    /// All five scores as an ordered array: [N, E, D, I, A].
    public var allScores: [Double] {
        [neuroticism, extraversion, dominance, impulsiveness, agreeableness]
    }

    /// Trait labels matching `allScores` order.
    public static let traitLabels = ["Neuroticism", "Extraversion", "Dominance", "Impulsiveness", "Agreeableness"]
}
