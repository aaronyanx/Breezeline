import Foundation

enum NoteLayout {
    static let cardWidth: CGFloat = 220
    static let spacing: CGFloat = Layout.spacing
    static let margin: CGFloat = 42
    static let panelHeight: CGFloat = Layout.panelHeight
    static let ropeTop: CGFloat = 10

    static func center(_ index: Int, count: Int, width: CGFloat) -> CGFloat {
        width / 2 - CGFloat(max(0, count - 1)) * spacing / 2 + CGFloat(index) * spacing
    }

    static func index(at x: CGFloat, count: Int, width: CGFloat) -> Int {
        guard count > 1 else { return 0 }
        let first = center(0, count: count, width: width)
        return Int(min(CGFloat(count - 1), max(0, ((x - first) / spacing).rounded())))
    }

    static func ropeY(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let f = max(0, min(1, x / max(1, width)))
        return ropeTop + 4 * Layout.sag(width: width) * f * (1 - f)
    }
}
