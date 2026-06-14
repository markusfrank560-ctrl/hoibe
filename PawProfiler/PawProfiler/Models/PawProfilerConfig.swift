import Foundation
import VLMPipeline

// ┌──────────────────────────────────────────────────────────────────┐
// │ TARGET DEVICE: iPhone 12 Pro (A14 Bionic, 6 GB RAM)             │
// │ Config: 3B model, 1 frame/call, 336px, v2 prompts.             │
// └──────────────────────────────────────────────────────────────────┘
//
// MODEL HISTORY (iPhone 12 Pro, 6 GB):
// ┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
// │ #  Model                                      Weights  KV+Act  Peak RAM  Result                         │
// │ 1  mlx-community/Qwen3-VL-4B-Instruct-4bit  ~2.9 GB  ~1.5 GB ~4.4 GB  Too slow (~25s/call)            │
// │ 2  mlx-community/Qwen3-VL-2B-Instruct-4bit   ~1.7 GB  ~2.5 GB ~4.2 GB  OOM — v1 prompts: long sys (~600tok) + uncapped output → large KV pre-alloc + aggressive ViT │
// │ 3  mlx-community/Qwen2.5-VL-3B-Instruct-4bit ~1.9 GB  ~1.5 GB ~3.4 GB  Metal GPU fault at 336px         │
// │ 4  mlx-community/Qwen2-VL-2B-Instruct-4bit   ~1.2 GB  ~0.8 GB ~2.0 GB  Stable at 336px, placeholder echo │
// │ 5  mlx-community/Qwen3-VL-2B-Instruct-4bit   ~1.7 GB  ~1.0 GB ~2.7 GB  ✓ Retrying — v2 prompts: short sys (~150tok) + 256 max_tokens cap → small KV pre-alloc │
// └──────────────────────────────────────────────────────────────────────────────────────────────────────┘
// RAM budget on iPhone 12 Pro (6 GB): ~4.5 GB usable for app (iOS keeps ~1.5 GB).
// KV+Act = KV cache + activations.
//   KV cache: key/value tensors stored per transformer layer for every generated token.
//             Grows with sequence length (vision tokens + prompt tokens + output tokens).
//             At 336px: ~784 vision tokens + ~300 prompt tokens + 256 output = ~1340 tokens.
//   Activations: intermediate tensors held in GPU memory during the forward pass.
//                Peak at inference time; freed after each token is generated.
//   Together they dominate runtime RAM on top of the static model weights.
// IMAGE SIZE HISTORY:
// ┌─────────────────────────────────────────────────────────────────────────┐
// │ 192px → Cat not detected (too few ViT patches)                         │
// │ 256px → Cat detected, but agent scores flat (0 / 0.5)                  │
// │ 336px → Current (≈28×28 patches = ~784 vision tokens)                  │
// │ 512px → Metal GPU Page Fault (OOM) on iPhone 12 Pro                    │
// └─────────────────────────────────────────────────────────────────────────┘

/// PawProfiler pipeline configuration extending the shared PipelineConfig.
public struct PawProfilerConfig: Codable, Sendable {
    // MARK: - Gate
    public var gateVotes: Int = 1
    public var gateTimeout: TimeInterval = 60.0

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
    public var agentTimeout: TimeInterval = 120.0
    /// Number of frames sent to each model call (gate + agent).
    public var framesPerCall: Int = 1
    /// Number of temporal windows per agent. 1 = Quick (same frames for all), >1 = Deep (sliding windows).
    public var windowsPerAgent: Int = 1  // 1 = Quick, 3 = Deep
    /// Total sharp frames retained after extraction. Sampled from `candidateFrameCount * 2` raw candidates.
    public var candidateFrameCount: Int = 4

    // MARK: - Coordinator
    public var coordinatorTimeout: TimeInterval = 120.0

    // MARK: - Model
    public var modelId: String = "mlx-community/Qwen3-VL-2B-Instruct-4bit"
    /// Approximate download size shown in UI while offline (updated per model).
    public var modelDownloadGB: String = "1.7"
    /// Human-readable display name derived from modelId for UI and metadata.
    public var modelDisplayName: String {
        // e.g. "mlx-community/Qwen2-VL-2B-Instruct-4bit" → "Qwen2-VL-2B"
        let repo = modelId.split(separator: "/").last.map(String.init) ?? modelId
        let parts = repo.split(separator: "-")
        // Take up to the size token (e.g. 2B / 4B / 7B)
        var label: [String] = []
        for part in parts {
            label.append(String(part))
            if part.hasSuffix("B") || part.hasSuffix("b") { break }
        }
        return label.joined(separator: "-")
    }
    /// Thinking requires the separate Thinking model variant (e.g. Qwen3-VL-4B-Thinking-MLX-4bit).
    /// The Instruct variant does not emit <think> blocks regardless of settings.
    public var enableThinking: Bool = false

    // MARK: - Inference
    /// Sampling temperature for model generation. Lower = more deterministic.
    public var temperature: Double = 0.1
    public var gateMaxTokens: Int = 256
    public var agentMaxTokens: Int = 256
    public var coordinatorMaxTokens: Int = 256
    public var imageResizeSize: Int = 192

    // MARK: - Thermal
    /// Inter-call cooldown. Kept at 0 for <30s inferences — thermal throttling
    /// is already managed by iOS; artificial delays don't help at this timescale.
    public var cooldown: TimeInterval = 0.0
    public var thermalCooldown: TimeInterval = 0.0

    // MARK: - Prompts
    /// Version directory for prompt files under Resources/Prompts/{agent}/{promptVersion}/system.txt
    public var promptVersion: String = "v2"

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
        case promptVersion = "prompt_version"
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

    /// Adapt a base config to the current device's memory tier at runtime.
    /// Constrains model, image size, and token budgets to avoid OOM on older devices.
    public static func adapted(from base: PawProfilerConfig) -> PawProfilerConfig {
        var config = base
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
        config.modelId = "mlx-community/Qwen3-VL-2B-Instruct-4bit"

        if ramGB >= 8 {
            // iPhone 16 Pro / Pro Max tier: full quality
            config.imageResizeSize = 192
            config.agentMaxTokens = 512
            config.gateMaxTokens = 512
            config.coordinatorMaxTokens = 1024
        } else {
            // iPhone 12 Pro / older tier: memory-safe
            config.imageResizeSize = 192
            config.agentMaxTokens = 256
            config.gateMaxTokens = 256
            config.coordinatorMaxTokens = 256
        }

        return config
    }
}
