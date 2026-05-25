import SwiftUI

/// Shows agent analysis progress: "Agent 3/6: Stress & Welfare…"
struct AgentProgressView: View {
    let currentAgent: Int
    let totalAgents: Int
    let agentName: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)

            Text("Analyzing…")
                .font(.title2.bold())

            Text("Agent \(currentAgent)/\(totalAgents): \(agentName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(currentAgent), total: Double(totalAgents))
                .tint(.orange)
                .padding(.horizontal, 40)

            Text("\(Int((Double(currentAgent) / Double(totalAgents)) * 100))%")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

/// Progress indicator for non-agent pipeline stages.
struct PipelineStageView: View {
    let stage: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)

            Text(stage)
                .font(.title3)
                .foregroundStyle(.secondary)

            ProgressView()
                .tint(.orange)
        }
        .padding()
    }
}
