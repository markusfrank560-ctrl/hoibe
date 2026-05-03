import Foundation

/// Role in a chat conversation with the VLM.
enum ChatRole: String, Sendable {
    case system
    case user
    case assistant
}

/// A single message in a VLM conversation.
struct ChatMessage: Sendable {
    let role: ChatRole
    let text: String
    let images: [Data]

    init(role: ChatRole, text: String, images: [Data] = []) {
        self.role = role
        self.text = text
        self.images = images
    }
}
