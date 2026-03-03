import CoreLocation

struct GridCell: Hashable, Codable, Sendable, Identifiable {
    var id: String { key }
    let latIndex: Int
    let lngIndex: Int

    // ~50m in latitude degrees (1 degree latitude ≈ 111,320m everywhere)
    static let latStep: Double = 50.0 / 111_320.0

    // ~50m in longitude degrees (shrinks toward the poles)
    static func lngStep(atLatitude latitude: Double) -> Double {
        50.0 / (111_320.0 * cos(latitude * .pi / 180.0))
    }

    static func from(latitude: Double, longitude: Double) -> GridCell {
        let latIdx = Int(floor(latitude / latStep))
        let lngStp = lngStep(atLatitude: latitude)
        let lngIdx = Int(floor(longitude / lngStp))
        return GridCell(latIndex: latIdx, lngIndex: lngIdx)
    }

    /// Returns the coordinate of the cell's south-west corner.
    var coordinate: CLLocationCoordinate2D {
        let lat = Double(latIndex) * Self.latStep
        let lng = Double(lngIndex) * Self.lngStep(atLatitude: lat)
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Center of this grid cell (not SW corner)
    var centerCoordinate: CLLocationCoordinate2D {
        let lat = Double(latIndex) * Self.latStep + Self.latStep / 2.0
        let lng = Double(lngIndex) * Self.lngStep(atLatitude: lat) + Self.lngStep(atLatitude: lat) / 2.0
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var key: String { "\(latIndex)_\(lngIndex)" }
}
