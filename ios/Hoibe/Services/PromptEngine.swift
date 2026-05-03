import Foundation

/// Loads bundled prompt templates and builds ChatMessage arrays for VLM inference.
struct PromptEngine: PromptBuilding {

    private let systemPrompt: String
    private let userPromptTemplate: String
    private let fillLevelPrompt: String

    init() {
        func loadPrompt(_ name: String) -> String {
            guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Prompts"),
                  let content = try? String(contentsOf: url, encoding: .utf8) else {
                fatalError("Missing bundled prompt: \(name).txt")
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        self.systemPrompt = loadPrompt("system_prompt")
        self.userPromptTemplate = loadPrompt("user_prompt_template")
        self.fillLevelPrompt = loadPrompt("fill_level_prompt")
    }

    func buildFillLevelMessages(imageData: Data) -> [ChatMessage] {
        [
            ChatMessage(role: .system, text: fillLevelPrompt),
            ChatMessage(role: .user, text: "Analyze this image.", images: [imageData])
        ]
    }

    func buildSipDetectionMessages(framesData: [Data], timestamps: [String]) -> [ChatMessage] {
        let timestampList = timestamps.joined(separator: ", ")
        let userText = userPromptTemplate.replacingOccurrences(of: "{{TIMESTAMPS}}", with: timestampList)
        return [
            ChatMessage(role: .system, text: systemPrompt),
            ChatMessage(role: .user, text: userText, images: framesData)
        ]
    }
}
