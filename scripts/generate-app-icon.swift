#!/usr/bin/env swift

import AppKit
import Foundation

enum IconKind {
    case touchBarpalooza
    case pokiSitelen
}

func color(_ white: CGFloat, alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedWhite: white, alpha: alpha)
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func renderIcon(kind: IconKind, pixels: Int) throws -> Data {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "AppIcon", code: 1)
    }

    rep.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "AppIcon", code: 2)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let outer = NSRect(x: size * 0.015, y: size * 0.015, width: size * 0.97, height: size * 0.97)
    let outerPath = roundedRect(outer, radius: size * 0.19)

    context.saveGraphicsState()
    outerPath.addClip()
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.145, green: 0.17, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.018, green: 0.028, blue: 0.035, alpha: 1)
    ])!
    gradient.draw(in: outer, angle: -90)
    context.restoreGraphicsState()

    color(0.43, alpha: 0.85).setStroke()
    outerPath.lineWidth = max(1, size * 0.009)
    outerPath.stroke()

    switch kind {
    case .touchBarpalooza:
        // Match the selected Option 3 more closely: a slim monochrome Touch
        // Bar capsule with four comfortably inset buttons.
        let pill = NSRect(
            x: size * 0.105,
            y: size * 0.415,
            width: size * 0.79,
            height: size * 0.17
        )
        let pillPath = roundedRect(pill, radius: size * 0.085)
        color(0.97).setStroke()
        pillPath.lineWidth = max(2, size * 0.026)
        pillPath.stroke()

        let buttonY = size * 0.447
        let buttonH = size * 0.106
        let buttonW = size * 0.145
        let gap = size * 0.028
        var x = size * 0.169

        for index in 0..<4 {
            let rect = NSRect(x: x, y: buttonY, width: buttonW, height: buttonH)
            let path = roundedRect(rect, radius: size * 0.028)
            let shade: CGFloat = index == 0 ? 0.96 : 0.83
            color(shade).setFill()
            path.fill()
            color(0.72, alpha: 0.45).setStroke()
            path.lineWidth = max(1, size * 0.0045)
            path.stroke()
            x += buttonW + gap
        }

    case .pokiSitelen:
        let roof = NSBezierPath()
        roof.move(to: NSPoint(x: size * 0.18, y: size * 0.36))
        roof.line(to: NSPoint(x: size * 0.50, y: size * 0.69))
        roof.line(to: NSPoint(x: size * 0.82, y: size * 0.36))
        roof.lineCapStyle = .round
        roof.lineJoinStyle = .round
        roof.lineWidth = max(3, size * 0.065)
        color(0.97).setStroke()
        roof.stroke()

        let dotRect = NSRect(x: size * 0.415, y: size * 0.21, width: size * 0.17, height: size * 0.17)
        color(0.97).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIcon", code: 3)
    }
    return data
}

let args = ProcessInfo.processInfo.arguments
guard args.count == 3 else {
    fputs("usage: generate-app-icon.swift <touchbarpalooza|poki-sitelen> <output.icns>\n", stderr)
    exit(2)
}

let kind: IconKind
switch args[1] {
case "touchbarpalooza":
    kind = .touchBarpalooza
case "poki-sitelen":
    kind = .pokiSitelen
default:
    fputs("unknown icon kind: \(args[1])\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: args[2])
let fm = FileManager.default
try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let iconsetURL = fm.temporaryDirectory
    .appendingPathComponent("TouchBarpaloozaIcon-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: iconsetURL) }

let specs: [(Int, Int, String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

for (points, scale, filename) in specs {
    let data = try renderIcon(kind: kind, pixels: points * scale)
    try data.write(to: iconsetURL.appendingPathComponent(filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", outputURL.path, iconsetURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fputs("iconutil failed with status \(process.terminationStatus)\n", stderr)
    exit(process.terminationStatus)
}
