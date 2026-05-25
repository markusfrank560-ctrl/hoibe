import Foundation
import Testing
@testable import PawProfiler

@Suite("AgentResult Parsing")
struct AgentResultParsingTests {

    // MARK: - Valid Parsing

    @Test("parse completed personality agent result")
    func parseCompletedPersonality() throws {
        let json = """
        {
            "agent_id": "personality",
            "domain": "Personality & Traits",
            "status": "completed",
            "trait_scores": {"neuroticism": 0.3, "extraversion": 0.8, "dominance": 0.5, "impulsiveness": 0.6, "agreeableness": 0.7},
            "observations": ["Relaxed ear position", "Active exploration"],
            "flags": [],
            "confidence": 0.75,
            "reasoning": "Clear body posture visible",
            "prompt_version": "v1"
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(AgentResult.self, from: data)

        #expect(result.agentId == "personality")
        #expect(result.status == .completed)
        #expect(result.traitScores?["neuroticism"] == 0.3)
        #expect(result.traitScores?["extraversion"] == 0.8)
        #expect(result.observations.count == 2)
        #expect(result.confidence == 0.75)
        #expect(result.promptVersion == "v1")
    }

    @Test("parse not_observable status")
    func parseNotObservable() throws {
        let json = """
        {
            "agent_id": "play",
            "domain": "Play, Activity & Predatory Behavior",
            "status": "not_observable",
            "trait_scores": null,
            "observations": [],
            "flags": [],
            "confidence": 0.0,
            "reasoning": "Cat is sleeping",
            "prompt_version": "v1"
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(AgentResult.self, from: data)

        #expect(result.status == .notObservable)
        #expect(result.traitScores == nil)
        #expect(result.confidence == 0.0)
    }

    @Test("parse timed_out status")
    func parseTimedOut() throws {
        let json = """
        {
            "agent_id": "social",
            "domain": "Social Behavior",
            "status": "timed_out",
            "trait_scores": null,
            "observations": [],
            "flags": [],
            "confidence": 0.0,
            "reasoning": "Agent exceeded timeout",
            "prompt_version": "v1"
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(AgentResult.self, from: data)

        #expect(result.status == .timedOut)
    }

    @Test("parse failed status")
    func parseFailed() throws {
        let json = """
        {
            "agent_id": "health",
            "domain": "Health-Behavior Correlation",
            "status": "failed",
            "trait_scores": null,
            "observations": [],
            "flags": [],
            "confidence": 0.0,
            "reasoning": null,
            "prompt_version": "v1"
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(AgentResult.self, from: data)

        #expect(result.status == .failed)
        #expect(result.reasoning == nil)
    }

    // MARK: - Stress Flags

    @Test("parse stress agent with flags")
    func parseStressFlags() throws {
        let json = """
        {
            "agent_id": "stress",
            "domain": "Stress, Anxiety & Welfare",
            "status": "completed",
            "trait_scores": {"neuroticism": 0.85},
            "observations": ["Flattened ears", "Crouched posture"],
            "flags": ["stress_detected"],
            "confidence": 0.8,
            "reasoning": "Multiple stress indicators visible",
            "prompt_version": "v1"
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(AgentResult.self, from: data)

        #expect(result.flags.contains("stress_detected"))
        #expect(result.traitScores?["neuroticism"] == 0.85)
    }

    // MARK: - Confidence Ranges

    @Test("confidence values are within 0.0–1.0", arguments: [0.0, 0.25, 0.5, 0.75, 1.0])
    func confidenceRange(value: Double) throws {
        let json = """
        {
            "agent_id": "test",
            "domain": "Test",
            "status": "completed",
            "trait_scores": {},
            "observations": [],
            "flags": [],
            "confidence": \(value),
            "prompt_version": "v1"
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(AgentResult.self, from: data)

        #expect(result.confidence >= 0.0)
        #expect(result.confidence <= 1.0)
    }

    // MARK: - All Agent Types

    @Test("schema validation per agent type", arguments: [
        ("personality", "Personality & Traits"),
        ("social", "Social Behavior & Human Bonding"),
        ("play", "Play, Activity & Predatory Behavior"),
        ("stress", "Stress, Anxiety & Welfare"),
        ("health", "Health-Behavior Correlation"),
        ("breed", "Breed & Archetype")
    ])
    func schemaPerAgent(agentId: String, domain: String) throws {
        let json = """
        {
            "agent_id": "\(agentId)",
            "domain": "\(domain)",
            "status": "completed",
            "trait_scores": {"extraversion": 0.5},
            "observations": ["Test observation"],
            "flags": [],
            "confidence": 0.6,
            "prompt_version": "v1"
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(AgentResult.self, from: data)

        #expect(result.agentId == agentId)
        #expect(result.domain == domain)
    }
}
