import AppKit

func drawKey(_ rect: NSRect, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 68, yRadius: 68)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(srgbRed: 0.12, green: 0.07, blue: 0.34, alpha: 0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 22
    shadow.set()
    color.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.55).setStroke()
    path.lineWidth = 2
    path.stroke()
}

func drawIcon() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 96, y: 96, width: 832, height: 832), xRadius: 186, yRadius: 186)
    NSColor(srgbRed: 0.39, green: 0.30, blue: 0.83, alpha: 1).setFill()
    tile.fill()
    NSColor.white.withAlphaComponent(0.2).setStroke()
    tile.lineWidth = 2
    tile.stroke()

    drawKey(
        NSRect(x: 208, y: 422, width: 440, height: 398),
        color: NSColor(srgbRed: 0.88, green: 0.85, blue: 0.98, alpha: 1)
    )
    let ink = NSColor(srgbRed: 0.29, green: 0.23, blue: 0.62, alpha: 1)
    ink.setStroke()
    let shift = NSBezierPath()
    shift.move(to: NSPoint(x: 318, y: 710))
    for point in [NSPoint(x: 398, y: 790), NSPoint(x: 478, y: 710), NSPoint(x: 442, y: 710),
                  NSPoint(x: 442, y: 650), NSPoint(x: 354, y: 650), NSPoint(x: 354, y: 710)] {
        shift.line(to: point)
    }
    shift.close()
    shift.lineWidth = 18
    shift.lineJoinStyle = .round
    shift.stroke()

    drawKey(
        NSRect(x: 374, y: 206, width: 438, height: 428),
        color: NSColor(srgbRed: 0.98, green: 0.97, blue: 1, alpha: 1)
    )
    let command = NSBezierPath()
    command.move(to: NSPoint(x: 18, y: 8))
    command.curve(to: NSPoint(x: 21, y: 5), controlPoint1: NSPoint(x: 19.657, y: 8), controlPoint2: NSPoint(x: 21, y: 6.657))
    command.curve(to: NSPoint(x: 18, y: 2), controlPoint1: NSPoint(x: 21, y: 3.343), controlPoint2: NSPoint(x: 19.657, y: 2))
    command.curve(to: NSPoint(x: 15, y: 5), controlPoint1: NSPoint(x: 16.343, y: 2), controlPoint2: NSPoint(x: 15, y: 3.343))
    command.line(to: NSPoint(x: 15, y: 19))
    command.curve(to: NSPoint(x: 18, y: 22), controlPoint1: NSPoint(x: 15, y: 20.657), controlPoint2: NSPoint(x: 16.343, y: 22))
    command.curve(to: NSPoint(x: 21, y: 19), controlPoint1: NSPoint(x: 19.657, y: 22), controlPoint2: NSPoint(x: 21, y: 20.657))
    command.curve(to: NSPoint(x: 18, y: 16), controlPoint1: NSPoint(x: 21, y: 17.343), controlPoint2: NSPoint(x: 19.657, y: 16))
    command.line(to: NSPoint(x: 6, y: 16))
    command.curve(to: NSPoint(x: 3, y: 19), controlPoint1: NSPoint(x: 4.343, y: 16), controlPoint2: NSPoint(x: 3, y: 17.343))
    command.curve(to: NSPoint(x: 6, y: 22), controlPoint1: NSPoint(x: 3, y: 20.657), controlPoint2: NSPoint(x: 4.343, y: 22))
    command.curve(to: NSPoint(x: 9, y: 19), controlPoint1: NSPoint(x: 7.657, y: 22), controlPoint2: NSPoint(x: 9, y: 20.657))
    command.line(to: NSPoint(x: 9, y: 5))
    command.curve(to: NSPoint(x: 6, y: 2), controlPoint1: NSPoint(x: 9, y: 3.343), controlPoint2: NSPoint(x: 7.657, y: 2))
    command.curve(to: NSPoint(x: 3, y: 5), controlPoint1: NSPoint(x: 4.343, y: 2), controlPoint2: NSPoint(x: 3, y: 3.343))
    command.curve(to: NSPoint(x: 6, y: 8), controlPoint1: NSPoint(x: 3, y: 6.657), controlPoint2: NSPoint(x: 4.343, y: 8))
    command.close()
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    context.translateBy(x: 426, y: 252)
    context.scaleBy(x: 14, y: 14)
    ink.setStroke()
    command.lineWidth = 1.9
    command.lineJoinStyle = .round
    command.stroke()
    context.restoreGState()
}

guard CommandLine.arguments.count == 2 else {
    print("Usage: swift Scripts/make-icon.swift OUTPUT.icns")
    exit(EXIT_FAILURE)
}
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: ".build/AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let filename = "icon_\(points)x\(points)\(suffix).png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
    }
}
try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
let converter = Process()
converter.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
converter.arguments = ["--convert", "icns", "--output", destination.path, output.path]
try converter.run()
converter.waitUntilExit()
exit(converter.terminationStatus)
