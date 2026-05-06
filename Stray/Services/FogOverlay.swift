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

        for (lodCell, coverage, cellCount, valueSum) in aggregated {
            let cellRect = lodCellScreenRect(for: lodCell)

            context.setBlendMode(.clear)
            context.fill(cellRect)
            context.setBlendMode(.normal)

            if isPhotoMode {
                let alpha = 0.20 + coverage * 0.25
                context.setFillColor(Constants.photoDensityMedium.withAlphaComponent(alpha).cgColor)
                context.fill(cellRect)
            } else if isHeatMode {
                // Base layer: default revealedCellTint forms the thin per-cell border at LOD,
                // mirroring base-zoom behavior where heat tints overlay the default fill.
                let baseAlpha = 0.25 + coverage * 0.30
                context.setFillColor(Constants.revealedCellTint.withAlphaComponent(baseAlpha).cgColor)
                context.fill(cellRect)

                // Heat overlay at slightly-inset rect so the base shows as a thin border.
                // Color keyed off avg visits in this LOD region (NOT coverage — they're independent).
                let avgVisits = cellCount > 0 ? Int(round(Double(valueSum) / Double(cellCount))) : 0
                if let heat = heatColor(for: avgVisits) {
                    context.setFillColor(heat.cgColor)
                    context.fill(cellRect.insetBy(dx: 0.5, dy: 0.5))
                }
            } else {
                let alpha = 0.25 + coverage * 0.30
                context.setFillColor(Constants.revealedCellTint.withAlphaComponent(alpha).cgColor)
                context.fill(cellRect)
            }
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
                context.setFillColor(UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 0.28).cgColor)
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
