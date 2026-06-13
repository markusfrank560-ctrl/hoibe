import Foundation
import VLMPipeline

/// PawProfiler pipeline configuration extending the shared PipelineConfig.
public struct PawProfilerConfig: Codable, Sendable {
    // MARK: - Gate
    public var gateVotes: Int = 3
    public var gateTimeout: TimeInterval = 45.0

    // MARK: - Agents
    //
    // Frame selection pipeline:
    //  1. Sample `candidateFrameCount * 2` evenly-spaced frames from the video.
    //  2. Rank all samples by sharpness, keep the top `candidateFrameCount`.
    //  3. Divide candidates into `windowsPerAgent` temporal intervals.
    //  4. Per interval: pick the `framesPerCall` sharpest → send to model.
    //  5. Gate uses the same logic (interval 0, top framesPerCall sharpest).
    //  6. Quick mode (windowsPerAgent=1): one interval = full video → one call per agent.
    //     Deep mode (windowsPerAgent=3): 3 intervals → 3 calls per agent, best confidence wins.
    //
    public var agentTimeout: TimeInterval = 90.0
    /// Number of frames sent to each model call (gate + agent).
    public var framesPerCall: Int = 3
    /// Number of temporal windows per agent. 1 = Quick (same frames for all), >1 = Deep (sliding windows).
    public var windowsPerAgent: Int = 1  // 1 = Quick, 3 = Deep
    /// Total sharp frames retained after extraction. Sampled from `candidateFrameCount * 2` raw candidates.
    public var candidateFrameCount: Int = 8

    // MARK: - Coordinator
    public var coordinatorTimeout: TimeInterval = 90.0

    // MARK: - Model
    public var modelId: String = "lmstudio-community/Qwen3-VL-4B-Instruct-MLX-4bit"
    /// Thinking requires the separate Thinking model variant (e.g. Qwen3-VL-4B-Thinking-MLX-4bit).
    /// The Instruct variant does not emit <think> blocks regardless of settings.
    public var enableThinking: Bool = false

    // MARK: - Inference
    /// Sampling temperature for model generation. Lower = more deterministic.
    public var temperature: Double = 0.1
    public var gateMaxTokens: Int = 1024
    public var agentMaxTokens: Int = 1024
    public var coordinatorMaxTokens: Int = 2048
    public var imageResizeSize: Int = 512

    // MARK: - Thermal
    public var cooldown: TimeInterval = 0.5
    public var thermalCooldown: TimeInterval = 2.0

    // MARK: - Validation
    public var minAgentsForValidProfile: Int = 3
    public var minVideoDuration: TimeInterval = 5.0
    public var maxVideoDuration: TimeInterval = 90.0

    // MARK: - Window
    public var windowMinSpan: Double = 0.6

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case enableThinking = "enable_thinking"
        case gateVotes = "gate_votes"
        case gateTimeout = "gate_timeout"
        case agentTimeout = "agent_timeout"
        case framesPerCall = "frames_per_call"
        case windowsPerAgent = "windows_per_agent"
        case candidateFrameCount = "candidate_frame_count"
        case coordinatorTimeout = "coordinator_timeout"
        case temperature
        case gateMaxTokens = "gate_max_tokens"
        case agentMaxTokens = "agent_max_tokens"
        case coordinatorMaxTokens = "coordinator_max_tokens"
        case imageResizeSize = "image_resize_size"
        case cooldown
        case thermalCooldown = "thermal_cooldown"
        case minAgentsForValidProfile = "min_agents_for_valid_profile"
        case minVideoDuration = "min_video_duration"
        case maxVideoDuration = "max_video_duration"
        case windowMinSpan = "window_min_span"
    }

    public init() {}

    /// Create a Quick Profile config (1 window per agent).
    public static func quick() -> PawProfilerConfig {
        PawProfilerConfig()
    }

    /// Create a Deep Profile config (3 windows per agent).
    public static func deep() -> PawProfilerConfig {
        var config = PawProfilerConfig()
        config.windowsPerAgent = 3
        return config
    }
}
