import UIKit
import CoreLocation

enum Constants {
    static let gridCellSizeMeters: Double = 50.0
    static let searchRadiusMeters: Double = 500.0

    static let fogColor = UIColor(white: 0.06, alpha: 0.93)

    static let bootRevealRadius: Int = 1
    static let tileReloadThrottleSeconds: Double = 1.0

    // Cooldown before a cell's visit count increments again (1 hour)
    static let visitCooldownSeconds: TimeInterval = 3600.0

    // Heat gradient colors — distinct at low counts, banded at high counts
    static let heatTeal = UIColor(red: 0.2, green: 0.6, blue: 0.7, alpha: 0.40)           // 1 visit — first footprint
    static let heatSlateBlue = UIColor(red: 0.3, green: 0.45, blue: 0.8, alpha: 0.40)     // 2 visits
    static let heatIndigo = UIColor(red: 0.4, green: 0.35, blue: 0.75, alpha: 0.40)       // 3 visits
    static let heatLavender = UIColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 0.38)       // 4-5 visits
    static let heatWarmNeutral = UIColor(red: 0.6, green: 0.5, blue: 0.4, alpha: 0.38)    // 6-10 visits
    static let heatAmber = UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 0.42)          // 11-20 visits
    static let heatDeepOrange = UIColor(red: 0.95, green: 0.45, blue: 0.15, alpha: 0.45)  // 21-50 visits
    static let heatGoldenGlow = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.50)    // 51+ visits

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
    static let mapStyleKey = "mapStyle" // "satellite" (default), "standard", "hybrid"

    // Photo density gradient colors (purple/magenta spectrum)
    static let photoDensityFaint = UIColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 0.30)    // 1 photo
    static let photoDensityMedium = UIColor(red: 0.65, green: 0.25, blue: 0.90, alpha: 0.40)   // 2-4 photos
    static let photoDensityBright = UIColor(red: 0.85, green: 0.20, blue: 0.75, alpha: 0.45)   // 5-9 photos
    static let photoDensityVivid = UIColor(red: 1.00, green: 0.30, blue: 0.65, alpha: 0.55)    // 10+ photos
}
