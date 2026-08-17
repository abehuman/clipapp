#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-dmg-background.swift /path/to/background.png\n".utf8))
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = NSSize(width: 640, height: 400)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("Failed to allocate the DMG background.\n".utf8))
    exit(70)
}
bitmap.size = canvasSize

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let background = NSGradient(
    starting: NSColor(calibratedRed: 0.965, green: 0.976, blue: 0.992, alpha: 1),
    ending: NSColor(calibratedRed: 0.895, green: 0.925, blue: 0.973, alpha: 1)
)
background?.draw(in: NSRect(origin: .zero, size: canvasSize), angle: 90)

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1),
    .paragraphStyle: titleStyle,
]
NSString(string: "Install ClipApp").draw(
    in: NSRect(x: 80, y: 326, width: 480, height: 42),
    withAttributes: titleAttributes
)

let instructionAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 17, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.28, alpha: 1),
    .paragraphStyle: titleStyle,
]
NSString(string: "Drag ClipApp to Applications").draw(
    in: NSRect(x: 80, y: 55, width: 480, height: 28),
    withAttributes: instructionAttributes
)

let arrowColor = NSColor(calibratedRed: 0.22, green: 0.45, blue: 0.82, alpha: 0.9)
arrowColor.setStroke()
arrowColor.setFill()

let shaft = NSBezierPath()
shaft.lineWidth = 7
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: 260, y: 198))
shaft.line(to: NSPoint(x: 380, y: 198))
shaft.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 380, y: 198))
arrowHead.line(to: NSPoint(x: 356, y: 217))
arrowHead.line(to: NSPoint(x: 356, y: 179))
arrowHead.close()
arrowHead.fill()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to render the DMG background.\n".utf8))
    exit(70)
}

do {
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    FileHandle.standardError.write(Data("Failed to write DMG background: \(error)\n".utf8))
    exit(74)
}
