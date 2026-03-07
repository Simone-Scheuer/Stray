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
    static let heatCoolBlue = UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.45)       // 1 visit
    static let heatLightBlue = UIColor(red: 0.35, green: 0.55, blue: 0.8, alpha: 0.38)    // 2-4 visits
    static let heatNeutral = UIColor(red: 0.55, green: 0.5, blue: 0.45, alpha: 0.30)      // 5-9 visits
    static let heatWarmAmber = UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 0.40)      // 10-29 visits
    static let heatBrightGlow = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.50)    // 30+ visits

    // Special tile presets
    static let specialTilePresets: [(label: String, icon: String, colorHex: String)] = [
        ("Home", "house.fill", "#4CAF50"),
        ("Work", "briefcase.fill", "#7B68EE"),
        ("Favorite", "star.fill", "#FFD700"),
    ]
    static let specialTileAlpha: CGFloat = 0.55

    static let passiveAccuracyThreshold: CLLocationAccuracy = 100.0
    static let activeAccuracyThreshold: CLLocationAccuracy = 50.0
    static let lowPowerAccuracyThreshold: CLLocationAccuracy = 150.0
    static let averageStrideLengthMeters: Double = 0.7
    static let minimumDistanceBetweenUpdatesMeters: Double = 5.0
    // Reject GPS deltas above this — implies a position jump, not actual movement
    static let maxDistanceDeltaMeters: Double = 100.0
    // Reject if implied speed exceeds this (6 m/s ≈ 13 mph, fast running)
    static let maxSpeedMetersPerSecond: Double = 6.0
    // Reset reference point after this long without an accepted distance (handles background gaps)
    static let staleReferenceTimeoutSeconds: TimeInterval = 120.0
    static let geocodeRateLimitPerMinute: Int = 40
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    static let hasPromptedAlwaysLocationKey = "hasPromptedAlwaysLocation"
    static let showMapLabelsKey = "showMapLabels"
    static let mutedMapStyleKey = "mutedMapStyle"
    static let showTrafficKey = "showTraffic"
    static let allowRotationKey = "allowRotation"
    static let hasCompletedPhotoScanKey = "hasCompletedPhotoScan"
    static let showPhotoDotsKey = "showPhotoDots"

    // Photo density gradient colors (purple/magenta spectrum)
    static let photoDensityFaint = UIColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 0.30)    // 1 photo
    static let photoDensityMedium = UIColor(red: 0.65, green: 0.25, blue: 0.90, alpha: 0.40)   // 2-4 photos
    static let photoDensityBright = UIColor(red: 0.85, green: 0.20, blue: 0.75, alpha: 0.45)   // 5-9 photos
    static let photoDensityVivid = UIColor(red: 1.00, green: 0.30, blue: 0.65, alpha: 0.55)    // 10+ photos
}
