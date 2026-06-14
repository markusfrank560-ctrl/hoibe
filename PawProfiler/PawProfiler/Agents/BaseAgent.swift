import Foundation
import VLMPipeline

/// Shared agent logic: timeout handling, JSON response parsing,
/// not_observable fallback, and error mapping.
struct BaseAgent: BehaviorAnalyzing, @unchecked Sendable {
    let agentId: String
    let domain: String
    let modelManager: any ModelManaging
    let promptEngine: any AgentPromptBuilding

    func analyze(
        frames: [Data],
        timestamps: [Double],
        config: PawProfilerConfig
    ) async throws -> AgentResult {
        let timestampStrings = timestamps.map { Self.formatTimestamp($0) }
        let messages = promptEngine.buildAgentMessages(
            agentId: agentId,
            framesData: frames,
            timestamps: timestampStrings
        )

        let response: String
        do {
            response = try await withThrowingTimeout(seconds: config.agentTimeout) {
                try await modelManager.generate(
                    messages: messages,
                    maxTokens: config.agentMaxTokens,
                    temperature: config.temperature,
                    imageResizeSize: config.imageResizeSize
                )
            }
            print("[\(agentId)] Raw response: \(response)")
        } catch is TimeoutError {
            return AgentResult(
                agentId: agentId,
                domain: domain,
                status: .timedOut,
                confidence: 0.0,
                reasoning: "Agent exceeded \(Int(config.agentTimeout))s timeout",
                promptVersion: "v1"
            )
        }

        return parseResponse(response)
    }

    // MARK: - Response Parsing

    private func parseResponse(_ raw: String) -> AgentResult {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            return notObservableResult(reason: "Invalid UTF-8 response")
        }

        // Try parsing as-is first, then attempt to repair truncated JSON
        let decoded: AgentResult
        if let result = try? JSONDecoder().decode(AgentResult.self, from: data) {
            decoded = result
        } else if let repaired = Self.repairTruncatedJSON(cleaned),
                  let repairedData = repaired.data(using: .utf8),
                  let result = try? JSONDecoder().decode(AgentResult.self, from: repairedData) {
            print("[\(agentId)] Repaired truncated JSON successfully")
            decoded = result
        } else {
            return notObservableResult(reason: "JSON parse failed for \(cleaned.count) chars")
        }

        // Override model's agent_id — it often hallucinates (e.g. "cat" for all agents)
        return AgentResult(
            agentId: agentId,
            domain: domain,
            status: decoded.status,
            traitScores: decoded.traitScores,
            observations: decoded.observations,
            flags: decoded.flags,
            confidence: decoded.confidence,
            reasoning: decoded.reasoning,
            promptVersion: decoded.promptVersion
        )
    }

    /// Attempt to close unclosed brackets/braces in truncated JSON from token limit.
    private static func repairTruncatedJSON(_ json: String) -> String? {
        var stack: [Character] = []
        var inString = false
        var escaped = false
        for ch in json {
            if escaped { escaped = false; continue }
            if ch == "\\" && inString { escaped = true; continue }
            if ch == "\"" { inString = !inString; continue }
            if inString { continue }
            switch ch {
            case "{": stack.append("}")
            case "[": stack.append("]")
            case "}", "]":
                if let last = stack.last, last == ch { stack.removeLast() }
            default: break
            }
        }
        guard !stack.isEmpty else { return nil } // wasn't truncated
        // Close all open brackets in reverse order
        var repaired = json
        // Trim trailing comma or incomplete value
        let trimChars = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",:\""))
        while let last = repaired.last, trimChars.contains(Unicode.Scalar(String(last))!) {
            repaired.removeLast()
        }
        repaired += stack.reversed().map(String.init).joined()
        return repaired
    }

    private func notObservableResult(reason: String) -> AgentResult {
        AgentResult(
            agentId: agentId,
            domain: domain,
            status: .notObservable,
            confidence: 0.0,
            reasoning: reason,
            promptVersion: "v1"
        )
    }

    // MARK: - Helpers

    static func formatTimestamp(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%04.1f", mins, secs)
    }
}

// MARK: - Timeout Support

struct TimeoutError: Error {}

func withThrowingTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        group.cancelAll()
        return result
    }
}
