import CoreLocation
import SwiftUI
import UIKit

// MARK: - Environment Keys for Service Injection

private struct GridEngineKey: EnvironmentKey {
    static let defaultValue = GridEngine()
}

private struct LocationServiceKey: EnvironmentKey {
    static let defaultValue = LocationService()
}

private struct PersistenceServiceKey: EnvironmentKey {
    static var defaultValue: PersistenceService? { nil }
}

private struct StraySessionViewModelKey: EnvironmentKey {
    static var defaultValue: StraySessionViewModel? { nil }
}

private struct PhotoServiceKey: EnvironmentKey {
    @MainActor static let defaultValue = PhotoService()
}
// Silence Swift 6 warning — EnvironmentKey.defaultValue is accessed on MainActor in practice
extension PhotoServiceKey: @unchecked Sendable {}

private struct StatsViewModelKey: EnvironmentKey {
    static let defaultValue = StatsViewModel()
}

extension EnvironmentValues {
    var gridEngine: GridEngine {
        get { self[GridEngineKey.self] }
        set { self[GridEngineKey.self] = newValue }
    }

    var locationService: LocationService {
        get { self[LocationServiceKey.self] }
        set { self[LocationServiceKey.self] = newValue }
    }

    var persistenceService: PersistenceService? {
        get { self[PersistenceServiceKey.self] }
        set { self[PersistenceServiceKey.self] = newValue }
    }

    var straySessionViewModel: StraySessionViewModel? {
        get { self[StraySessionViewModelKey.self] }
        set { self[StraySessionViewModelKey.self] = newValue }
    }

    var photoService: PhotoService {
        get { self[PhotoServiceKey.self] }
        set { self[PhotoServiceKey.self] = newValue }
    }

    var statsViewModel: StatsViewModel {
        get { self[StatsViewModelKey.self] }
        set { self[StatsViewModelKey.self] = newValue }
    }
}

// MARK: - Locale-Aware Distance Formatting

func formatDistance(_ meters: Double) -> String {
    let useMetric = Locale.current.measurementSystem == .metric
    if useMetric {
        let km = meters / 1000.0
        if km < 0.1 { return "0 km" }
        return String(format: "%.1f km", km)
    } else {
        let miles = meters / 1609.34
        if miles < 0.1 { return "0 mi" }
        return String(format: "%.1f mi", miles)
    }
}

// MARK: - UIColor Hex Parsing

extension UIColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        guard hexString.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgb) else { return nil }
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - CLLocationCoordinate2D Helpers

extension CLLocationCoordinate2D {

    /// Returns the great-circle distance in meters using the Haversine formula.
    func distance(to other: CLLocationCoordinate2D) -> Double {
        let earthRadiusMeters: Double = 6_371_000.0

        let lat1 = latitude * .pi / 180.0
        let lat2 = other.latitude * .pi / 180.0
        let dLat = (other.latitude - latitude) * .pi / 180.0
        let dLng = (other.longitude - longitude) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusMeters * c
    }

    /// Returns the initial geographic bearing (0-360 degrees, clockwise from north) toward `other`.
    func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude * .pi / 180.0
        let lat2 = other.latitude * .pi / 180.0
        let dLng = (other.longitude - longitude) * .pi / 180.0

        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)

        let radians = atan2(y, x)
        // Normalize from [-pi, pi] to [0, 360)
        return (radians * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
}
