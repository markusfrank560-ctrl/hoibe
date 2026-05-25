import Foundation

/// Role in a chat conversation with the VLM.
public enum ChatRole: String, Sendable {
    case system
    case user
    case assistant
}

/// A single message in a VLM conversation.
public struct ChatMessage: Sendable {
    public let role: ChatRole
    public let text: String
    public let images: [Data]

    public init(role: ChatRole, text: String, images: [Data] = []) {
        self.role = role
        self.text = text
        self.images = images
    }
}
