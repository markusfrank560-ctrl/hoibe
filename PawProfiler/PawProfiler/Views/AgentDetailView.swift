import SwiftUI

/// Per-agent reasoning drill-down with research references.
/// Accessible from PersonaCardView agent details section.
struct AgentDetailView: View {
    let result: AgentResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                header

                // Status & Confidence
                statusCard

                // Trait Scores
                if let scores = result.traitScores, !scores.isEmpty {
                    traitScoresSection(scores)
                }

                // Observations
                if !result.observations.isEmpty {
                    observationsSection
                }

                // Flags
                if !result.flags.isEmpty {
                    flagsSection
                }

                // Reasoning
                if let reasoning = result.reasoning, !reasoning.isEmpty {
                    reasoningSection(reasoning)
                }

                // Research Reference
                researchReference

                // Metadata
                metadataSection
            }
            .padding()
        }
        .navigationTitle(result.domain)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: agentIcon)
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(result.domain)
                    .font(.title2.bold())
            }
            Text("Agent: \(result.agentId)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var agentIcon: String {
        switch result.agentId {
        case "personality": return "brain.head.profile"
        case "social": return "person.2"
        case "play": return "figure.play"
        case "stress": return "exclamationmark.triangle"
        case "health": return "heart.text.clipboard"
        case "breed": return "cat"
        default: return "pawprint"
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(statusText)
                    .font(.subheadline.bold())
                    .foregroundStyle(statusColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Confidence")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(String(format: "%.0f%%", result.confidence * 100))
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusText: String {
        switch result.status {
        case .completed: return "Completed"
        case .notObservable: return "Not Observable"
        case .timedOut: return "Timed Out"
        case .failed: return "Failed"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .completed: return .green
        case .notObservable: return .secondary
        case .timedOut: return .yellow
        case .failed: return .red
        }
    }

    // MARK: - Trait Scores

    private func traitScoresSection(_ scores: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Trait Scores", systemImage: "chart.bar")
                .font(.headline)

            ForEach(scores.sorted(by: { $0.key < $1.key }), id: \.key) { trait, score in
                HStack {
                    Text(trait.capitalized)
                        .font(.subheadline)
                        .frame(width: 110, alignment: .leading)
                    ProgressView(value: score, total: 1.0)
                        .tint(.orange)
                    Text(String(format: "%.0f%%", score * 100))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Observations

    private var observationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Observations", systemImage: "eye")
                .font(.headline)

            ForEach(result.observations, id: \.self) { observation in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 3)
                    Text(observation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Flags

    private var flagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Flags", systemImage: "flag")
                .font(.headline)
                .foregroundStyle(.yellow)

            ForEach(result.flags, id: \.self) { flag in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(flag.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Reasoning

    private func reasoningSection(_ reasoning: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Reasoning", systemImage: "text.alignleft")
                .font(.headline)

            Text(reasoning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Research Reference

    private var researchReference: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Research Basis", systemImage: "book")
                .font(.headline)

            Text(researchText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineSpacing(3)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var researchText: String {
        switch result.agentId {
        case "personality":
            return "Based on the Feline Five framework (Litchfield et al., 2017). Factor analysis of N=2,802 cats identified five personality dimensions: Neuroticism, Extraversion, Dominance, Impulsiveness, and Agreeableness."
        case "social":
            return "Based on cat–human attachment research (Vitale Shreve & Udell, 2017; Turner & Bateson, 2014). Cats form attachment bonds similar to infant–caregiver patterns."
        case "play":
            return "Based on predatory behavior research (Hall et al., 2002; Bradshaw, 2013). Play sequences retain predatory motor patterns: stalk → pounce → bite → manipulate."
        case "stress":
            return "Based on the Cat-Stress-Score system (Kessler & Turner, 1997) and AAFP/ISFM welfare guidelines (Dantas et al., 2016). Visual indicators include ear position, eye aperture, and body posture."
        case "health":
            return "Based on pain assessment research (Robertson, 2008; Lascelles et al., 2007) and the Feline Grimace Scale (Evangelista et al., 2019). Behavioral indicators correlate with health changes."
        case "breed":
            return "Based on the Helsinki Breed Study (Salonen et al., 2019, Nature). Behavioral heritability 0.40–0.53 across 26 breeds (N=4,316 cats)."
        default:
            return "Domain-specific behavioral analysis."
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(spacing: 4) {
            Text("Prompt Version: \(result.promptVersion)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
