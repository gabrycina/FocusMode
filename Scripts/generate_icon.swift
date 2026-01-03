#!/usr/bin/env swift

import Cocoa

// Create app icon - a modern focus/target symbol
func createIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let center = NSPoint(x: size / 2, y: size / 2)
    let scale = CGFloat(size) / 1024.0

    // Background - rounded square with gradient
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.05, dy: CGFloat(size) * 0.05),
                               xRadius: CGFloat(size) * 0.22,
                               yRadius: CGFloat(size) * 0.22)

    // Gradient from deep purple to blue
    let gradient = NSGradient(colors: [
        NSColor(red: 0.4, green: 0.2, blue: 0.9, alpha: 1.0),
        NSColor(red: 0.2, green: 0.4, blue: 0.95, alpha: 1.0)
    ])!
    gradient.draw(in: bgPath, angle: -45)

    // Draw concentric circles (target symbol)
    let white = NSColor.white

    // Outer ring
    let outerRadius = CGFloat(size) * 0.35
    let outerPath = NSBezierPath(ovalIn: NSRect(
        x: center.x - outerRadius,
        y: center.y - outerRadius,
        width: outerRadius * 2,
        height: outerRadius * 2
    ))
    white.withAlphaComponent(0.9).setStroke()
    outerPath.lineWidth = CGFloat(size) * 0.04
    outerPath.stroke()

    // Middle ring
    let middleRadius = CGFloat(size) * 0.22
    let middlePath = NSBezierPath(ovalIn: NSRect(
        x: center.x - middleRadius,
        y: center.y - middleRadius,
        width: middleRadius * 2,
        height: middleRadius * 2
    ))
    white.withAlphaComponent(0.9).setStroke()
    middlePath.lineWidth = CGFloat(size) * 0.04
    middlePath.stroke()

    // Center dot
    let centerRadius = CGFloat(size) * 0.08
    let centerPath = NSBezierPath(ovalIn: NSRect(
        x: center.x - centerRadius,
        y: center.y - centerRadius,
        width: centerRadius * 2,
        height: centerRadius * 2
    ))
    white.setFill()
    centerPath.fill()

    // Crosshair lines
    let lineLength = CGFloat(size) * 0.12
    let lineOffset = CGFloat(size) * 0.38
    white.withAlphaComponent(0.9).setStroke()

    // Top line
    let topLine = NSBezierPath()
    topLine.move(to: NSPoint(x: center.x, y: center.y + lineOffset))
    topLine.line(to: NSPoint(x: center.x, y: center.y + lineOffset + lineLength))
    topLine.lineWidth = CGFloat(size) * 0.035
    topLine.lineCapStyle = .round
    topLine.stroke()

    // Bottom line
    let bottomLine = NSBezierPath()
    bottomLine.move(to: NSPoint(x: center.x, y: center.y - lineOffset))
    bottomLine.line(to: NSPoint(x: center.x, y: center.y - lineOffset - lineLength))
    bottomLine.lineWidth = CGFloat(size) * 0.035
    bottomLine.lineCapStyle = .round
    bottomLine.stroke()

    // Left line
    let leftLine = NSBezierPath()
    leftLine.move(to: NSPoint(x: center.x - lineOffset, y: center.y))
    leftLine.line(to: NSPoint(x: center.x - lineOffset - lineLength, y: center.y))
    leftLine.lineWidth = CGFloat(size) * 0.035
    leftLine.lineCapStyle = .round
    leftLine.stroke()

    // Right line
    let rightLine = NSBezierPath()
    rightLine.move(to: NSPoint(x: center.x + lineOffset, y: center.y))
    rightLine.line(to: NSPoint(x: center.x + lineOffset + lineLength, y: center.y))
    rightLine.lineWidth = CGFloat(size) * 0.035
    rightLine.lineCapStyle = .round
    rightLine.stroke()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created: \(path)")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// Create iconset directory
let iconsetPath = "/Users/gabrycina/Documents/dev/FocusMode/Assets/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Generate all required sizes for macOS app icon
let sizes = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, filename) in sizes {
    let image = createIcon(size: size)
    savePNG(image, to: "\(iconsetPath)/\(filename)")
}

print("\nIconset created! Run: iconutil -c icns \(iconsetPath)")
