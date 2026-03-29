import MapKit
import UIKit
import Accelerate

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

    private var cachedFogImage: CGImage?
    private var cachedGeneration: Int = -1
    private var cachedMapRect: MKMapRect = .null

    init(overlay: MKOverlay, gridEngine: GridEngine) {
        self.gridEngine = gridEngine
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let drawRect = rect(for: mapRect)
        let region = MKCoordinateRegion(mapRect)

        let baseFogAlpha = Double(Constants.fogColor.cgColor.alpha)
        let logScale = log10(max(Double(zoomScale), 1e-6))
        let fogMultiplier = min(1.0, max(0.3, (logScale + 4.5) / 3.0))
        let fogAlpha = baseFogAlpha * fogMultiplier

        if region.span.latitudeDelta > 1.0 {
            context.setFillColor(Constants.fogColor.withAlphaComponent(fogAlpha).cgColor)
            context.fill(drawRect)
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

        let hasActiveAnimation = hasActiveClearing()

        // Pass 1: Offscreen fog mask with blur
        let fogDrawn = drawBlurredFog(
            cells: cells,
            fogAlpha: fogAlpha,
            drawRect: drawRect,
            mapRect: mapRect,
            hasActiveAnimation: hasActiveAnimation,
            into: context
        )

        if !fogDrawn {
            renderFogDirect(
                cells: cells,
                fogAlpha: fogAlpha,
                drawRect: drawRect,
                into: context
            )
        }

        // Pass 2: Crisp overlays drawn directly to map context
        let isHeatMode = gridEngine.heatCells
        let isPhotoMode = gridEngine.photoCells != nil
        let dayHighlight = gridEngine.dayHighlightCells
        let dayNew = gridEngine.dayNewCells

        drawCellTints(
            cells: cells,
            isHeatMode: isHeatMode,
            isPhotoMode: isPhotoMode,
            dayHighlight: dayHighlight,
            dayNew: dayNew,
            context: context
        )
        drawInspectionHighlight(cells: cells, context: context)
        drawPhotoCounts(
            region: region,
            isPhotoMode: isPhotoMode,
            isHeatMode: isHeatMode,
            context: context
        )
    }

    // MARK: - Pass 1: Blurred Fog

    private func drawBlurredFog(
        cells: [(GridCell, Int)],
        fogAlpha: Double,
        drawRect: CGRect,
        mapRect: MKMapRect,
        hasActiveAnimation: Bool,
        into context: CGContext
    ) -> Bool {
        let width = Int(drawRect.width)
        let height = Int(drawRect.height)
        guard width > 0, height > 0 else { return false }

        let renderGen = gridEngine.renderGeneration
        let canUseCache = !hasActiveAnimation
            && cachedGeneration == renderGen
            && mapRectsEqual(cachedMapRect, mapRect)
            && cachedFogImage != nil

        let fogImage: CGImage
        if canUseCache, let cached = cachedFogImage {
            fogImage = cached
        } else {
            guard let offscreen = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            // Flip to match UIKit coordinate system
            offscreen.translateBy(x: 0, y: CGFloat(height))
            offscreen.scaleBy(x: 1, y: -1)

            offscreen.translateBy(x: -drawRect.origin.x, y: -drawRect.origin.y)

            offscreen.setFillColor(Constants.fogColor.withAlphaComponent(fogAlpha).cgColor)
            offscreen.fill(drawRect)

            for (cell, _) in cells {
                let cellRect = cellScreenRect(for: cell)
                offscreen.setBlendMode(.clear)
                offscreen.fill(cellRect)
            }
            offscreen.setBlendMode(.normal)

            // Clearing animation residuals
            let now = Date()
            let animationDuration: TimeInterval = 0.3
            for (cell, revealTime) in gridEngine.recentlyRevealedCells {
                let age = now.timeIntervalSince(revealTime)
                guard age < animationDuration else { continue }
                let progress = age / animationDuration
                let residualAlpha = (1.0 - progress) * Double(Constants.fogColor.cgColor.alpha)
                let cellRect = cellScreenRect(for: cell)
                offscreen.setFillColor(Constants.fogColor.withAlphaComponent(residualAlpha).cgColor)
                offscreen.fill(cellRect)
            }

            guard let rawImage = offscreen.makeImage() else { return false }

            let sampleCell = cells.first.map { cellScreenRect(for: $0.0) }
            let cellPixelWidth = sampleCell?.width ?? 30.0
            let blurRadius = UInt32(Float(cellPixelWidth) * Constants.fogBlurRadiusFraction)

            if blurRadius > 1 {
                if let blurred = applyBlur(to: rawImage, radius: blurRadius) {
                    fogImage = blurred
                } else {
                    fogImage = rawImage
                }
            } else {
                fogImage = rawImage
            }

            if !hasActiveAnimation {
                cachedFogImage = fogImage
                cachedGeneration = renderGen
                cachedMapRect = mapRect
            }
        }

        context.saveGState()
        // CGContext draws images with origin at bottom-left; flip for correct orientation
        context.translateBy(x: drawRect.origin.x, y: drawRect.origin.y + drawRect.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(fogImage, in: CGRect(x: 0, y: 0, width: drawRect.width, height: drawRect.height))
        context.restoreGState()

        return true
    }

    // MARK: - Fallback: Direct Fog (no blur)

    private func renderFogDirect(
        cells: [(GridCell, Int)],
        fogAlpha: Double,
        drawRect: CGRect,
        into context: CGContext
    ) {
        context.setFillColor(Constants.fogColor.withAlphaComponent(fogAlpha).cgColor)
        context.fill(drawRect)

        for (cell, _) in cells {
            let cellRect = cellScreenRect(for: cell)
            context.setBlendMode(.clear)
            context.fill(cellRect)
        }
        context.setBlendMode(.normal)

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
    }

    // MARK: - Pass 2: Crisp Overlays

    private func drawCellTints(
        cells: [(GridCell, Int)],
        isHeatMode: Bool,
        isPhotoMode: Bool,
        dayHighlight: Set<GridCell>?,
        dayNew: Set<GridCell>?,
        context: CGContext
    ) {
        for (cell, count) in cells {
            let cellRect = cellScreenRect(for: cell)

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
                context.setBlendMode(.normal)
                context.setFillColor(Constants.revealedCellTint.cgColor)
                context.fill(cellRect)
            }
            context.setBlendMode(.normal)

            if let dayHighlight {
                if dayHighlight.contains(cell) {
                    let isNew = dayNew?.contains(cell) ?? false
                    let highlightColor = isNew
                        ? UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 0.45)
                        : UIColor.white.withAlphaComponent(0.3)
                    context.setFillColor(highlightColor.cgColor)
                    context.fill(cellRect)
                } else {
                    context.setFillColor(Constants.fogColor.withAlphaComponent(0.5).cgColor)
                    context.fill(cellRect)
                }
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

    // MARK: - Blur via Accelerate

    private func applyBlur(to image: CGImage, radius: UInt32) -> CGImage? {
        var radius = radius
        if radius % 2 == 0 { radius += 1 }

        var inBuffer = vImage_Buffer()
        var outBuffer = vImage_Buffer()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var mutableFormat = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: Unmanaged.passUnretained(colorSpace),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )

        var error = vImageBuffer_InitWithCGImage(
            &inBuffer, &mutableFormat, nil, image, vImage_Flags(kvImageNoFlags)
        )
        guard error == kvImageNoError else { return nil }
        defer { free(inBuffer.data) }

        error = vImageBuffer_Init(&outBuffer, inBuffer.height, inBuffer.width, 32, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        defer { free(outBuffer.data) }

        // 3x box convolve approximates gaussian blur
        for _ in 0..<3 {
            error = vImageBoxConvolve_ARGB8888(
                &inBuffer, &outBuffer, nil, 0, 0,
                radius, radius,
                nil, vImage_Flags(kvImageEdgeExtend)
            )
            guard error == kvImageNoError else { return nil }
            swap(&inBuffer, &outBuffer)
        }

        // After 3 swaps, result is in inBuffer
        let result = vImageCreateCGImageFromBuffer(
            &inBuffer, &mutableFormat, nil, nil, vImage_Flags(kvImageNoFlags), &error
        )
        guard error == kvImageNoError else { return nil }
        return result?.takeRetainedValue()
    }

    // MARK: - Helpers

    private func mapRectsEqual(_ a: MKMapRect, _ b: MKMapRect) -> Bool {
        a.origin.x == b.origin.x
            && a.origin.y == b.origin.y
            && a.size.width == b.size.width
            && a.size.height == b.size.height
    }

    private func hasActiveClearing() -> Bool {
        let now = Date()
        let animationDuration: TimeInterval = 0.3
        for (_, revealTime) in gridEngine.recentlyRevealedCells {
            if now.timeIntervalSince(revealTime) < animationDuration {
                return true
            }
        }
        return false
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
