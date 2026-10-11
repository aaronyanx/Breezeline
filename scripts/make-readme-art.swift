// Draws an illustrated product preview, not a screenshot of a running app.
// Usage: swift scripts/make-readme-art.swift [output-directory]
import AppKit
import CoreText

let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resources = project.appendingPathComponent("Sources/Breezeline/Resources")
let output = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
    ?? project.appendingPathComponent("docs/images")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
CTFontManagerRegisterFontsForURL(resources.appendingPathComponent("Caveat.ttf") as CFURL, .process, nil)
let texture = NSImage(contentsOf: resources.appendingPathComponent("natural-paper.png"))
let featherSource = try String(contentsOf: resources.appendingPathComponent("feather.svg"), encoding: .utf8)
let feather = NSImage(data: Data(featherSource.replacingOccurrences(
    of: "currentColor", with: "#67553B").utf8))

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}
func shadow(_ opacity: CGFloat, blur: CGFloat, y: CGFloat) {
    let shadow = NSShadow()
    shadow.shadowColor = color(0.08, 0.14, 0.22, opacity)
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: y)
    shadow.set()
}
func stroke(_ path: NSBezierPath, _ tint: NSColor, _ width: CGFloat) {
    tint.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}
func label(_ string: String, in rect: NSRect, font: NSFont, tint: NSColor,
           alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineSpacing = 4
    let text = NSAttributedString(string: string, attributes: [
        .font: font, .foregroundColor: tint, .paragraphStyle: paragraph,
    ])
    text.draw(in: rect)
}
func handwriting(_ size: CGFloat) -> NSFont {
    NSFont(name: "Caveat-Regular", size: size) ?? .systemFont(ofSize: size)
}
func clip() {
    let shape = rounded(NSRect(x: -4.5, y: -17.5, width: 9, height: 26), 3.5)
    NSGraphicsContext.saveGraphicsState()
    shadow(0.26, blur: 3, y: -1.5)
    color(0.80, 0.83, 0.85).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [color(0.60, 0.66, 0.68), color(0.96, 0.98, 0.98),
                        color(0.70, 0.77, 0.79)])!.draw(in: shape, angle: 0)
    stroke(shape, color(1, 1, 1, 0.7), 0.6)
    color(0.24, 0.32, 0.35, 0.48).setFill()
    rounded(NSRect(x: -2.5, y: -0.7, width: 5, height: 1.4), 0.7).fill()
}

func note() {
    let rect = NSRect(x: -110, y: -274, width: 220, height: 260)
    let shape = rounded(rect, 5)
    NSGraphicsContext.saveGraphicsState()
    shadow(0.18, blur: 14, y: -8)
    color(0.97, 0.94, 0.82).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    texture?.draw(in: rect, from: .zero, operation: .multiply, fraction: 0.82)
    NSGradient(colors: [color(1, 1, 1, 0.16), color(0, 0, 0, 0.035)])!
        .draw(in: shape, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    let ink = color(0.18, 0.20, 0.17)
    label("Little things", in: NSRect(x: -90, y: -67, width: 180, height: 34),
          font: handwriting(25), tint: ink)
    label("A good idea.\nA tiny reminder.\nSomething worth\nkeeping close.",
          in: NSRect(x: -90, y: -224, width: 180, height: 144),
          font: handwriting(21), tint: ink)
    feather?.draw(in: NSRect(x: 73, y: -253, width: 17, height: 17))
    clip()
}

func image(width: CGFloat, height: CGFloat, dark: Bool) {
    let rect = NSRect(x: -width / 2, y: -height - 14, width: width, height: height)
    let glass = rounded(rect, 16)
    NSGraphicsContext.saveGraphicsState()
    shadow(dark ? 0.40 : 0.19, blur: 16, y: -8)
    color(1, 1, 1, dark ? 0.24 : 0.62).setFill()
    glass.fill()
    NSGraphicsContext.restoreGraphicsState()
    let photo = rect.insetBy(dx: 4, dy: 4)
    NSGraphicsContext.saveGraphicsState()
    rounded(photo, 12).addClip()
        NSGradient(colors: [color(0.28, 0.38, 0.65), color(0.87, 0.58, 0.60),
                            color(0.99, 0.76, 0.49)])!.draw(in: photo, angle: -90)
        color(1, 0.92, 0.69).setFill()
        NSBezierPath(ovalIn: NSRect(x: photo.maxX - 85, y: photo.maxY - 89,
                                  width: 44, height: 44)).fill()
        for (index, tint) in [color(0.29, 0.36, 0.49), color(0.16, 0.28, 0.32)].enumerated() {
            let ridge = NSBezierPath()
            let lift: CGFloat = index == 0 ? 52 : 29
            ridge.move(to: NSPoint(x: photo.minX - 5, y: photo.minY))
            ridge.line(to: NSPoint(x: photo.minX - 5, y: photo.minY + lift))
            ridge.curve(to: NSPoint(x: photo.maxX + 5, y: photo.minY + lift),
                        controlPoint1: NSPoint(x: photo.minX + 90, y: photo.minY + (index == 0 ? 112 : 8)),
                        controlPoint2: NSPoint(x: photo.maxX - 45, y: photo.minY + (index == 0 ? 8 : 91)))
            ridge.line(to: NSPoint(x: photo.maxX + 5, y: photo.minY))
            ridge.close()
            tint.setFill()
            ridge.fill()
        }
    NSGraphicsContext.restoreGraphicsState()
    stroke(glass, color(1, 1, 1, dark ? 0.44 : 0.82), 0.9)
    clip()
}

let width: CGFloat = 1200
let height: CGFloat = 750
let scale: CGFloat = 2

for dark in [false, true] {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)
    let page = dark ? color(0.06, 0.09, 0.12) : NSColor.white
    let ink = dark ? color(0.95, 0.97, 1) : color(0.10, 0.15, 0.19)
    page.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
    label("Breezeline", in: NSRect(x: 60, y: 586, width: 1080, height: 96),
          font: .systemFont(ofSize: 76, weight: .semibold), tint: ink, alignment: .center)
    label("Images and ideas, hanging together.",
          in: NSRect(x: 60, y: 536, width: 1080, height: 42),
          font: .systemFont(ofSize: 27), tint: ink.withAlphaComponent(0.66), alignment: .center)

    let scene = NSRect(x: 60, y: 87, width: 1080, height: 410)
    let shape = rounded(scene, 32)
    NSGraphicsContext.saveGraphicsState()
    shadow(dark ? 0.45 : 0.17, blur: 26, y: -12)
    page.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: dark
        ? [color(0.12, 0.18, 0.29), color(0.18, 0.23, 0.32), color(0.15, 0.31, 0.30)]
        : [color(0.86, 0.90, 0.99), color(0.88, 0.92, 0.98), color(0.73, 0.87, 0.86)])!
        .draw(in: scene, angle: -25)

    let barHeight: CGFloat = 27
    (dark ? color(0.09, 0.14, 0.21, 0.70) : color(1, 1, 1, 0.53)).setFill()
    NSBezierPath(rect: NSRect(x: scene.minX, y: scene.maxY - barHeight,
                             width: scene.width, height: barHeight)).fill()
    let menuInk = dark ? color(0.86, 0.92, 0.97) : color(0.21, 0.27, 0.35)
    label("Breezeline", in: NSRect(x: scene.minX + 21, y: scene.maxY - 22, width: 78, height: 18),
          font: .systemFont(ofSize: 12, weight: .semibold), tint: menuInk)
    label("File   Edit",
          in: NSRect(x: scene.minX + 111, y: scene.maxY - 22, width: 90, height: 18),
          font: .systemFont(ofSize: 12), tint: menuInk)
    label("Sun  9:41", in: NSRect(x: scene.maxX - 91, y: scene.maxY - 22, width: 77, height: 18),
          font: .systemFont(ofSize: 12), tint: menuInk, alignment: .right)
    // A small paper-and-photo mark mirrors the current menu-bar icon.
    stroke(rounded(NSRect(x: scene.maxX - 148, y: scene.maxY - 21, width: 9, height: 14), 1),
           menuInk, 1)
    stroke(rounded(NSRect(x: scene.maxX - 135, y: scene.maxY - 18, width: 11, height: 10), 2),
           menuInk, 1)
    let menuRope = NSBezierPath()
    menuRope.move(to: NSPoint(x: scene.maxX - 151, y: scene.maxY - 5))
    menuRope.curve(to: NSPoint(x: scene.maxX - 122, y: scene.maxY - 5),
                  controlPoint1: NSPoint(x: scene.maxX - 142, y: scene.maxY - 9),
                  controlPoint2: NSPoint(x: scene.maxX - 132, y: scene.maxY - 9))
    stroke(menuRope, menuInk, 1)
    menuInk.setFill()
    for x: CGFloat in [scene.maxX - 144, scene.maxX - 131] {
        rounded(NSRect(x: x, y: scene.maxY - 10, width: 1.5, height: 6), 0.5).fill()
    }

    let ropeTop = scene.maxY - barHeight - 10
    let sag = min(CGFloat(56), scene.width * 0.032)
    func ropeY(_ x: CGFloat) -> CGFloat {
        let fraction = (x - scene.minX) / scene.width
        return ropeTop - 4 * sag * fraction * (1 - fraction)
    }
    let rope = NSBezierPath()
    rope.move(to: NSPoint(x: scene.minX - 10, y: ropeTop))
    rope.curve(to: NSPoint(x: scene.maxX + 10, y: ropeTop),
               controlPoint1: NSPoint(x: scene.minX + scene.width / 3, y: ropeTop - 4 * sag / 3),
               controlPoint2: NSPoint(x: scene.minX + scene.width * 2 / 3, y: ropeTop - 4 * sag / 3))
    stroke(rope, dark ? color(0.76, 0.83, 0.86, 0.72) : color(0.45, 0.50, 0.56, 0.78), 1.4)

    for (index, x) in [CGFloat(454), 746].enumerated() {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: x, yBy: ropeY(x))
        transform.rotate(byDegrees: index == 0 ? 2 : -1.8)
        transform.concat()
        if index == 0 { note() }
        else { image(width: 260, height: 172, dark: dark) }
        NSGraphicsContext.restoreGraphicsState()
    }
    // The add-note control stays at the viewport edge, like in the app.
    let plus = NSRect(x: scene.maxX - 38, y: ropeY(scene.maxX - 24) - 37, width: 28, height: 28)
    color(1, 1, 1, dark ? 0.16 : 0.62).setFill()
    NSBezierPath(ovalIn: plus).fill()
    let cross = NSBezierPath()
    cross.move(to: NSPoint(x: plus.midX - 4, y: plus.midY))
    cross.line(to: NSPoint(x: plus.midX + 4, y: plus.midY))
    cross.move(to: NSPoint(x: plus.midX, y: plus.midY - 4))
    cross.line(to: NSPoint(x: plus.midX, y: plus.midY + 4))
    stroke(cross, menuInk, 1.2)
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    let file = output.appendingPathComponent(dark ? "hero-dark.png" : "hero-light.png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: file)
    print("Created \(file.path)")
}
