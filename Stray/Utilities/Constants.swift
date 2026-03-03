import UIKit
import CoreLocation

enum Constants {
    static let gridCellSizeMeters: Double = 50.0
    static let searchRadiusMeters: Double = 500.0

    static let fogColor = UIColor(white: 0.06, alpha: 0.93)

    static let bootRevealRadius: Int = 1
    static let tileReloadThrottleSeconds: Double = 1.0

    // Cooldown before a cell's visit count increments again (30 minutes)
    static let visitCooldownSeconds: TimeInterval = 1800.0

    // Heat gradient colors — smooth ramp from cool to warm
    static let heatCoolBlue = UIColor(red: 0.3, green: 0.45, blue: 0.85, alpha: 0.22)     // 1 visit
    static let heatLightBlue = UIColor(red: 0.35, green: 0.5, blue: 0.75, alpha: 0.15)    // 2-4 visits
    static let heatNeutral = UIColor(red: 0.55, green: 0.5, blue: 0.45, alpha: 0.10)      // 5-9 visits
    static let heatWarmAmber = UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 0.18)      // 10-29 visits
    static let heatBrightGlow = UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.25)     // 30+ visits

    static let passiveAccuracyThreshold: CLLocationAccuracy = 100.0
    static let activeAccuracyThreshold: CLLocationAccuracy = 50.0
    static let lowPowerAccuracyThreshold: CLLocationAccuracy = 150.0
    static let averageStrideLengthMeters: Double = 0.7
    static let minimumDistanceBetweenUpdatesMeters: Double = 5.0
    static let geocodeRateLimitPerMinute: Int = 40
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    static let hasPromptedAlwaysLocationKey = "hasPromptedAlwaysLocation"
    static let showMapLabelsKey = "showMapLabels"
}
