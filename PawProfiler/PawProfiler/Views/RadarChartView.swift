import SwiftUI

/// Feline-Five radar chart with 5 axes using SwiftUI paths.
struct RadarChartView: View {
    let scores: FelineFiveScores
    let size: CGFloat

    private let labels = ["N", "E", "D", "I", "A"]
    private let fullLabels = FelineFiveScores.traitLabels
    private let axisCount = 5

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background grid
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    radarPath(values: Array(repeating: level, count: axisCount))
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                }

                // Axis lines
                ForEach(0..<axisCount, id: \.self) { i in
                    let point = pointOnCircle(index: i, value: 1.0)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point)
                    }
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                }

                // Data polygon
                radarPath(values: scores.allScores)
                    .fill(Color.orange.opacity(0.2))

                radarPath(values: scores.allScores)
                    .stroke(Color.orange, lineWidth: 2)

                // Data points
                ForEach(0..<axisCount, id: \.self) { i in
                    let point = pointOnCircle(index: i, value: scores.allScores[i])
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .position(point)
                }

                // Labels
                ForEach(0..<axisCount, id: \.self) { i in
                    let labelPoint = pointOnCircle(index: i, value: 1.18)
                    Text(labels[i])
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .position(labelPoint)
                }
            }
            .frame(width: size, height: size)

            // Legend
            HStack(spacing: 12) {
                ForEach(0..<axisCount, id: \.self) { i in
                    VStack(spacing: 2) {
                        Text(labels[i])
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                        Text(String(format: "%.0f%%", scores.allScores[i] * 100))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Geometry

    private var center: CGPoint {
        CGPoint(x: size / 2, y: size / 2)
    }

    private var radius: CGFloat {
        size / 2 * 0.75
    }

    private func pointOnCircle(index: Int, value: Double) -> CGPoint {
        let angle = (2 * .pi / Double(axisCount)) * Double(index) - .pi / 2
        let r = radius * CGFloat(value)
        return CGPoint(
            x: center.x + r * CGFloat(cos(angle)),
            y: center.y + r * CGFloat(sin(angle))
        )
    }

    private func radarPath(values: [Double]) -> Path {
        Path { path in
            for (i, value) in values.enumerated() {
                let point = pointOnCircle(index: i, value: value)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
    }
}
