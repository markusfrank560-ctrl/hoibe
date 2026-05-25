import SwiftUI

/// Displayed when the cat gate rejects the video (no cat or not a cat).
struct GateRejectedView: View {
    let result: CatGateResult

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundStyle(.orange.opacity(0.6))

            Text(title)
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let species = result.speciesGuess {
                Label("Detected: \(species)", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(spacing: 8) {
                Text("Tips for better results:")
                    .font(.subheadline.bold())

                VStack(alignment: .leading, spacing: 6) {
                    tipRow("Ensure your cat is clearly visible")
                    tipRow("Use good lighting conditions")
                    tipRow("Film for at least 15 seconds")
                    tipRow("Keep the camera relatively steady")
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }

    private var iconName: String {
        switch result.status {
        case .notACat: return "dog.fill"
        case .noCatDetected: return "questionmark.circle"
        case .catDetected: return "cat.fill"
        }
    }

    private var title: String {
        switch result.status {
        case .notACat: return "That's Not a Cat"
        case .noCatDetected: return "No Cat Found"
        case .catDetected: return "Cat Detected"
        }
    }

    private var message: String {
        switch result.status {
        case .notACat:
            if let species = result.speciesGuess {
                return "It looks like there's a \(species) in the video instead of a cat. Please try again with a video featuring a cat."
            }
            return "The animal in the video doesn't appear to be a cat. Please try again with a cat video."
        case .noCatDetected:
            return "We couldn't find a cat in the video. Make sure your cat is visible and try again."
        case .catDetected:
            return "A cat was detected."
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
