import Foundation

/// Profile analysis mode.
public enum ProfileMode: String, Codable, Sendable {
    case quick  // windowsPerAgent = 1
    case deep   // windowsPerAgent = 3
}

/// Single analysis run metadata (v1: in-memory only).
public struct AnalysisSession: Sendable {
    public let id: UUID
    public let startedAt: Date
    public var completedAt: Date?
    public let videoURL: URL
    public let videoDuration: TimeInterval
    public let profileMode: ProfileMode
    public var gateResult: CatGateResult?
    public var compositeProfile: CompositeProfile?

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        videoURL: URL,
        videoDuration: TimeInterval,
        profileMode: ProfileMode
    ) {
        self.id = id
        self.startedAt = startedAt
        self.videoURL = videoURL
        self.videoDuration = videoDuration
        self.profileMode = profileMode
    }
}
