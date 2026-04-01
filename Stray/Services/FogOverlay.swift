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
    private let heatColors = HeatGradient.colors()

    init(overlay: MKOverlay, gridEngine: GridEngine) {
        self.gridEngine = gridEngine
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let drawRect = rect(for: mapRect)
        let region = MKCoordinateRegion(mapRect)

        context.setShouldAntialias(false)
        context.setAllowsAntialiasing(false)

        let baseFogAlpha = Double(Constants.fogColor.cgColor.alpha)
        let latDelta = region.span.latitudeDelta
        let zoomFactor = min(latDelta / 6.0, 1.0)
        let fogAlpha = baseFogAlpha * (1.0 - zoomFactor * 0.25)

        let level = GridEngine.LODLevel.level(for: latDelta)

        if level == .base {
            drawBaseLevel(region: region, fogAlpha: fogAlpha, drawRect: drawRect, context: context)
        } else {
            drawAggregateLevel(region: region, level: level, fogAlpha: fogAlpha, drawRect: drawRect, context: context)
        }
    }

    // MARK: - Base Level (50m cells)

    private func drawBaseLevel(region: MKCoordinateRegion, fogAlpha: Double, drawRect: CGRect, context: CGContext) {
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

        // Build a single combined path for all cells (expanded slightly so
        // adjacent rects overlap — fillPath renders the union exactly once,
        // eliminating both sub-pixel gaps and double-compositing artifacts).
        let cellPath = CGMutablePath()
        for (cell, _) in cells {
            cellPath.addRect(cellScreenRect(for: cell).insetBy(dx: -0.5, dy: -0.5))
        }

        // Pass 1: Fog with clear cutouts (single fill — no seams)
        context.setFillColor(Constants.fogColor.withAlphaComponent(fogAlpha).cgColor)
        context.fill(drawRect)

        context.addPath(cellPath)
        context.setBlendMode(.clear)
        context.fillPath()
        context.setBlendMode(.normal)

        // Clearing animation
        let now = Date()
        let animationDuration: TimeInterval = 0.3
        for (cell, revealTime) in gridEngine.recentlyRevealedCells {
            let age = now.timeIntervalSince(revealTime)
            guard age < animationDuration else { continue }
            let progress = age / animationDuration
            let residualAlpha = (1.0 - progress) * fogAlpha
            let cellRect = cellScreenRect(for: cell)
            context.setFillColor(Constants.fogColor.withAlphaComponent(residualAlpha).cgColor)
            context.fill(cellRect)
        }

        // Pass 2: Default tint (single fill — no seams)
        context.addPath(cellPath)
        context.setFillColor(Constants.revealedCellTint.cgColor)
        context.fillPath()

        // Pass 3: Per-cell overrides for non-default tints
        drawCellTintOverrides(
            cells: cells,
            isHeatMode: gridEngine.heatCells,
            isPhotoMode: gridEngine.photoCells != nil,
            dayHighlight: gridEngine.dayHighlightCells,
            dayNew: gridEngine.dayNewCells,
            context: context
        )
        drawInspectionHighlight(cells: cells, context: context)
        drawPhotoCounts(
            region: region,
            isPhotoMode: gridEngine.photoCells != nil,
            isHeatMode: gridEngine.heatCells,
            context: context
        )
    }

    // MARK: - Aggregate LOD Level

    private func drawAggregateLevel(
        region: MKCoordinateRegion,
        level: GridEngine.LODLevel,
        fogAlpha: Double,
        drawRect: CGRect,
        context: CGContext
    ) {
        context.setFillColor(Constants.fogColor.withAlphaComponent(fogAlpha).cgColor)
        context.fill(drawRect)

        let aggregated = gridEngine.aggregatedCells(in: region, level: level)
        let isHeatMode = gridEngine.heatCells
        let isPhotoMode = gridEngine.photoCells != nil

        for (lodCell, coverage, _) in aggregated {
            let cellRect = lodCellScreenRect(for: lodCell)

            context.setBlendMode(.clear)
            context.fill(cellRect)
            context.setBlendMode(.normal)

            let tint: UIColor
            if isPhotoMode {
                let alpha = 0.20 + coverage * 0.25
                tint = Constants.photoDensityMedium.withAlphaComponent(alpha)
            } else if isHeatMode {
                tint = coverageHeatColor(coverage)
            } else {
                let alpha = 0.25 + coverage * 0.30
                tint = Constants.revealedCellTint.withAlphaComponent(alpha)
            }
            context.setFillColor(tint.cgColor)
            context.fill(cellRect)
        }

        // Count badges
        if isPhotoMode {
            drawAggregateBadges(aggregated: aggregated, style: .photo, context: context)
        }
    }

    // MARK: - LOD Count Badges

    private enum BadgeStyle {
        case photo

        var backgroundColor: UIColor {
            switch self {
            case .photo: return UIColor(red: 0.65, green: 0.25, blue: 0.90, alpha: 0.85)
            }
        }

        var textColor: UIColor { .white }
    }

    private func drawAggregateBadges(
        aggregated: [(GridEngine.LODCell, Double, Int)],
        style: BadgeStyle,
        context: CGContext
    ) {
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        for (lodCell, _, count) in aggregated {
            guard count > 0 else { continue }
            let cellRect = lodCellScreenRect(for: lodCell)

            let label = count >= 1000 ? "\(count / 1000)k" : "\(count)"
            let fontSize = max(min(cellRect.width * 0.18, 28), 10)
            let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: style.textColor
            ]
            let textSize = (label as NSString).size(withAttributes: attrs)
            let padH: CGFloat = fontSize * 0.4
            let padV: CGFloat = fontSize * 0.2
            let badgeSize = CGSize(
                width: textSize.width + padH * 2,
                height: textSize.height + padV * 2
            )
            let badgeOrigin = CGPoint(
                x: cellRect.midX - badgeSize.width / 2,
                y: cellRect.midY - badgeSize.height / 2
            )
            let badgeRect = CGRect(origin: badgeOrigin, size: badgeSize)
            let cornerRadius = badgeSize.height / 2

            let path = UIBezierPath(roundedRect: badgeRect, cornerRadius: cornerRadius)
            style.backgroundColor.setFill()
            path.fill()

            let textOrigin = CGPoint(
                x: badgeRect.midX - textSize.width / 2,
                y: badgeRect.midY - textSize.height / 2
            )
            (label as NSString).draw(at: textOrigin, withAttributes: attrs)
        }
    }

    // MARK: - Cell Tints (base level)

    private func drawCellTintOverrides(
        cells: [(GridCell, Int)],
        isHeatMode: Bool,
        isPhotoMode: Bool,
        dayHighlight: Set<GridCell>?,
        dayNew: Set<GridCell>?,
        context: CGContext
    ) {
        let todayCells = gridEngine.todayVisitedCells

        // Batch today cells into a single path (same fix as default tint)
        if !isPhotoMode && !isHeatMode {
            let todayPath = CGMutablePath()
            for (cell, _) in cells {
                guard todayCells.contains(cell) else { continue }
                guard gridEngine.specialTile(for: cell) == nil else { continue }
                todayPath.addRect(cellScreenRect(for: cell).insetBy(dx: -0.5, dy: -0.5))
            }
            if !todayPath.isEmpty {
                context.addPath(todayPath)
                context.setFillColor(UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 0.55).cgColor)
                context.fillPath()
            }
        }

        for (cell, count) in cells {
            let cellRect = cellScreenRect(for: cell)

            if isPhotoMode {
                if let tint = photoDensityColor(for: count) {
                    context.setFillColor(tint.cgColor)
                    context.fill(cellRect)
                }
            } else if isHeatMode {
                if let tint = heatColor(for: count) {
                    context.setFillColor(tint.cgColor)
                    context.fill(cellRect)
                }
            } else if let special = gridEngine.specialTile(for: cell),
               let specialColor = UIColor(hex: special.colorHex) {
                context.setFillColor(specialColor.withAlphaComponent(Constants.specialTileAlpha).cgColor)
                context.fill(cellRect)
            }

        }

        // Batch day highlight fills into paths to avoid gridline artifacts
        if let dayHighlight {
            let newPath = CGMutablePath()
            let existingPath = CGMutablePath()
            let dimPath = CGMutablePath()
            for (cell, _) in cells {
                let expandedRect = cellScreenRect(for: cell).insetBy(dx: -0.5, dy: -0.5)
                if dayHighlight.contains(cell) {
                    let isNew = dayNew?.contains(cell) ?? false
                    if isNew {
                        newPath.addRect(expandedRect)
                    } else {
                        existingPath.addRect(expandedRect)
                    }
                } else {
                    dimPath.addRect(expandedRect)
                }
            }
            if !dimPath.isEmpty {
                context.addPath(dimPath)
                context.setFillColor(Constants.fogColor.withAlphaComponent(0.5).cgColor)
                context.fillPath()
            }
            if !existingPath.isEmpty {
                context.addPath(existingPath)
                context.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
                context.fillPath()
            }
            if !newPath.isEmpty {
                context.addPath(newPath)
                context.setFillColor(UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 0.45).cgColor)
                context.fillPath()
            }
        }
    }

    private func drawInspectionHighlight(cells: [(GridCell, Int)], context: CGContext) {
        guard let inspected = gridEngine.inspectedCell else { return }
        for (cell, _) in cells where cell == inspected {
            let cellRect = cellScreenRect(for: cell)
            context.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            context.fill(cellRect)
        }
    }

    private func drawPhotoCounts(
        region: MKCoordinateRegion,
        isPhotoMode: Bool,
        isHeatMode: Bool,
        context: CGContext
    ) {
        guard !isPhotoMode, !isHeatMode, let photoDots = gridEngine.photoDotsData else { return }
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

    // MARK: - Heat Coverage Color (LOD only, when heat mode is on)

    private func coverageHeatColor(_ coverage: Double) -> UIColor {
        guard !heatColors.isEmpty else { return Constants.revealedCellTint }

        let position = min(1.0, max(0.0, coverage))
        let index = position * Double(heatColors.count - 1)
        let lower = Int(floor(index))
        let upper = min(lower + 1, heatColors.count - 1)
        let fraction = CGFloat(index - Double(lower))

        let c1 = heatColors[lower]
        let c2 = heatColors[upper]

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let alpha: CGFloat = 0.35 + CGFloat(position) * 0.30

        return UIColor(
            red: r1 + (r2 - r1) * fraction,
            green: g1 + (g2 - g1) * fraction,
            blue: b1 + (b2 - b1) * fraction,
            alpha: alpha
        )
    }

    // MARK: - Geometry Helpers

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

    private func lodCellScreenRect(for lodCell: GridEngine.LODCell) -> CGRect {
        let sw = lodCell.coordinate
        let step = lodCell.degreeStep
        let neLat = sw.latitude + step
        let neLng = sw.longitude + step

        let swPoint = MKMapPoint(CLLocationCoordinate2D(latitude: sw.latitude, longitude: sw.longitude))
        let nePoint = MKMapPoint(CLLocationCoordinate2D(latitude: neLat, longitude: neLng))

        let cellMapRect = MKMapRect(
            x: min(swPoint.x, nePoint.x),
            y: min(swPoint.y, nePoint.y),
            width: abs(nePoint.x - swPoint.x),
            height: abs(nePoint.y - swPoint.y)
        )

        return rect(for: cellMapRect).integral
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
        guard !heatColors.isEmpty else { return nil }
        switch visitCount {
        case 0: return nil
        case 1: return heatColors[0]
        case 2: return heatColors.count > 1 ? heatColors[1] : heatColors[0]
        case 3...5: return heatColors.count > 2 ? heatColors[2] : heatColors.last
        case 6...20: return heatColors.count > 3 ? heatColors[3] : heatColors.last
        default: return heatColors.count > 4 ? heatColors[4] : heatColors.last
        }
    }
}
