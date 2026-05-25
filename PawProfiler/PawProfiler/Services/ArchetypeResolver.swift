import Foundation

/// Deterministic archetype lookup from Feline Five scores.
/// Uses most-specific-match-wins precedence (highest trait-condition count).
/// Ties broken by table order.
struct ArchetypeResolver {

    struct Archetype {
        let label: String
        let conditions: [(KeyPath<FelineFiveScores, Double>, (Double) -> Bool)]

        var specificity: Int { conditions.count }

        func matches(_ scores: FelineFiveScores) -> Bool {
            conditions.allSatisfy { keyPath, predicate in
                predicate(scores[keyPath: keyPath])
            }
        }
    }

    /// Archetype table ordered by specificity (most specific first), then by table order.
    static let archetypes: [Archetype] = [
        // 3-trait archetypes
        Archetype(
            label: "The Chaotic Acrobat",
            conditions: [
                (\.extraversion, { $0 > 0.7 }),
                (\.impulsiveness, { $0 > 0.7 }),
                (\.neuroticism, { $0 < 0.3 })
            ]
        ),
        // 2-trait archetypes (table order)
        Archetype(
            label: "The Midnight Gremlin",
            conditions: [
                (\.impulsiveness, { $0 > 0.7 }),
                (\.extraversion, { $0 > 0.7 })
            ]
        ),
        Archetype(
            label: "The Royal Aristocat",
            conditions: [
                (\.dominance, { $0 > 0.7 }),
                (\.impulsiveness, { $0 < 0.3 })
            ]
        ),
        Archetype(
            label: "The Lone Strategist",
            conditions: [
                (\.dominance, { $0 > 0.7 }),
                (\.agreeableness, { $0 < 0.3 })
            ]
        ),
        Archetype(
            label: "The Anxious Explorer",
            conditions: [
                (\.neuroticism, { $0 > 0.7 }),
                (\.extraversion, { $0 > 0.7 })
            ]
        ),
        Archetype(
            label: "The Gentle Soul",
            conditions: [
                (\.agreeableness, { $0 > 0.7 }),
                (\.dominance, { $0 < 0.3 })
            ]
        ),
        Archetype(
            label: "The Couch Philosopher",
            conditions: [
                (\.extraversion, { $0 < 0.3 }),
                (\.impulsiveness, { $0 < 0.3 })
            ]
        ),
        Archetype(
            label: "The Social Butterfly",
            conditions: [
                (\.agreeableness, { $0 > 0.7 }),
                (\.extraversion, { $0 > 0.7 })
            ]
        ),
    ]

    static let fallback = "The Everyday Cat"

    /// Resolve the archetype for given Feline Five scores.
    /// Most-specific match wins; ties broken by table order.
    static func resolve(_ scores: FelineFiveScores) -> String {
        // Archetypes are pre-sorted by specificity (descending) then table order
        for archetype in archetypes {
            if archetype.matches(scores) {
                return archetype.label
            }
        }
        return fallback
    }
}
