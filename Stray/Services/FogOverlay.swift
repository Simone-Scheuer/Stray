import MapKit
import UIKit

// MARK: - Overlay Data Object

final class FogOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    var boundingMapRect: MKMapRect { MKMapRect.world }
}

// MARK: - Overlay Renderer

final class FogOverlayRenderer: MKOverlayRenderer {
    let gridEngine: GridEngine

    init(overlay: MKOverlay, gridEngine: GridEngine) {
        self.gridEngine = gridEngine
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let drawRect = rect(for: mapRect)

        // Fill entire draw rect with fog
        context.setFillColor(Constants.fogColor.cgColor)
        context.fill(drawRect)

        // Convert mapRect to coordinate region for spatial query
        let region = MKCoordinateRegion(mapRect)

        // At very low zoom, individual 50m cells are invisible — skip the query
        if region.span.latitudeDelta > 1.0 {
            return
        }

        // Pad query region by 2 cell widths to catch cells straddling edges
        let cellPadLat = GridCell.latStep * 2
        let cellPadLng = GridCell.lngStep(atLatitude: region.center.latitude) * 2
        let paddedRegion = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta + cellPadLat,
                longitudeDelta: region.span.longitudeDelta + cellPadLng
            )
        )

        let cells = gridEngine.cellsWithCounts(in: paddedRegion)

        for (cell, count) in cells {
            let sw = cell.coordinate
            let neLat = sw.latitude + GridCell.latStep
            let neLng = sw.longitude + GridCell.lngStep(atLatitude: sw.latitude)

            let swPoint = MKMapPoint(CLLocationCoordinate2D(latitude: sw.latitude, longitude: sw.longitude))
            let nePoint = MKMapPoint(CLLocationCoordinate2D(latitude: neLat, longitude: neLng))

            let cellMapRect = MKMapRect(
                x: min(swPoint.x, nePoint.x),
                y: min(swPoint.y, nePoint.y),
                width: abs(nePoint.x - swPoint.x),
                height: abs(nePoint.y - swPoint.y)
            )

            let cellRect = rect(for: cellMapRect)

            // Punch hole in fog
            context.setBlendMode(.clear)
            context.fill(cellRect)

            // Special tile color overrides heat gradient
            if let special = gridEngine.specialTile(for: cell),
               let specialColor = UIColor(hex: special.colorHex) {
                context.setBlendMode(.normal)
                context.setFillColor(specialColor.withAlphaComponent(Constants.specialTileAlpha).cgColor)
                context.fill(cellRect)
            } else if let tint = heatColor(for: count) {
                context.setBlendMode(.normal)
                context.setFillColor(tint.cgColor)
                context.fill(cellRect)
            }
            context.setBlendMode(.normal)
        }
    }

    private func heatColor(for visitCount: Int) -> UIColor? {
        switch visitCount {
        case 0: return nil
        case 1: return Constants.heatCoolBlue
        case 2...4: return Constants.heatLightBlue
        case 5...9: return Constants.heatNeutral
        case 10...29: return Constants.heatWarmAmber
        default: return Constants.heatBrightGlow
        }
    }
}
