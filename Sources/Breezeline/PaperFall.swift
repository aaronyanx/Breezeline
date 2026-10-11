import AppKit
import QuartzCore

/// Tendedero's fall motion, rendered over the whole screen instead of inside the line panel.
@MainActor
final class PaperFall {
    static let duration: CFTimeInterval = 0.55
    private static var current: [PaperFall] = []
    private let window: NSPanel
    private let layer = CALayer()
    private let card: CGRect
    private let tilt: CGFloat
    private var start: CFTimeInterval = 0
    private var timer: Timer?

    static func pose(at progress: Double, tilt: CGFloat) -> (distance: CGFloat, angle: CGFloat, opacity: Float) {
        let raw = max(0, min(1, progress))
        let eased = CGFloat(raw * raw * raw)
        return (520 * eased, tilt + (tilt * 7 + 20) * eased, Float(1 - eased))
    }

    static func run(image: CGImage, card: CGRect, tilt: CGFloat, on screen: NSScreen) {
        let fall = PaperFall(image: image, card: card, tilt: tilt, screen: screen)
        current.append(fall)
        fall.run()
    }

    private init(image: CGImage, card: CGRect, tilt: CGFloat, screen: NSScreen) {
        self.card = card
        self.tilt = tilt
        window = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let host = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        host.wantsLayer = true
        window.contentView = host
        layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        layer.bounds = CGRect(origin: .zero, size: card.size)
        layer.contents = image
        layer.contentsScale = screen.backingScaleFactor
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.24
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: -5)
        host.layer?.addSublayer(layer)
    }

    private func run() {
        update(0)
        window.orderFrontRegardless()
        start = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let progress = min(1, (CACurrentMediaTime() - start) / Self.duration)
        update(progress)
        if progress >= 1 {
            timer?.invalidate()
            timer = nil
            window.orderOut(nil)
            Self.current.removeAll { $0 === self }
        }
    }

    private func update(_ progress: Double) {
        let pose = Self.pose(at: progress, tilt: tilt)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.position = CGPoint(x: card.midX - window.frame.minX,
                                 y: card.maxY - window.frame.minY - pose.distance)
        layer.setAffineTransform(CGAffineTransform(rotationAngle: -pose.angle * .pi / 180))
        layer.opacity = pose.opacity
        CATransaction.commit()
    }
}
