import Foundation

struct LineVisibility {
    private(set) var enabled = true
    private(set) var isVisible = false
    private(set) var alwaysVisible: Bool
    private var hoverSince: Date?
    private var awaySince: Date?
    private var peekUntil = Date.distantPast

    init(alwaysVisible: Bool = false) {
        self.alwaysVisible = alwaysVisible
        isVisible = alwaysVisible
    }

    mutating func updateHover(inMenuBar: Bool, insideLine: Bool, busy: Bool) {
        guard enabled else { return }
        let now = Date()
        if alwaysVisible {
            isVisible = true
            return
        }
        if isVisible {
            hoverSince = nil
            if inMenuBar || insideLine || busy || now < peekUntil {
                awaySince = nil
            } else {
                let since = awaySince ?? now
                awaySince = since
                if now.timeIntervalSince(since) >= 0.5 {
                    isVisible = false
                    awaySince = nil
                }
            }
        } else if inMenuBar {
            let since = hoverSince ?? now
            hoverSince = since
            if now.timeIntervalSince(since) >= 0.25 {
                isVisible = true
                hoverSince = nil
            }
        } else {
            hoverSince = nil
        }
    }

    mutating func toggle() {
        enabled.toggle()
        isVisible = enabled && alwaysVisible
        resetTimers()
    }

    mutating func setAlwaysVisible(_ on: Bool) {
        alwaysVisible = on
        enabled = true
        isVisible = on
        resetTimers()
    }

    mutating func revealNewImage() {
        guard enabled else { return }
        isVisible = true
        peekUntil = Date().addingTimeInterval(2.5)
        hoverSince = nil
        awaySince = nil
    }

    private mutating func resetTimers() {
        hoverSince = nil
        awaySince = nil
        peekUntil = .distantPast
    }
}
