// SPDX-License-Identifier: MIT
// Contract: PromptBuilding protocol

import Foundation

/// Builds chat messages from prompt templates for VLM inference.
protocol PromptBuilding: Sendable {

    /// Build messages for the fill-level gate prompt.
    /// - Parameters:
    ///   - imageData: Single JPEG-encoded frame.
    /// - Returns: Array of ChatMessages (system + user with image).
    func buildFillLevelMessages(imageData: Data) -> [ChatMessage]

    /// Build messages for the sliding-window sip detection prompt.
    /// - Parameters:
    ///   - framesData: JPEG-encoded frames for the window.
    ///   - timestamps: Formatted timestamp strings for the frames.
    /// - Returns: Array of ChatMessages (system + user with images).
    func buildSipDetectionMessages(
        framesData: [Data],
        timestamps: [String]
    ) -> [ChatMessage]
}
