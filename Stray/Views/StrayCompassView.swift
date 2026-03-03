import SwiftUI

struct StrayCompassView: View {
    let bearing: Double
    let hasTarget: Bool
    let noTargetMessage: String?

    var body: some View {
        VStack {
            if hasTarget {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .rotationEffect(.degrees(bearing))
                    .animation(.easeInOut(duration: 0.5), value: bearing)
                    .accessibilityLabel("Compass pointing \(cardinalDirection(from: bearing))")
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

    private func cardinalDirection(from degrees: Double) -> String {
        let normalized = ((degrees.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let directions = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        let index = Int((normalized + 22.5) / 45.0) % 8
        return directions[index]
    }
}
