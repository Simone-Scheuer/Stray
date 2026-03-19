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
    private var heatColors: [UIColor]

    init(overlay: MKOverlay, gridEngine: GridEngine, colorblind: Bool = false) {
        self.gridEngine = gridEngine
        self.heatColors = HeatGradient.colors(colorblind: colorblind)
        super.init(overlay: overlay)
    }

    func updateColorblindMode(_ colorblind: Bool) {
        heatColors = HeatGradient.colors(colorblind: colorblind)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let drawRect = rect(for: mapRect)
        let region = MKCoordinateRegion(mapRect)

        let baseFogAlpha = Double(Constants.fogColor.cgColor.alpha)
        let logScale = log10(max(Double(zoomScale), 1e-6))
        let fogMultiplier = min(1.0, max(0.3, (logScale + 4.5) / 3.0))
        let fogAlpha = baseFogAlpha * fogMultiplier

        context.setFillColor(Constants.fogColor.withAlphaComponent(fogAlpha).cgColor)
        context.fill(drawRect)

        if region.span.latitudeDelta > 1.0 {
            return
        }

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
        let isHeatMode = gridEngine.heatCells
        let isPhotoMode = gridEngine.photoCells != nil

        for (cell, count) in cells {
            let cellRect = cellScreenRect(for: cell)

            // Punch hole in fog
            context.setBlendMode(.clear)
            context.fill(cellRect)

            // Apply tint only in a visualization mode, or for special tiles
            if isPhotoMode {
                if let tint = photoDensityColor(for: count) {
                    context.setBlendMode(.normal)
                    context.setFillColor(tint.cgColor)
                    context.fill(cellRect)
                }
            } else if isHeatMode {
                if let tint = heatColor(for: count) {
                    context.setBlendMode(.normal)
                    context.setFillColor(tint.cgColor)
                    context.fill(cellRect)
                }
            } else if let special = gridEngine.specialTile(for: cell),
               let specialColor = UIColor(hex: special.colorHex) {
                context.setBlendMode(.normal)
                context.setFillColor(specialColor.withAlphaComponent(Constants.specialTileAlpha).cgColor)
                context.fill(cellRect)
            } else {
                // Default mode: subtle pale blue wash on revealed cells
                context.setBlendMode(.normal)
                context.setFillColor(Constants.revealedCellTint.cgColor)
                context.fill(cellRect)
            }
            context.setBlendMode(.normal)

            if gridEngine.inspectedCell == cell {
                context.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
                context.fill(cellRect)
            }
        }

        // Cell clearing animation
        let now = Date()
        let animationDuration: TimeInterval = 0.3
        for (cell, revealTime) in gridEngine.recentlyRevealedCells {
            let age = now.timeIntervalSince(revealTime)
            guard age < animationDuration else { continue }
            let progress = age / animationDuration
            let residualAlpha = (1.0 - progress) * Double(Constants.fogColor.cgColor.alpha)
            let cellRect = cellScreenRect(for: cell)
            context.setFillColor(Constants.fogColor.withAlphaComponent(residualAlpha).cgColor)
            context.fill(cellRect)
        }

        // Photo count numbers
        if !isPhotoMode, !isHeatMode, let photoDots = gridEngine.photoDotsData {
            context.setBlendMode(.normal)
            for (cell, photoCount) in photoDots {
                let coord = cell.coordinate
                guard coord.latitude >= region.center.latitude - region.span.latitudeDelta
                        && coord.latitude <= region.center.latitude + region.span.latitudeDelta
                        && coord.longitude >= region.center.longitude - region.span.longitudeDelta
                        && coord.longitude <= region.center.longitude + region.span.longitudeDelta else {
                    continue
                }
                let cellRect = cellScreenRect(for: cell)
                let fontSize = max(cellRect.width * 0.22, 6)
                guard fontSize >= 6 else { continue }
                let text = "\(photoCount)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.55)
                ]
                let textSize = text.size(withAttributes: attrs)
                let textOrigin = CGPoint(
                    x: cellRect.maxX - textSize.width - cellRect.width * 0.06,
                    y: cellRect.maxY - textSize.height - cellRect.height * 0.04
                )
                UIGraphicsPushContext(context)
                text.draw(at: textOrigin, withAttributes: attrs)
                UIGraphicsPopContext()
            }
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

        return rect(for: cellMapRect).insetBy(dx: -0.5, dy: -0.5)
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
        case 1: return heatColors[0]
        case 2: return heatColors[1]
        case 3...5: return heatColors[2]
        case 6...20: return heatColors[3]
        default: return heatColors[4]
        }
    }
}
