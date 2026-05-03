import Foundation

/// State of the analysis pipeline for UI observation.
enum AnalysisState: Equatable, Sendable {
    case idle
    case validating
    case extractingFrames
    case runningGate(vote: Int, total: Int)
    case runningWindows(window: Int, total: Int)
    case complete(AnalysisResult)
    case error(String)
}
