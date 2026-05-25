import Foundation
import Observation
import VLMPipeline

/// Orchestrates the full cat profiling pipeline.
/// Pipeline: extract frames → cat gate → 6 agents sequential → coordinator → profile.
@Observable
final class CatProfiler: CatProfiling, @unchecked Sendable {
    private(set) var analysisState: CatAnalysisState = .idle

    private let modelManager: any ModelManaging
    private let frameExtractor: any FrameExtracting
    private let promptEngine: AgentPromptEngine
    private var currentTask: Task<CompositeProfile, Error>?

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
    }

    // MARK: - Pipeline

    private func runPipeline(
        videoURL: URL,
        config: PawProfilerConfig
    ) async throws -> CompositeProfile {
        // 1. Extract frames
        analysisState = .extractingFrames
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

        // 2. Cat Gate
        analysisState = .runningGate
        try Task.checkCancellation()

        let gate = CatGate(modelManager: modelManager, promptEngine: promptEngine)
        let gateResult = try await gate.runGate(frames: gateFrames, config: config)

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
            try Task.checkCancellation()

            let agentFrames = selectAgentFrames(
                from: frameData,
                config: config,
                windowIndex: 0
            )

            let result = try await agent.analyze(
                frames: agentFrames.frames,
                timestamps: agentFrames.timestamps,
                config: config
            )
            agentResults.append(result)

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
            PersonalityAgent(modelManager: modelManager, promptEngine: promptEngine),
            SocialBehaviorAgent(modelManager: modelManager, promptEngine: promptEngine),
            PlayActivityAgent(modelManager: modelManager, promptEngine: promptEngine),
            StressWelfareAgent(modelManager: modelManager, promptEngine: promptEngine),
            HealthBehaviorAgent(modelManager: modelManager, promptEngine: promptEngine),
            BreedArchetypeAgent(modelManager: modelManager, promptEngine: promptEngine),
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

        if config.windowsPerAgent <= 1 || totalFrames <= framesNeeded {
            // Quick mode or not enough frames: use top N by sharpness
            let indices = Array(frameData.indicesBySharpness.prefix(framesNeeded))
            let sortedByTime = indices.sorted()
            return AgentFrameSelection(
                frames: sortedByTime.map { frameData.framesJPEG[$0] },
                timestamps: sortedByTime.map { frameData.timestamps[$0] }
            )
        }

        // Deep mode: distribute frames across temporal windows
        let windowCount = config.windowsPerAgent
        let windowSize = totalFrames / windowCount
        let start = windowIndex * windowSize
        let end = min(start + windowSize, totalFrames)
        let windowFrames = Array(start..<end)

        // Pick top frames by sharpness within this window
        let ranked = windowFrames
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
