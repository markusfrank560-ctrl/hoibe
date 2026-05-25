import Foundation
import Testing
@testable import PawProfiler

@Suite("ArchetypeResolver")
struct ArchetypeResolverTests {

    // MARK: - All 8 Archetypes

    @Test("The Chaotic Acrobat: E>0.7 + I>0.7 + N<0.3")
    func chaoticAcrobat() {
        let scores = FelineFiveScores(neuroticism: 0.1, extraversion: 0.9, dominance: 0.5, impulsiveness: 0.85, agreeableness: 0.5)
        #expect(ArchetypeResolver.resolve(scores) == "The Chaotic Acrobat")
    }

    @Test("The Midnight Gremlin: I>0.7 + E>0.7 (but N not <0.3)")
    func midnightGremlin() {
        let scores = FelineFiveScores(neuroticism: 0.5, extraversion: 0.8, dominance: 0.5, impulsiveness: 0.8, agreeableness: 0.5)
        #expect(ArchetypeResolver.resolve(scores) == "The Midnight Gremlin")
    }

    @Test("The Royal Aristocat: D>0.7 + I<0.3")
    func royalAristocat() {
        let scores = FelineFiveScores(neuroticism: 0.3, extraversion: 0.5, dominance: 0.8, impulsiveness: 0.2, agreeableness: 0.5)
        #expect(ArchetypeResolver.resolve(scores) == "The Royal Aristocat")
    }

    @Test("The Lone Strategist: D>0.7 + A<0.3")
    func loneStrategist() {
        let scores = FelineFiveScores(neuroticism: 0.3, extraversion: 0.5, dominance: 0.8, impulsiveness: 0.5, agreeableness: 0.2)
        #expect(ArchetypeResolver.resolve(scores) == "The Lone Strategist")
    }

    @Test("The Anxious Explorer: N>0.7 + E>0.7")
    func anxiousExplorer() {
        let scores = FelineFiveScores(neuroticism: 0.8, extraversion: 0.8, dominance: 0.5, impulsiveness: 0.5, agreeableness: 0.5)
        #expect(ArchetypeResolver.resolve(scores) == "The Anxious Explorer")
    }

    @Test("The Gentle Soul: A>0.7 + D<0.3")
    func gentleSoul() {
        let scores = FelineFiveScores(neuroticism: 0.3, extraversion: 0.5, dominance: 0.2, impulsiveness: 0.5, agreeableness: 0.8)
        #expect(ArchetypeResolver.resolve(scores) == "The Gentle Soul")
    }

    @Test("The Couch Philosopher: E<0.3 + I<0.3")
    func couchPhilosopher() {
        let scores = FelineFiveScores(neuroticism: 0.3, extraversion: 0.2, dominance: 0.5, impulsiveness: 0.2, agreeableness: 0.5)
        #expect(ArchetypeResolver.resolve(scores) == "The Couch Philosopher")
    }

    @Test("The Social Butterfly: A>0.7 + E>0.7")
    func socialButterfly() {
        let scores = FelineFiveScores(neuroticism: 0.3, extraversion: 0.8, dominance: 0.5, impulsiveness: 0.5, agreeableness: 0.8)
        #expect(ArchetypeResolver.resolve(scores) == "The Social Butterfly")
    }

    // MARK: - Fallback

    @Test("The Everyday Cat: mid-range scores (no archetype matches)")
    func everydayCat() {
        let scores = FelineFiveScores(neuroticism: 0.5, extraversion: 0.5, dominance: 0.5, impulsiveness: 0.5, agreeableness: 0.5)
        #expect(ArchetypeResolver.resolve(scores) == "The Everyday Cat")
    }

    // MARK: - Precedence

    @Test("Chaotic Acrobat beats Midnight Gremlin (more specific)")
    func chaoticAcrobatPrecedence() {
        // Scores that match both: E>0.7, I>0.7, N<0.3
        let scores = FelineFiveScores(neuroticism: 0.1, extraversion: 0.9, dominance: 0.5, impulsiveness: 0.9, agreeableness: 0.5)
        // Chaotic Acrobat (3 traits) should win over Midnight Gremlin (2 traits)
        #expect(ArchetypeResolver.resolve(scores) == "The Chaotic Acrobat")
    }

    @Test("Midnight Gremlin when N is not <0.3 (Chaotic Acrobat doesn't match)")
    func midnightGremlinNotChaotic() {
        // E>0.7, I>0.7, but N=0.4 (>0.3) so Chaotic Acrobat doesn't match
        let scores = FelineFiveScores(neuroticism: 0.4, extraversion: 0.8, dominance: 0.5, impulsiveness: 0.8, agreeableness: 0.5)
        #expect(ArchetypeResolver.resolve(scores) == "The Midnight Gremlin")
    }

    // MARK: - Boundary Values

    @Test("boundary: exactly 0.7 does NOT match >0.7")
    func boundaryExact() {
        let scores = FelineFiveScores(neuroticism: 0.3, extraversion: 0.7, dominance: 0.5, impulsiveness: 0.7, agreeableness: 0.5)
        // E=0.7, I=0.7 — both need >0.7, so Midnight Gremlin should NOT match
        #expect(ArchetypeResolver.resolve(scores) == "The Everyday Cat")
    }

    @Test("boundary: exactly 0.3 does NOT match <0.3")
    func boundaryExactLow() {
        let scores = FelineFiveScores(neuroticism: 0.5, extraversion: 0.2, dominance: 0.5, impulsiveness: 0.3, agreeableness: 0.5)
        // I=0.3 — needs <0.3 for Couch Philosopher
        #expect(ArchetypeResolver.resolve(scores) == "The Everyday Cat")
    }

    @Test("boundary: 0.71 and 0.29 match")
    func boundaryJustInside() {
        let scores = FelineFiveScores(neuroticism: 0.5, extraversion: 0.29, dominance: 0.5, impulsiveness: 0.29, agreeableness: 0.5)
        #expect(ArchetypeResolver.resolve(scores) == "The Couch Philosopher")
    }
}
