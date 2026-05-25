import Foundation
import Testing
@testable import PawProfiler
import VLMPipeline

@Suite("AgentPromptEngine")
struct AgentPromptEngineTests {

    let engine = AgentPromptEngine()

    // MARK: - Gate Messages

    @Test("buildGateMessages single image returns system + user")
    func gateMessagesSingle() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF]) // minimal JPEG header
        let messages = engine.buildGateMessages(imageData: imageData)

        #expect(messages.count == 2)
        #expect(messages[0].role == .system)
        #expect(messages[1].role == .user)
        #expect(messages[0].text.contains("cat detection specialist"))
        #expect(messages[1].images.count == 1)
        #expect(messages[1].text.contains("/no_think"))
    }

    @Test("buildGateMessages multi-frame returns all frames in images array")
    func gateMessagesMultiFrame() throws {
        let frames = (0..<3).map { _ in Data([0xFF, 0xD8, 0xFF]) }
        let messages = engine.buildGateMessages(framesData: frames)

        #expect(messages.count == 2)
        #expect(messages[1].images.count == 3)
        #expect(messages[0].text.contains("cat detection specialist"))
    }

    // MARK: - Agent Messages

    @Test("buildAgentMessages includes agent-specific prompt", arguments: AgentPromptEngine.agentIds)
    func agentMessages(agentId: String) throws {
        let frames = [Data([0xFF, 0xD8, 0xFF])]
        let timestamps = ["00:05.0"]
        let messages = engine.buildAgentMessages(
            agentId: agentId,
            framesData: frames,
            timestamps: timestamps
        )

        #expect(messages.count == 2)
        #expect(messages[0].role == .system)
        #expect(messages[1].role == .user)
        #expect(messages[1].images.count == 1)
        #expect(messages[1].text.contains("00:05.0"))
        #expect(messages[1].text.contains("/no_think"))
        // System prompt should not be empty
        #expect(!messages[0].text.isEmpty)
    }

    @Test("buildAgentMessages includes all timestamps")
    func agentMessagesTimestamps() throws {
        let frames = (0..<3).map { _ in Data([0xFF, 0xD8, 0xFF]) }
        let timestamps = ["00:02.0", "00:15.5", "00:28.3"]
        let messages = engine.buildAgentMessages(
            agentId: "personality",
            framesData: frames,
            timestamps: timestamps
        )

        #expect(messages[1].text.contains("00:02.0"))
        #expect(messages[1].text.contains("00:15.5"))
        #expect(messages[1].text.contains("00:28.3"))
    }

    // MARK: - Coordinator Messages

    @Test("buildCoordinatorMessages includes aggregated data")
    func coordinatorMessages() throws {
        let data = try JSONSerialization.data(
            withJSONObject: ["feline_five_scores": ["neuroticism": 0.3]]
        )
        let messages = engine.buildCoordinatorMessages(aggregatedData: data)

        #expect(messages.count == 2)
        #expect(messages[0].role == .system)
        #expect(messages[0].text.contains("cat persona writer"))
        #expect(messages[1].text.contains("feline_five_scores"))
        #expect(messages[1].text.contains("/no_think"))
        #expect(messages[1].images.isEmpty)
    }

    // MARK: - Agent IDs

    @Test("agentIds contains all 6 specialist agents")
    func agentIdsComplete() {
        let ids = AgentPromptEngine.agentIds
        #expect(ids.count == 6)
        #expect(ids.contains("personality"))
        #expect(ids.contains("social"))
        #expect(ids.contains("play"))
        #expect(ids.contains("stress"))
        #expect(ids.contains("health"))
        #expect(ids.contains("breed"))
    }

    // MARK: - Prompt Content

    @Test("each agent prompt contains domain-specific keywords", arguments: [
        ("personality", "Feline Five"),
        ("social", "attachment"),
        ("play", "predatory"),
        ("stress", "Cat-Stress-Score"),
        ("health", "pain"),
        ("breed", "breed")
    ])
    func promptContent(agentId: String, expectedKeyword: String) throws {
        let frames = [Data([0xFF, 0xD8, 0xFF])]
        let messages = engine.buildAgentMessages(
            agentId: agentId,
            framesData: frames,
            timestamps: ["00:00.0"]
        )

        #expect(messages[0].text.contains(expectedKeyword))
    }
}
