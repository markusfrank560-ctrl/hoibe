import SwiftUI

/// Cat Persona Card — the main result view after analysis.
/// Shows archetype, radar chart, persona description, observations,
/// breed affinity, and stress/health hints.
struct PersonaCardView: View {
    let profile: CompositeProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Archetype Header
                archetypeHeader

                // Radar Chart
                RadarChartView(scores: profile.felineFiveScores, size: 200)
                    .padding(.vertical, 8)

                // Persona Description
                personaDescription

                // Top Observations
                observationsSection

                // Breed Affinity
                if !profile.breedEstimate.isEmpty {
                    breedSection
                }

                // Stress / Health Hints
                if !profile.stressIndicators.isEmpty || !profile.healthFlags.isEmpty {
                    alertsSection
                }

                // Agent Details Drill-Down
                agentDetailsSection

                // Metadata Footer
                metadataFooter
            }
            .padding()
        }
    }

    // MARK: - Archetype Header

    private var archetypeHeader: some View {
        VStack(spacing: 8) {
            Text(profile.archetypeLabel)
                .font(.title.bold())
                .foregroundStyle(.orange)

            HStack(spacing: 6) {
                Image(systemName: moodIcon)
                    .foregroundStyle(.secondary)
                Text("Mood: \(profile.overallMood.capitalized)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var moodIcon: String {
        switch profile.overallMood.lowercased() {
        case "playful": return "figure.play"
        case "relaxed": return "moon.zzz"
        case "anxious": return "exclamationmark.triangle"
        case "content": return "face.smiling"
        default: return "cat"
        }
    }

    // MARK: - Persona Description

    private var personaDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Personality Portrait", systemImage: "text.quote")
                .font(.headline)

            Text(profile.archetypeDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Observations

    private var observationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Key Observations", systemImage: "eye")
                .font(.headline)

            ForEach(Array(profile.topObservations.prefix(5).enumerated()), id: \.offset) { _, observation in
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Breed

    private var breedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Breed Affinity", systemImage: "cat")
                .font(.headline)

            ForEach(Array(profile.breedEstimate.prefix(3).enumerated()), id: \.offset) { _, estimate in
                HStack {
                    Text(estimate.breed)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.0f%%", estimate.confidence * 100))
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stress / Health Alerts

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !profile.stressIndicators.isEmpty {
                Label("Stress Indicators", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(.yellow)

                ForEach(profile.stressIndicators, id: \.self) { indicator in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.yellow)
                            .padding(.top, 5)
                        Text(indicator.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !profile.healthFlags.isEmpty {
                Label("Health Notes", systemImage: "heart.text.clipboard")
                    .font(.headline)
                    .foregroundStyle(.red.opacity(0.8))

                ForEach(profile.healthFlags, id: \.self) { flag in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.red.opacity(0.6))
                            .padding(.top, 5)
                        Text(flag.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("These are behavioral observations only — consider discussing with your vet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Agent Details

    private var agentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Agent Details", systemImage: "list.bullet.rectangle")
                .font(.headline)

            ForEach(profile.agentResults, id: \.agentId) { result in
                NavigationLink {
                    AgentDetailView(result: result)
                } label: {
                    HStack {
                        statusIcon(for: result.status)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.domain)
                                .font(.subheadline)
                            Text(result.status.rawValue.replacingOccurrences(of: "_", with: " "))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if result.confidence > 0 {
                            Text(String(format: "%.0f%%", result.confidence * 100))
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statusIcon(for status: AgentStatus) -> some View {
        Group {
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .notObservable:
                Image(systemName: "eye.slash.circle.fill")
                    .foregroundStyle(.secondary)
            case .timedOut:
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.yellow)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.body)
    }

    // MARK: - Metadata

    private var metadataFooter: some View {
        VStack(spacing: 4) {
            Text("Model: \(profile.modelName) • Version: \(profile.analysisVersion)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("Mode: \(profile.profileMode.capitalized) • \(profile.analyzedAt)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }
}
