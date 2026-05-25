import Foundation
import VLMPipeline

/// Cat detection gate that determines if a cat is present in video frames.
/// Uses a single VLM call with multiple frames; applies majority-vote logic in code.
struct CatGate: CatGating {
    let modelManager: any ModelManaging
    let promptEngine: any AgentPromptBuilding

    func runGate(
        frames: [Data],
        config: PawProfilerConfig
    ) async throws -> CatGateResult {
        let messages = promptEngine.buildGateMessages(framesData: frames)
        let response = try await modelManager.generate(
            messages: messages,
            maxTokens: 1024,
            temperature: config.temperature
        )

        let gateResponse = try parseGateResponse(response)
        return applyMajorityVote(gateResponse, modelName: "qwen3-vl-4b")
    }

    // MARK: - Response Parsing

    private struct GateResponse: Codable {
        let frameAssessments: [FrameAssessment]

        enum CodingKeys: String, CodingKey {
            case frameAssessments = "frame_assessments"
        }
    }

    private struct FrameAssessment: Codable {
        let frameIndex: Int
        let catDetected: Bool
        let confidence: Double
        let speciesGuess: String?
        let multipleCats: Bool

        enum CodingKeys: String, CodingKey {
            case frameIndex = "frame_index"
            case catDetected = "cat_detected"
            case confidence
            case speciesGuess = "species_guess"
            case multipleCats = "multiple_cats"
        }
    }

    private func parseGateResponse(_ raw: String) throws -> GateResponse {
        // Strip markdown code fences if present
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw GateError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(GateResponse.self, from: data)
        } catch {
            throw GateError.parseFailed(error.localizedDescription)
        }
    }

    // MARK: - Majority Vote (code-based, not trusting VLM)

    private func applyMajorityVote(_ response: GateResponse, modelName: String) -> CatGateResult {
        let assessments = response.frameAssessments
        guard !assessments.isEmpty else {
            return CatGateResult(
                catDetected: false,
                status: .noCatDetected,
                confidence: 0.0,
                multipleCats: false,
                modelName: modelName
            )
        }

        let catCount = assessments.filter(\.catDetected).count
        let totalCount = assessments.count
        let catDetected = catCount * 2 >= totalCount  // ≥ majority (ceil)

        // Average confidence across all frames
        let avgConfidence = assessments.map(\.confidence).reduce(0, +) / Double(totalCount)

        // Multiple cats if any frame reports it
        let multipleCats = assessments.contains(where: \.multipleCats)

        // Species guess: use first non-nil guess from non-cat frames
        let speciesGuess = assessments.first(where: { !$0.catDetected && $0.speciesGuess != nil })?.speciesGuess

        let status: CatGateStatus
        if catDetected {
            status = .catDetected
        } else if speciesGuess != nil {
            status = .notACat
        } else {
            status = .noCatDetected
        }

        return CatGateResult(
            catDetected: catDetected,
            status: status,
            speciesGuess: speciesGuess,
            confidence: avgConfidence,
            multipleCats: multipleCats,
            modelName: modelName
        )
    }
}

enum GateError: Error, LocalizedError {
    case invalidResponse
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Gate received invalid response from VLM"
        case .parseFailed(let detail): return "Gate JSON parse failed: \(detail)"
        }
    }
}
