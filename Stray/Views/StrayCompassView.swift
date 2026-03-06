import SwiftUI

struct StrayCompassView: View {
    let bearing: Double
    let hasTarget: Bool
    let noTargetMessage: String?
    let distanceToTarget: Double?

    var body: some View {
        VStack(spacing: 4) {
            if hasTarget {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .rotationEffect(.degrees(bearing))
                    .animation(.easeInOut(duration: 0.5), value: bearing)
                    .accessibilityLabel("Compass pointing \(cardinalDirection(from: bearing))")
                if let dist = distanceToTarget {
                    Text(formatDistanceShort(dist))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                }
            } else if let message = noTargetMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private func formatDistanceShort(_ meters: Double) -> String {
        let useMetric = Locale.current.measurementSystem == .metric
        if useMetric {
            return meters < 1000 ? "~\(Int(meters))m" : String(format: "~%.1f km", meters / 1000)
        } else {
            let feet = meters * 3.28084
            return feet < 528 ? "~\(Int(feet)) ft" : String(format: "~%.1f mi", meters / 1609.34)
        }
    }

    private func cardinalDirection(from degrees: Double) -> String {
        let normalized = ((degrees.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let directions = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        let index = Int((normalized + 22.5) / 45.0) % 8
        return directions[index]
    }
}
