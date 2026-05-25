import Foundation

/// State of the model download lifecycle.
public enum ModelDownloadState: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double)
    case paused(bytesDownloaded: Int64)
    case ready
    case error(message: String)
}
