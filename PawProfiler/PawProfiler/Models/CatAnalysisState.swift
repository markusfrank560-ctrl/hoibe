import Foundation

/// Pipeline analysis state for UI observation.
public enum CatAnalysisState: Equatable, Sendable {
    case idle
    case extractingFrames
    case runningGate
    case gateRejected(CatGateResult)
    case runningAgent(agent: Int, of: Int, name: String)
    case runningCoordinator
    case complete(CompositeProfile)
    case error(String)
}
