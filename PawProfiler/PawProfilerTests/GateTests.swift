import Foundation
import Testing
@testable import PawProfiler
import VLMPipeline

@Suite("CatGate")
struct GateTests {
    let promptEngine = AgentPromptEngine()

    private func makeMock(gateResponse: String) -> MockModelManager {
        let mock = MockModelManager()
        mock.setResponse(forAgent: "gate", response: gateResponse)
        return mock
    }

    // MARK: - Cat Detected

    @Test("cat detected with 3/3 positive frames")
    func catDetectedUnanimous() async throws {
        let response = """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":true,"confidence":0.95,"species_guess":null,"multiple_cats":false},
            {"frame_index":1,"cat_detected":true,"confidence":0.90,"species_guess":null,"multiple_cats":false},
            {"frame_index":2,"cat_detected":true,"confidence":0.92,"species_guess":null,"multiple_cats":false}
        ]}
        """
        let mock = makeMock(gateResponse: response)
        let gate = CatGate(modelManager: mock, promptEngine: promptEngine)
        let config = PawProfilerConfig()
        let frames = (0..<3).map { _ in Data([0xFF, 0xD8]) }

        let result = try await gate.runGate(frames: frames, config: config)

        #expect(result.catDetected == true)
        #expect(result.status == .catDetected)
        #expect(result.confidence > 0.9)
        #expect(result.multipleCats == false)
    }

    @Test("cat detected with 2/3 majority vote")
    func catDetectedMajority() async throws {
        let response = """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":true,"confidence":0.9,"species_guess":null,"multiple_cats":false},
            {"frame_index":1,"cat_detected":false,"confidence":0.6,"species_guess":null,"multiple_cats":false},
            {"frame_index":2,"cat_detected":true,"confidence":0.85,"species_guess":null,"multiple_cats":false}
        ]}
        """
        let mock = makeMock(gateResponse: response)
        let gate = CatGate(modelManager: mock, promptEngine: promptEngine)

        let result = try await gate.runGate(frames: [Data(), Data(), Data()], config: PawProfilerConfig())

        #expect(result.catDetected == true)
        #expect(result.status == .catDetected)
    }

    // MARK: - No Cat

    @Test("no cat detected with 0/3 frames")
    func noCatDetected() async throws {
        let response = """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":false,"confidence":0.95,"species_guess":null,"multiple_cats":false},
            {"frame_index":1,"cat_detected":false,"confidence":0.92,"species_guess":null,"multiple_cats":false},
            {"frame_index":2,"cat_detected":false,"confidence":0.93,"species_guess":null,"multiple_cats":false}
        ]}
        """
        let mock = makeMock(gateResponse: response)
        let gate = CatGate(modelManager: mock, promptEngine: promptEngine)

        let result = try await gate.runGate(frames: [Data(), Data(), Data()], config: PawProfilerConfig())

        #expect(result.catDetected == false)
        #expect(result.status == .noCatDetected)
        #expect(result.speciesGuess == nil)
    }

    // MARK: - Not A Cat

    @Test("not-a-cat with species guess")
    func notACatWithSpecies() async throws {
        let response = """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":false,"confidence":0.9,"species_guess":"dog","multiple_cats":false},
            {"frame_index":1,"cat_detected":false,"confidence":0.88,"species_guess":"dog","multiple_cats":false},
            {"frame_index":2,"cat_detected":false,"confidence":0.91,"species_guess":"dog","multiple_cats":false}
        ]}
        """
        let mock = makeMock(gateResponse: response)
        let gate = CatGate(modelManager: mock, promptEngine: promptEngine)

        let result = try await gate.runGate(frames: [Data(), Data(), Data()], config: PawProfilerConfig())

        #expect(result.catDetected == false)
        #expect(result.status == .notACat)
        #expect(result.speciesGuess == "dog")
    }

    // MARK: - Multiple Cats

    @Test("multiple cats detected")
    func multipleCats() async throws {
        let response = """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":true,"confidence":0.93,"species_guess":null,"multiple_cats":true},
            {"frame_index":1,"cat_detected":true,"confidence":0.9,"species_guess":null,"multiple_cats":true},
            {"frame_index":2,"cat_detected":true,"confidence":0.91,"species_guess":null,"multiple_cats":false}
        ]}
        """
        let mock = makeMock(gateResponse: response)
        let gate = CatGate(modelManager: mock, promptEngine: promptEngine)

        let result = try await gate.runGate(frames: [Data(), Data(), Data()], config: PawProfilerConfig())

        #expect(result.catDetected == true)
        #expect(result.multipleCats == true)
    }

    // MARK: - Edge Cases

    @Test("majority vote threshold: 1/3 = no cat")
    func majorityVoteThreshold() async throws {
        let response = """
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":true,"confidence":0.9,"species_guess":null,"multiple_cats":false},
            {"frame_index":1,"cat_detected":false,"confidence":0.8,"species_guess":null,"multiple_cats":false},
            {"frame_index":2,"cat_detected":false,"confidence":0.85,"species_guess":null,"multiple_cats":false}
        ]}
        """
        let mock = makeMock(gateResponse: response)
        let gate = CatGate(modelManager: mock, promptEngine: promptEngine)

        let result = try await gate.runGate(frames: [Data(), Data(), Data()], config: PawProfilerConfig())

        #expect(result.catDetected == false)
    }

    @Test("response wrapped in markdown code fence")
    func markdownCodeFence() async throws {
        let response = """
        ```json
        {"frame_assessments":[
            {"frame_index":0,"cat_detected":true,"confidence":0.9,"species_guess":null,"multiple_cats":false},
            {"frame_index":1,"cat_detected":true,"confidence":0.9,"species_guess":null,"multiple_cats":false},
            {"frame_index":2,"cat_detected":true,"confidence":0.9,"species_guess":null,"multiple_cats":false}
        ]}
        ```
        """
        let mock = makeMock(gateResponse: response)
        let gate = CatGate(modelManager: mock, promptEngine: promptEngine)

        let result = try await gate.runGate(frames: [Data(), Data(), Data()], config: PawProfilerConfig())

        #expect(result.catDetected == true)
    }
}
