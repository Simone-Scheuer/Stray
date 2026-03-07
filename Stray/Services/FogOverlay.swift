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
        let revealedSet = Set(cells.map { $0.0 })

        for (cell, count) in cells {
            let cellRect = cellScreenRect(for: cell)

            // Punch hole in fog
            context.setBlendMode(.clear)
            context.fill(cellRect)

            // Photo mode uses purple density gradient; normal mode uses heat + special tiles
            if gridEngine.photoCells != nil {
                if let tint = photoDensityColor(for: count) {
                    context.setBlendMode(.normal)
                    context.setFillColor(tint.cgColor)
                    context.fill(cellRect)
                }
            } else if let special = gridEngine.specialTile(for: cell),
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

            if gridEngine.inspectedCell == cell {
                context.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
                context.fill(cellRect)
            }
        }

        // Soft fog edges: draw gradient strips on edges that border unrevealed cells
        drawFogEdgeGradients(cells: cells, revealedSet: revealedSet, in: context)

        // Cell clearing animation: recently revealed cells show residual fog that fades out
        let now = Date()
        let animationDuration: TimeInterval = 0.3
        for (cell, revealTime) in gridEngine.recentlyRevealedCells {
            let age = now.timeIntervalSince(revealTime)
            guard age < animationDuration else { continue }
            let progress = age / animationDuration
            let fogAlpha = (1.0 - progress) * Double(Constants.fogColor.cgColor.alpha)
            let cellRect = cellScreenRect(for: cell)
            context.setFillColor(Constants.fogColor.withAlphaComponent(fogAlpha).cgColor)
            context.fill(cellRect)
        }
    }

    private func cellScreenRect(for cell: GridCell) -> CGRect {
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

        return rect(for: cellMapRect)
    }

    private func drawFogEdgeGradients(cells: [(GridCell, Int)], revealedSet: Set<GridCell>, in context: CGContext) {
        let fogCG = Constants.fogColor.cgColor
        let clearFog = Constants.fogColor.withAlphaComponent(0).cgColor
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [clearFog, fogCG] as CFArray,
            locations: [0.0, 1.0]
        ) else { return }

        for (cell, _) in cells {
            let cellRect = cellScreenRect(for: cell)
            let feather = min(cellRect.width, cellRect.height) * 0.2

            let neighbors = cell.neighbors
            // North edge (top of screen = min Y in CG, but MKMapPoint Y increases going north = decreasing screen Y)
            if !revealedSet.contains(neighbors.north) {
                context.saveGState()
                context.clip(to: CGRect(x: cellRect.minX, y: cellRect.minY, width: cellRect.width, height: feather))
                context.drawLinearGradient(gradient, start: CGPoint(x: cellRect.midX, y: cellRect.minY + feather), end: CGPoint(x: cellRect.midX, y: cellRect.minY), options: [])
                context.restoreGState()
            }
            // South edge
            if !revealedSet.contains(neighbors.south) {
                context.saveGState()
                context.clip(to: CGRect(x: cellRect.minX, y: cellRect.maxY - feather, width: cellRect.width, height: feather))
                context.drawLinearGradient(gradient, start: CGPoint(x: cellRect.midX, y: cellRect.maxY - feather), end: CGPoint(x: cellRect.midX, y: cellRect.maxY), options: [])
                context.restoreGState()
            }
            // West edge
            if !revealedSet.contains(neighbors.west) {
                context.saveGState()
                context.clip(to: CGRect(x: cellRect.minX, y: cellRect.minY, width: feather, height: cellRect.height))
                context.drawLinearGradient(gradient, start: CGPoint(x: cellRect.minX + feather, y: cellRect.midY), end: CGPoint(x: cellRect.minX, y: cellRect.midY), options: [])
                context.restoreGState()
            }
            // East edge
            if !revealedSet.contains(neighbors.east) {
                context.saveGState()
                context.clip(to: CGRect(x: cellRect.maxX - feather, y: cellRect.minY, width: feather, height: cellRect.height))
                context.drawLinearGradient(gradient, start: CGPoint(x: cellRect.maxX - feather, y: cellRect.midY), end: CGPoint(x: cellRect.maxX, y: cellRect.midY), options: [])
                context.restoreGState()
            }
        }
    }

    private func photoDensityColor(for photoCount: Int) -> UIColor? {
        switch photoCount {
        case 0: return nil
        case 1: return Constants.photoDensityFaint
        case 2...4: return Constants.photoDensityMedium
        case 5...9: return Constants.photoDensityBright
        default: return Constants.photoDensityVivid
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
