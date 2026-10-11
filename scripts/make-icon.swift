import AppKit

let output = CommandLine.arguments[1]
let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../Sources/Breezeline/Resources")

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}
func stroke(_ path: NSBezierPath, _ tint: NSColor, _ width: CGFloat) {
    tint.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}
func shadow(_ opacity: CGFloat, blur: CGFloat, y: CGFloat) {
    let shadow = NSShadow()
    shadow.shadowColor = color(0.10, 0.17, 0.28, opacity)
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: y)
    shadow.set()
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let base = rounded(NSRect(x: 94, y: 94, width: 836, height: 836), 188)
NSGraphicsContext.saveGraphicsState()
shadow(0.22, blur: 30, y: -15)
color(0.72, 0.80, 0.89).setFill()
base.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [color(0.87, 0.90, 0.99), color(0.71, 0.87, 0.86)])!
    .draw(in: base, angle: -65)
stroke(base, color(1, 1, 1, 0.84), 5)
stroke(rounded(NSRect(x: 106, y: 106, width: 812, height: 812), 179),
       color(1, 1, 1, 0.30), 1.5)

let rope = NSBezierPath()
rope.move(to: NSPoint(x: 119, y: 741))
rope.curve(to: NSPoint(x: 905, y: 741),
           controlPoint1: NSPoint(x: 330, y: 665),
           controlPoint2: NSPoint(x: 694, y: 665))
NSGraphicsContext.saveGraphicsState()
shadow(0.20, blur: 3, y: -2)
stroke(rope, color(0.37, 0.43, 0.51, 0.72), 4)
NSGraphicsContext.restoreGraphicsState()

func clip() {
    let clip = rounded(NSRect(x: -11, y: -23, width: 22, height: 76), 8)
    NSGraphicsContext.saveGraphicsState()
    shadow(0.25, blur: 6, y: -3)
    color(0.79, 0.83, 0.85).setFill()
    clip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [color(0.59, 0.65, 0.68), color(0.96, 0.98, 0.98),
                        color(0.74, 0.80, 0.82)])!.draw(in: clip, angle: 0)
    stroke(clip, color(1, 1, 1, 0.70), 1.5)
    let slot = rounded(NSRect(x: -6, y: 7, width: 12, height: 2), 1)
    color(0.31, 0.38, 0.41, 0.45).setFill()
    slot.fill()
}

// Independent artwork: a textured paper sheet and a landscape photo.
func card(center: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat,
          tilt: CGFloat, note: Bool) throws {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let transform = NSAffineTransform()
    transform.translateX(by: center, yBy: top)
    transform.rotate(byDegrees: tilt)
    transform.concat()
    let rect = NSRect(x: -width / 2, y: -height, width: width, height: height)
    let shape = rounded(rect, note ? 9 : 33)
    NSGraphicsContext.saveGraphicsState()
    shadow(0.22, blur: 24, y: -13)
    (note ? color(0.99, 0.95, 0.81) : color(0.97, 0.99, 1, 0.85)).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    if note {
        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        if let texture = NSImage(contentsOf: resources.appendingPathComponent("natural-paper.png")) {
            texture.draw(in: rect, from: .zero, operation: .multiply, fraction: 0.72)
        }
        NSGradient(colors: [color(1, 1, 1, 0.20), color(0.64, 0.47, 0.22, 0.06)])!
            .draw(in: shape, angle: -90)
        NSGraphicsContext.restoreGraphicsState()
        // Short uneven strokes read as handwriting, rather than browser UI.
        for (index, length) in [CGFloat(168), 219, 196, 208, 133].enumerated() {
            let y = -78 - CGFloat(index) * 45
            let line = NSBezierPath()
            line.move(to: NSPoint(x: rect.minX + 35, y: y))
            line.curve(to: NSPoint(x: rect.minX + 35 + length, y: y + 3),
                       controlPoint1: NSPoint(x: rect.minX + 90, y: y - 9),
                       controlPoint2: NSPoint(x: rect.minX + length - 15, y: y + 11))
            stroke(line, color(0.37, 0.31, 0.22, index == 0 ? 0.82 : 0.55),
                   index == 0 ? 9 : 6)
        }
        // A small turned-up corner distinguishes paper from the photo's glass frame.
        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: rect.maxX - 37, y: rect.minY))
        fold.line(to: NSPoint(x: rect.maxX - 37, y: rect.minY + 37))
        fold.line(to: NSPoint(x: rect.maxX, y: rect.minY + 37))
        fold.close()
        color(1, 0.99, 0.91).setFill()
        fold.fill()
        stroke(fold, color(0.61, 0.51, 0.31, 0.20), 1)
        let svg = try String(contentsOf: resources.appendingPathComponent("feather.svg"), encoding: .utf8)
        if let feather = NSImage(data: Data(svg.replacingOccurrences(
            of: "currentColor", with: "#756343").utf8)) {
            feather.draw(in: NSRect(x: rect.maxX - 78, y: rect.minY + 47, width: 30, height: 30))
        }
        stroke(shape, color(1, 1, 1, 0.50), 1.5)
    } else {
        let photo = rect.insetBy(dx: 13, dy: 13)
        NSGraphicsContext.saveGraphicsState()
        rounded(photo, 23).addClip()
        NSGradient(colors: [color(0.27, 0.37, 0.65), color(0.89, 0.60, 0.61),
                            color(0.99, 0.76, 0.49)])!.draw(in: photo, angle: -90)
        color(1, 0.92, 0.69).setFill()
        NSBezierPath(ovalIn: NSRect(x: photo.maxX - 104, y: photo.maxY - 114,
                                  width: 63, height: 63)).fill()
        let distant = NSBezierPath()
        distant.move(to: NSPoint(x: photo.minX - 10, y: photo.minY))
        distant.line(to: NSPoint(x: photo.minX - 10, y: photo.minY + 67))
        distant.curve(to: NSPoint(x: photo.maxX + 10, y: photo.minY + 92),
                      controlPoint1: NSPoint(x: photo.minX + 100, y: photo.minY + 146),
                      controlPoint2: NSPoint(x: photo.maxX - 102, y: photo.minY + 18))
        distant.line(to: NSPoint(x: photo.maxX + 10, y: photo.minY))
        distant.close()
        color(0.29, 0.36, 0.49).setFill()
        distant.fill()
        let foreground = NSBezierPath()
        foreground.move(to: NSPoint(x: photo.minX - 10, y: photo.minY))
        foreground.line(to: NSPoint(x: photo.minX - 10, y: photo.minY + 39))
        foreground.curve(to: NSPoint(x: photo.maxX + 10, y: photo.minY + 60),
                        controlPoint1: NSPoint(x: photo.minX + 115, y: photo.minY + 8),
                        controlPoint2: NSPoint(x: photo.maxX - 52, y: photo.minY + 116))
        foreground.line(to: NSPoint(x: photo.maxX + 10, y: photo.minY))
        foreground.close()
        color(0.16, 0.28, 0.32).setFill()
        foreground.fill()
        NSGraphicsContext.restoreGraphicsState()
        stroke(shape, color(1, 1, 1, 0.86), 3.5)
    }
    clip()
}

try card(center: 365, top: 698, width: 320, height: 382, tilt: 5, note: true)
try card(center: 699, top: 698, width: 310, height: 278, tilt: -5, note: false)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: output))

if CommandLine.arguments.count > 2 {
    let menu = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 72, pixelsHigh: 72,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: menu)
    let rope = NSBezierPath()
    rope.move(to: NSPoint(x: 3, y: 57))
    rope.curve(to: NSPoint(x: 69, y: 57),
               controlPoint1: NSPoint(x: 23, y: 49), controlPoint2: NSPoint(x: 49, y: 49))
    stroke(rope, .black, 3)
    stroke(rounded(NSRect(x: 9, y: 10, width: 25, height: 38), 2), .black, 3)
    stroke(rounded(NSRect(x: 41, y: 22, width: 25, height: 26), 4), .black, 3)
    for x: CGFloat in [21, 53] {
        NSColor.black.setFill()
        rounded(NSRect(x: x - 2, y: 44, width: 4, height: 14), 1.5).fill()
    }
    for y: CGFloat in [37, 29, 21] {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 14, y: y))
        line.line(to: NSPoint(x: y == 21 ? 24 : 28, y: y))
        stroke(line, .black, 2)
    }
    let mountain = NSBezierPath()
    mountain.move(to: NSPoint(x: 45, y: 28))
    mountain.line(to: NSPoint(x: 51, y: 36))
    mountain.line(to: NSPoint(x: 57, y: 30))
    mountain.line(to: NSPoint(x: 63, y: 36))
    stroke(mountain, .black, 2)
    NSColor.black.setFill()
    NSBezierPath(ovalIn: NSRect(x: 57, y: 41, width: 4, height: 4)).fill()
    NSGraphicsContext.restoreGraphicsState()
    try menu.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
