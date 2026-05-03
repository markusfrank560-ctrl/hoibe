import Foundation

/// Pipeline configuration with defaults matching the validated Mac config.
struct PipelineConfig: Codable, Sendable {
    var gateVotes: Int = 3
    var gateTimeout: TimeInterval = 45
    var gateWindow: (start: Double, end: Double) = (0.0, 0.10)
    var windowCount: Int = 3
    var windowMinSpan: Double = 0.6
    var windowTimeout: TimeInterval = 90
    var numCtx: Int = 4096
    var temperature: Double = 0.1
    var maxWidth: Int = 1024
    var jpegQuality: Double = 1.0
    var cooldown: TimeInterval = 2.0
    var think: Bool = false
    var rejectLevels: Set<BeerFillLevel> = [.half, .mostlyEmpty, .empty]

    enum CodingKeys: String, CodingKey {
        case gateVotes = "gate_votes"
        case gateTimeout = "gate_timeout"
        case windowCount = "window_count"
        case windowMinSpan = "window_min_span"
        case windowTimeout = "window_timeout"
        case numCtx = "num_ctx"
        case temperature
        case maxWidth = "max_width"
        case jpegQuality = "jpeg_quality"
        case cooldown
    }

    // Custom coding for non-Codable properties
    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gateVotes = try container.decodeIfPresent(Int.self, forKey: .gateVotes) ?? 3
        gateTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .gateTimeout) ?? 45
        windowCount = try container.decodeIfPresent(Int.self, forKey: .windowCount) ?? 3
        windowMinSpan = try container.decodeIfPresent(Double.self, forKey: .windowMinSpan) ?? 0.6
        windowTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .windowTimeout) ?? 90
        numCtx = try container.decodeIfPresent(Int.self, forKey: .numCtx) ?? 4096
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.1
        maxWidth = try container.decodeIfPresent(Int.self, forKey: .maxWidth) ?? 1024
        jpegQuality = try container.decodeIfPresent(Double.self, forKey: .jpegQuality) ?? 0.9
        cooldown = try container.decodeIfPresent(TimeInterval.self, forKey: .cooldown) ?? 2.0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gateVotes, forKey: .gateVotes)
        try container.encode(gateTimeout, forKey: .gateTimeout)
        try container.encode(windowCount, forKey: .windowCount)
        try container.encode(windowMinSpan, forKey: .windowMinSpan)
        try container.encode(windowTimeout, forKey: .windowTimeout)
        try container.encode(numCtx, forKey: .numCtx)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(maxWidth, forKey: .maxWidth)
        try container.encode(jpegQuality, forKey: .jpegQuality)
        try container.encode(cooldown, forKey: .cooldown)
    }
}
