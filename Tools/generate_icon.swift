#!/usr/bin/swift

// Generates a 1024x1024 Stray app icon: lowercase italic serif "s" in amber
// on a radial dark gradient.
// Run: swift Tools/generate_icon.swift <output-path>

import AppKit
import CoreText

guard CommandLine.arguments.count >= 2 else {
    print("usage: swift generate_icon.swift <output-path>")
    exit(1)
}
let outPath = CommandLine.arguments[1]

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    print("no graphics context")
    exit(1)
}

// MARK: Background — radial dark gradient
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1.0).cgColor,
    NSColor(red: 0.015, green: 0.015, blue: 0.02, alpha: 1.0).cgColor,
] as CFArray
let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
let center = CGPoint(x: size.width / 2, y: size.height / 2)
ctx.drawRadialGradient(
    bgGradient,
    startCenter: center,
    startRadius: 0,
    endCenter: center,
    endRadius: size.width * 0.70,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

// MARK: Glyph — italic serif "s" in amber
// Try New York (system serif) italic first, fall back to Times-Italic.
let fontSize: CGFloat = 760
let font: NSFont = NSFont(name: "NewYork-RegularItalic", size: fontSize)
    ?? NSFont(name: "NewYorkRegular-Italic", size: fontSize)
    ?? NSFont(name: "Times-Italic", size: fontSize)
    ?? NSFont.systemFont(ofSize: fontSize)

let amber = NSColor(red: 0.92, green: 0.72, blue: 0.28, alpha: 1.0)

let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: amber,
]
let str = NSAttributedString(string: "s", attributes: attrs)

// Compute true tight bounds via Core Text so we can center accurately.
let line = CTLineCreateWithAttributedString(str as CFAttributedString)
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

let drawX = (size.width - bounds.width) / 2 - bounds.origin.x
let drawY = (size.height - bounds.height) / 2 - bounds.origin.y

ctx.textPosition = CGPoint(x: drawX, y: drawY)
CTLineDraw(line, ctx)

image.unlockFocus()

// MARK: Encode + write PNG
guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    print("png encode failed")
    exit(1)
}

let url = URL(fileURLWithPath: outPath)
do {
    try png.write(to: url)
    print("wrote \(url.path)")
} catch {
    print("write failed: \(error)")
    exit(1)
}
