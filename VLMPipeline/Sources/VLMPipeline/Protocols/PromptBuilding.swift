import Foundation

/// Base protocol for prompt building across apps.
/// Apps define their own domain-specific prompt protocols
/// (e.g., SipPromptBuilding for Hoibe, AgentPromptBuilding for PawProfiler).
public protocol PromptBuilding: Sendable {}
