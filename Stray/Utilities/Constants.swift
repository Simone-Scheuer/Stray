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

    // Heat gradient — 5 tiers, interpolated in HSB between two endpoints
    // Default: deep blue → bright green
    // Colorblind: deep blue → warm yellow
    static let heatTiers = 5
    static let heatAlphaRange: (low: CGFloat, high: CGFloat) = (0.40, 0.55)

    // Default gradient: blue (H=215°) → green (H=145°)
    static let defaultGradientStart = HSBColor(h: 215, s: 0.65, b: 0.70)
    static let defaultGradientEnd = HSBColor(h: 145, s: 0.60, b: 0.80)

    // Colorblind-safe gradient: blue (H=215°) → yellow (H=45°)
    static let colorblindGradientStart = HSBColor(h: 215, s: 0.65, b: 0.70)
    static let colorblindGradientEnd = HSBColor(h: 45, s: 0.70, b: 0.90)

    static let colorblindModeKey = "colorblindMode"

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
    static let maxDistanceDeltaMeters: Double = 100.0
    static let maxSpeedMetersPerSecond: Double = 6.0
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
    static let mapStyleKey = "mapStyle"

    // Photo density gradient colors (purple/magenta spectrum)
    static let photoDensityFaint = UIColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 0.30)
    static let photoDensityMedium = UIColor(red: 0.65, green: 0.25, blue: 0.90, alpha: 0.40)
    static let photoDensityBright = UIColor(red: 0.85, green: 0.20, blue: 0.75, alpha: 0.45)
    static let photoDensityVivid = UIColor(red: 1.00, green: 0.30, blue: 0.65, alpha: 0.55)
}

// MARK: - Heat Gradient

struct HSBColor {
    let h: CGFloat // 0-360
    let s: CGFloat // 0-1
    let b: CGFloat // 0-1
}

/// Pre-computed heat gradient colors for fast lookup in the renderer.
/// Call `HeatGradient.colors(colorblind:)` to get the 5-tier array.
enum HeatGradient {
    /// Returns 5 UIColors interpolated between the gradient endpoints.
    /// Index 0 = tier 1 (1 visit), index 4 = tier 5 (21+ visits).
    static func colors(colorblind: Bool) -> [UIColor] {
        let start = colorblind ? Constants.colorblindGradientStart : Constants.defaultGradientStart
        let end = colorblind ? Constants.colorblindGradientEnd : Constants.defaultGradientEnd
        let n = Constants.heatTiers
        let (alphaLow, alphaHigh) = Constants.heatAlphaRange

        return (0..<n).map { i in
            let t = n == 1 ? 0.0 : CGFloat(i) / CGFloat(n - 1)
            let h = lerp(start.h, end.h, t) / 360.0
            let s = lerp(start.s, end.s, t)
            let b = lerp(start.b, end.b, t)
            let alpha = lerp(alphaLow, alphaHigh, t)
            return UIColor(hue: h, saturation: s, brightness: b, alpha: alpha)
        }
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}
