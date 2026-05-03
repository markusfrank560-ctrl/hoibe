import Foundation

/// Orchestrates the full first-sip detection pipeline: gate → windows → result.
final class SipDetector: SipDetecting, @unchecked Sendable {

    private let modelManager: ModelManaging
    private let frameExtractor: FrameExtracting
    private let promptEngine: PromptBuilding
    private let config: PipelineConfig

    private var currentTask: Task<AnalysisResult, Error>?

    @Published private(set) var analysisState: AnalysisState = .idle

    init(
        modelManager: ModelManaging,
        frameExtractor: FrameExtracting = FrameExtractor(),
        promptEngine: PromptBuilding = PromptEngine(),
        config: PipelineConfig = PipelineConfig()
    ) {
        self.modelManager = modelManager
        self.frameExtractor = frameExtractor
        self.promptEngine = promptEngine
        self.config = config
    }

    func analyze(videoURL: URL) async throws -> AnalysisResult {
        let task = Task { [self] in
            try await runPipeline(videoURL: videoURL)
        }
        currentTask = task
        return try await task.value
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        analysisState = .idle
    }

    // MARK: - Pipeline

    private func runPipeline(videoURL: URL) async throws -> AnalysisResult {
        // Gate: fill-level check
        analysisState = .extractingFrames

        let gateFrames = try await frameExtractor.extractSharpestFrames(
            from: videoURL,
            topN: config.gateVotes,
            candidateCount: max(config.gateVotes * 2, 6),
            window: config.gateWindow,
            maxWidth: config.maxWidth,
            jpegQuality: config.jpegQuality
        )

        var rejectCount = 0
        for vote in 0..<config.gateVotes {
            try Task.checkCancellation()
            analysisState = .runningGate(vote: vote + 1, total: config.gateVotes)

            let messages = promptEngine.buildFillLevelMessages(imageData: gateFrames.framesJPEG[vote])

            let response = try await withTimeout(config.gateTimeout) { [self] in
                try await modelManager.generate(messages: messages, maxTokens: 50, temperature: config.temperature)
            }

            let level = parseFillLevel(response)
            print("[SipDetector] Gate vote \(vote+1): response='\(response.prefix(80))' → level=\(level)")
            if config.rejectLevels.contains(level) {
                rejectCount += 1
            }

            if vote < config.gateVotes - 1 {
                try await Task.sleep(for: .seconds(config.cooldown))
            }
        }

        // Majority vote: reject if majority says non-full
        if rejectCount > config.gateVotes / 2 {
            let result = makeNegativeResult(reason: "Glas nicht voll – kein erster Schluck")
            print("[SipDetector] Gate rejected (\(rejectCount)/\(config.gateVotes) reject votes) → returning negative result")
            analysisState = .complete(result)
            return result
        }

        print("[SipDetector] Gate passed (\(rejectCount)/\(config.gateVotes) reject votes) → proceeding to windows")

        // Windows: sliding-window sip detection
        let fullFrames = try await frameExtractor.extractFrames(
            from: videoURL,
            count: config.windowCount * 4,
            window: (start: 0.0, end: 1.0),
            maxWidth: config.maxWidth,
            jpegQuality: config.jpegQuality
        )

        let framesPerWindow = fullFrames.framesJPEG.count / config.windowCount

        for windowIdx in 0..<config.windowCount {
            try Task.checkCancellation()
            analysisState = .runningWindows(window: windowIdx + 1, total: config.windowCount)

            let startIdx = windowIdx * framesPerWindow
            let endIdx = min(startIdx + framesPerWindow, fullFrames.framesJPEG.count)
            let windowFrames = Array(fullFrames.framesJPEG[startIdx..<endIdx])
            let windowTimestamps = Array(fullFrames.timestamps[startIdx..<endIdx]).map { String(format: "%.2fs", $0) }

            let messages = promptEngine.buildSipDetectionMessages(framesData: windowFrames, timestamps: windowTimestamps)

            do {
                let response = try await withTimeout(config.windowTimeout) { [self] in
                    try await modelManager.generate(messages: messages, maxTokens: 200, temperature: config.temperature)
                }

                if let result = parseWindowResult(response, videoURL: videoURL) {
                    if result.firstSipDetected && result.confidence >= 0.7 {
                        analysisState = .complete(result)
                        return result
                    }
                }
            } catch {
                // Timeout or error — skip window, continue
                continue
            }

            if windowIdx < config.windowCount - 1 {
                try await Task.sleep(for: .seconds(config.cooldown))
            }
        }

        let result = makeNegativeResult(reason: "Kein erster Schluck in den Analysefenstern erkannt")
        analysisState = .complete(result)
        return result
    }

    // MARK: - Parsing

    private func parseFillLevel(_ response: String) -> BeerFillLevel {
        let lower = response.lowercased()
        for level in BeerFillLevel.allCases {
            if lower.contains(level.rawValue.replacingOccurrences(of: "_", with: " ")) || lower.contains(level.rawValue) {
                return level
            }
        }
        return .unknown
    }

    private func parseWindowResult(_ response: String, videoURL: URL) -> AnalysisResult? {
        // Extract JSON from response (may be wrapped in markdown code block)
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let detected = json["first_sip_detected"] as? Bool ?? false
        let confidence = json["confidence"] as? Double ?? 0.0
        let reason = json["reason_short"] as? String ?? ""

        return AnalysisResult(
            firstSipDetected: detected,
            confidence: confidence,
            reasonShort: reason,
            faceVisible: true,
            drinkingObjectVisible: true,
            mouthContactLikely: detected,
            beerLikely: "true",
            beerFillLevel: .full,
            modelName: "Qwen3-VL-4B-Instruct-MLX-4bit",
            analysisVersion: "v3",
            analyzedAt: ISO8601DateFormatter().string(from: Date()),
            sourceVideo: videoURL.lastPathComponent
        )
    }

    private func makeNegativeResult(reason: String) -> AnalysisResult {
        AnalysisResult(
            firstSipDetected: false,
            confidence: 0.1,
            reasonShort: reason,
            faceVisible: true,
            drinkingObjectVisible: true,
            mouthContactLikely: false,
            beerLikely: "true",
            beerFillLevel: .full,
            modelName: "Qwen3-VL-4B-Instruct-MLX-4bit",
            analysisVersion: "v3",
            analyzedAt: nil,
            sourceVideo: nil
        )
    }

    // MARK: - Timeout

    private func withTimeout<T>(_ seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw CancellationError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
