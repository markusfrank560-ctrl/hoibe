import Foundation
import Observation
import VLMPipeline

/// Orchestrates the full cat profiling pipeline.
/// Pipeline: extract frames → cat gate → 6 agents sequential → coordinator → profile.
@Observable
final class CatProfiler: CatProfiling, @unchecked Sendable {
    private(set) var analysisState: CatAnalysisState = .idle
    private(set) var debugLog: [DebugEntry] = []

    private let modelManager: any ModelManaging
    private let frameExtractor: any FrameExtracting
    private let promptEngine: AgentPromptEngine
    private var currentTask: Task<CompositeProfile, Error>?
    private var pipelineStart: Date?

    init(
        modelManager: any ModelManaging,
        frameExtractor: any FrameExtracting,
        promptEngine: AgentPromptEngine = AgentPromptEngine()
    ) {
        self.modelManager = modelManager
        self.frameExtractor = frameExtractor
        self.promptEngine = promptEngine
    }

    // MARK: - CatProfiling

    func analyze(
        videoURL: URL,
        mode: ProfileMode
    ) async throws -> CompositeProfile {
        let config = mode == .deep ? PawProfilerConfig.deep() : PawProfilerConfig.quick()

        let task = Task { [weak self] () -> CompositeProfile in
            guard let self else { throw ProfilerError.cancelled }
            return try await self.runPipeline(videoURL: videoURL, config: config)
        }
        currentTask = task
        return try await task.value
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        analysisState = .idle
        log("Pipeline cancelled")
    }

    // MARK: - Debug Logging

    struct DebugEntry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let message: String
        var elapsed: String {
            String(format: "%.1fs", timestamp.timeIntervalSinceNow * -1)
        }
    }

    private func log(_ message: String) {
        let entry = DebugEntry(timestamp: Date(), message: message)
        debugLog.append(entry)
        print("[PawProfiler] \(message)")
    }

    private func logElapsed(_ label: String) {
        guard let start = pipelineStart else { return }
        let elapsed = Date().timeIntervalSince(start)
        log("\(label) [\(String(format: "%.1f", elapsed))s total]")
    }

    // MARK: - Pipeline

    private func runPipeline(
        videoURL: URL,
        config: PawProfilerConfig
    ) async throws -> CompositeProfile {
        debugLog = []
        pipelineStart = Date()
        log("Pipeline started")

        // 0. Ensure model is downloaded and ready
        if !modelManager.isReady {
            analysisState = .downloadingModel(progress: 0)
            log("Model not cached — downloading…")
            let mgr = modelManager
            mgr.onProgress = { [weak self] frac in
                Task { @MainActor in
                    self?.analysisState = .downloadingModel(progress: frac)
                }
            }
            try await mgr.startDownload(allowCellular: true)
            logElapsed("Model downloaded ✓")
        } else {
            log("Model already cached ✓")
        }

        // 1. Extract frames
        analysisState = .extractingFrames
        log("Extracting frames…")
        try Task.checkCancellation()

        let frameData = try await frameExtractor.extractSharpestFrames(
            from: videoURL,
            topN: config.candidateFrameCount,
            candidateCount: config.candidateFrameCount * 2,
            window: (start: 0.0, end: 1.0),
            maxWidth: 960,
            jpegQuality: 0.85
        )

        // Select top frames for gate (framesPerCall)
        let gateFrameCount = min(config.framesPerCall, frameData.framesJPEG.count)
        let topIndices = Array(frameData.indicesBySharpness.prefix(gateFrameCount))
        let gateFrames = topIndices.map { frameData.framesJPEG[$0] }
        logElapsed("Extracted \(frameData.framesJPEG.count) frames")
        let allTimestamps = frameData.timestamps.map { String(format: "%.1fs", $0) }.joined(separator: ", ")
        log("Frame timestamps: [\(allTimestamps)]")

        // 2. Cat Gate
        analysisState = .runningGate
        log("Gate: checking \(gateFrames.count) frames for cat…")
        try Task.checkCancellation()

        let gate = CatGate(modelManager: modelManager, promptEngine: promptEngine)
        let gateResult = try await gate.runGate(frames: gateFrames, config: config)
        logElapsed("Gate result: cat=\(gateResult.catDetected)")

        try await applyCooldown(config: config)

        guard gateResult.catDetected else {
            analysisState = .gateRejected(gateResult)
            throw ProfilerError.gateRejected(gateResult)
        }

        // 3. Run 6 specialist agents sequentially
        let agents = createAgents()
        var agentResults: [AgentResult] = []

        for (index, agent) in agents.enumerated() {
            analysisState = .runningAgent(agent: index + 1, of: agents.count, name: agent.domain)
            log("Agent \(index + 1)/\(agents.count): \(agent.domain) — inference…")
            try Task.checkCancellation()

            let agentFrames = selectAgentFrames(
                from: frameData,
                config: config,
                windowIndex: 0
            )
            let agentTs = agentFrames.timestamps.map { String(format: "%.1fs", $0) }.joined(separator: ", ")
            log("  → using \(agentFrames.frames.count) frames at [\(agentTs)]")

            let result = try await agent.analyze(
                frames: agentFrames.frames,
                timestamps: agentFrames.timestamps,
                config: config
            )
            agentResults.append(result)
            logElapsed("Agent \(agent.domain) done (conf: \(String(format: "%.2f", result.confidence)))")

            try await applyCooldown(config: config)
        }

        // Deep mode: additional windows for each agent
        if config.windowsPerAgent > 1 {
            agentResults = try await runDeepWindows(
                agents: agents,
                existingResults: agentResults,
                frameData: frameData,
                config: config
            )
        }

        // 4. Coordinator
        analysisState = .runningCoordinator
        log("Coordinator: synthesizing profile…")
        try Task.checkCancellation()

        let coordinator = ProfileCoordinator(
            modelManager: modelManager,
            promptEngine: promptEngine
        )

        // Check minimum agent threshold
        let completedCount = agentResults.filter { $0.status == .completed }.count
        guard completedCount >= config.minAgentsForValidProfile else {
            throw ProfilerError.insufficientAgents(completed: completedCount, required: config.minAgentsForValidProfile)
        }

        let profile = try await coordinator.synthesize(
            agentResults: agentResults,
            config: config
        )

        analysisState = .complete(profile)
        logElapsed("Pipeline complete ✓")
        return profile
    }

    // MARK: - Deep Mode Windows

    private func runDeepWindows(
        agents: [any BehaviorAnalyzing],
        existingResults: [AgentResult],
        frameData: FrameData,
        config: PawProfilerConfig
    ) async throws -> [AgentResult] {
        var allResults = existingResults

        for windowIndex in 1..<config.windowsPerAgent {
            for (index, agent) in agents.enumerated() {
                analysisState = .runningAgent(
                    agent: index + 1,
                    of: agents.count,
                    name: "\(agent.domain) (window \(windowIndex + 1))"
                )
                try Task.checkCancellation()

                let agentFrames = selectAgentFrames(
                    from: frameData,
                    config: config,
                    windowIndex: windowIndex
                )
                let agentTs = agentFrames.timestamps.map { String(format: "%.1fs", $0) }.joined(separator: ", ")
                log("Agent \(index + 1)/\(agents.count): \(agent.domain) (window \(windowIndex + 1)) — \(agentFrames.frames.count) frames at [\(agentTs)]")

                let result = try await agent.analyze(
                    frames: agentFrames.frames,
                    timestamps: agentFrames.timestamps,
                    config: config
                )

                // Merge: keep the result with higher confidence
                if let existingIndex = allResults.firstIndex(where: { $0.agentId == agent.agentId }) {
                    if result.confidence > allResults[existingIndex].confidence {
                        allResults[existingIndex] = result
                    }
                } else {
                    allResults.append(result)
                }

                try await applyCooldown(config: config)
            }
        }

        return allResults
    }

    // MARK: - Agent Creation

    private func createAgents() -> [any BehaviorAnalyzing] {
        [
            BreedArchetypeAgent(modelManager: modelManager, promptEngine: promptEngine),
            PersonalityAgent(modelManager: modelManager, promptEngine: promptEngine),
            SocialBehaviorAgent(modelManager: modelManager, promptEngine: promptEngine),
            PlayActivityAgent(modelManager: modelManager, promptEngine: promptEngine),
            StressWelfareAgent(modelManager: modelManager, promptEngine: promptEngine),
            HealthBehaviorAgent(modelManager: modelManager, promptEngine: promptEngine),
        ]
    }

    // MARK: - Frame Selection

    private struct AgentFrameSelection {
        let frames: [Data]
        let timestamps: [Double]
    }

    private func selectAgentFrames(
        from frameData: FrameData,
        config: PawProfilerConfig,
        windowIndex: Int
    ) -> AgentFrameSelection {
        let totalFrames = frameData.framesJPEG.count
        let framesNeeded = min(config.framesPerCall, totalFrames)
        let windowCount = max(config.windowsPerAgent, 1)

        // Divide candidates (already time-sorted by index) into windowCount temporal slices
        let windowSize = totalFrames / windowCount
        let start = windowIndex * windowSize
        let end = (windowIndex == windowCount - 1) ? totalFrames : start + windowSize
        let sliceIndices = Array(start..<end)

        // Pick top framesPerCall by sharpness within this slice
        let ranked = sliceIndices
            .sorted { frameData.sharpnessScores[$0] > frameData.sharpnessScores[$1] }
        let selected = Array(ranked.prefix(framesNeeded)).sorted()

        return AgentFrameSelection(
            frames: selected.map { frameData.framesJPEG[$0] },
            timestamps: selected.map { frameData.timestamps[$0] }
        )
    }

    // MARK: - Thermal / Cooldown

    private func applyCooldown(config: PawProfilerConfig) async throws {
        try Task.checkCancellation()

        let thermalState = ProcessInfo.processInfo.thermalState
        let cooldown: TimeInterval

        switch thermalState {
        case .critical:
            // Pause longer at critical thermal state
            cooldown = config.thermalCooldown * 2
        case .serious:
            cooldown = config.thermalCooldown
        default:
            cooldown = config.cooldown
        }

        try await Task.sleep(for: .seconds(cooldown))
    }
}

// MARK: - Errors

enum ProfilerError: Error, LocalizedError {
    case gateRejected(CatGateResult)
    case insufficientAgents(completed: Int, required: Int)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .gateRejected(let result):
            if let species = result.speciesGuess {
                return "No cat detected — looks like a \(species)"
            }
            return "No cat detected in the video"
        case .insufficientAgents(let completed, let required):
            return "Only \(completed) agents completed (minimum \(required) required)"
        case .cancelled:
            return "Analysis was cancelled"
        }
    }
}
