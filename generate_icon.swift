#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outputPath = "\(FileManager.default.currentDirectoryPath)/Stray/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

// S shape grid (7 wide x 9 tall)
let grid: [[Int]] = [
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 0, 0, 0, 1, 1],
    [1, 1, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 0, 0],
    [0, 0, 1, 1, 1, 1, 0],
    [0, 0, 0, 0, 0, 1, 1],
    [0, 0, 0, 0, 0, 1, 1],
    [1, 1, 0, 0, 0, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
]

let cols = grid[0].count  // 7
let rows = grid.count      // 9

// Heat gradient colors (top to bottom)
struct RGB { let r: CGFloat; let g: CGFloat; let b: CGFloat }
let gradientColors: [(position: CGFloat, color: RGB)] = [
    (0.0,  RGB(r: 0.3, g: 0.5, b: 0.9)),    // cool blue
    (0.25, RGB(r: 0.35, g: 0.55, b: 0.8)),   // light blue
    (0.5,  RGB(r: 0.55, g: 0.5, b: 0.45)),   // neutral
    (0.75, RGB(r: 0.9, g: 0.6, b: 0.2)),     // warm amber
    (1.0,  RGB(r: 1.0, g: 0.85, b: 0.3)),    // bright glow
]

func interpolateColor(at t: CGFloat) -> RGB {
    let clamped = min(max(t, 0), 1)
    for i in 0..<(gradientColors.count - 1) {
        let (p0, c0) = gradientColors[i]
        let (p1, c1) = gradientColors[i + 1]
        if clamped >= p0 && clamped <= p1 {
            let local = (clamped - p0) / (p1 - p0)
            return RGB(
                r: c0.r + (c1.r - c0.r) * local,
                g: c0.g + (c1.g - c0.g) * local,
                b: c0.b + (c1.b - c0.b) * local
            )
        }
    }
    return gradientColors.last!.color
}

// Layout: center the grid with margins safe for iOS icon rounding (~118px each side)
let margin: CGFloat = 150
let gap: CGFloat = 8
let availableW = CGFloat(size) - 2 * margin
let availableH = CGFloat(size) - 2 * margin
let cellW = (availableW - CGFloat(cols - 1) * gap) / CGFloat(cols)
let cellH = (availableH - CGFloat(rows - 1) * gap) / CGFloat(rows)
let cellSize = min(cellW, cellH)

// Recalculate to center
let totalW = CGFloat(cols) * cellSize + CGFloat(cols - 1) * gap
let totalH = CGFloat(rows) * cellSize + CGFloat(rows - 1) * gap
let originX = (CGFloat(size) - totalW) / 2
let originY = (CGFloat(size) - totalH) / 2

// Create bitmap context
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create CGContext")
}

// Fill background — fog color
ctx.setFillColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.0)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Draw glow pass first (behind cells) for warmer cells
for row in 0..<rows {
    for col in 0..<cols {
        guard grid[row][col] == 1 else { continue }
        let t = CGFloat(row) / CGFloat(rows - 1)
        let color = interpolateColor(at: t)

        // Glow intensity increases toward bottom (warmer cells glow more)
        let glowAlpha = 0.08 + t * 0.15

        let x = originX + CGFloat(col) * (cellSize + gap)
        // Flip y: CG origin is bottom-left
        let y = CGFloat(size) - originY - CGFloat(row + 1) * cellSize - CGFloat(row) * gap
        let glowInset: CGFloat = -cellSize * 0.5
        let glowRect = CGRect(x: x + glowInset, y: y + glowInset,
                              width: cellSize - 2 * glowInset, height: cellSize - 2 * glowInset)
        ctx.setFillColor(red: color.r, green: color.g, blue: color.b, alpha: glowAlpha)
        ctx.fillEllipse(in: glowRect)
    }
}

// Draw cells
let cornerRadius: CGFloat = cellSize * 0.15
for row in 0..<rows {
    for col in 0..<cols {
        guard grid[row][col] == 1 else { continue }
        let t = CGFloat(row) / CGFloat(rows - 1)
        let color = interpolateColor(at: t)

        let x = originX + CGFloat(col) * (cellSize + gap)
        let y = CGFloat(size) - originY - CGFloat(row + 1) * cellSize - CGFloat(row) * gap

        let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
        ctx.fillPath()
    }
}

// Generate image
guard let image = ctx.makeImage() else {
    fatalError("Failed to create image")
}

// Ensure output directory exists
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

// Write PNG
guard let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Failed to create image destination at \(outputPath)")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    fatalError("Failed to write PNG")
}

print("Icon generated: \(outputPath)")
print("Size: \(size)x\(size)")
