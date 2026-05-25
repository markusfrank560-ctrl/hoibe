import Foundation
import VLMPipeline

/// PawProfiler pipeline configuration extending the shared PipelineConfig.
public struct PawProfilerConfig: Codable, Sendable {
    // MARK: - Gate
    public var gateVotes: Int = 3
    public var gateTimeout: TimeInterval = 45.0

    // MARK: - Agents
    public var agentTimeout: TimeInterval = 90.0
    public var framesPerCall: Int = 3
    public var windowsPerAgent: Int = 1  // 1 = Quick, 3 = Deep
    public var candidateFrameCount: Int = 8

    // MARK: - Coordinator
    public var coordinatorTimeout: TimeInterval = 90.0

    // MARK: - Inference
    public var numCtx: Int = 4096
    public var temperature: Double = 0.1

    // MARK: - Thermal
    public var cooldown: TimeInterval = 2.0
    public var thermalCooldown: TimeInterval = 5.0

    // MARK: - Validation
    public var minAgentsForValidProfile: Int = 3
    public var minVideoDuration: TimeInterval = 15.0
    public var maxVideoDuration: TimeInterval = 90.0

    // MARK: - Window
    public var windowMinSpan: Double = 0.6

    enum CodingKeys: String, CodingKey {
        case gateVotes = "gate_votes"
        case gateTimeout = "gate_timeout"
        case agentTimeout = "agent_timeout"
        case framesPerCall = "frames_per_call"
        case windowsPerAgent = "windows_per_agent"
        case candidateFrameCount = "candidate_frame_count"
        case coordinatorTimeout = "coordinator_timeout"
        case numCtx = "num_ctx"
        case temperature
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
