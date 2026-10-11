import SwiftUI

enum Layout {
    static let panelHeight: CGFloat = 380
    static let ropeTop: CGFloat = 10
    static let spacing: CGFloat = 292
    static let cardWidth: CGFloat = 260
    static let cardHeight: CGFloat = 232
    static let pinAbove: CGFloat = 9.5

    /// The rope hangs as a parabola from edge to edge of the screen.
    static func sag(width: CGFloat) -> CGFloat { min(56, width * 0.032) }

    static func ropeY(x: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return ropeTop }
        let f = x / width
        return ropeTop + 4 * sag(width: width) * f * (1 - f)
    }

    static func x(index: Int, count: Int, width: CGFloat) -> CGFloat {
        let total = CGFloat(max(count - 1, 0)) * spacing
        return width / 2 - total / 2 + CGFloat(index) * spacing
    }

    static func index(at x: CGFloat, count: Int, width: CGFloat) -> Int {
        guard count > 1 else { return 0 }
        let first = Self.x(index: 0, count: count, width: width)
        let slot = ((x - first) / spacing).rounded()
        return Int(min(CGFloat(count - 1), max(0, slot)))
    }
}

struct LineView: View {
    @ObservedObject var line: Line
    @State private var dragOriginX: CGFloat?
    @State private var draggedX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let width = line.displayWidth(geo.size.width)
            ScrollView(.horizontal, showsIndicators: false) {
              ZStack(alignment: .topLeading) {
                Rope(width: width)

                if line.items.isEmpty {
                    Hint()
                        .position(x: width / 2, y: Layout.ropeY(x: width / 2, width: width) + 34)
                        .transition(.opacity)
                }

                ForEach(Array(line.items.enumerated()), id: \.element.id) { index, item in
                    let restingX = line.x(index: index, width: width)
                    let moving = line.reorderingID == item.id
                    let x = moving ? (draggedX ?? restingX) : restingX
                    let ropeY = Layout.ropeY(x: x, width: width)
                    PeggedView(item: item, line: line, onClipDrag: { translation in
                        if let translation {
                            if line.reorderingID != item.id {
                                dragOriginX = restingX
                                line.reorderingID = item.id
                            }
                            let margin: CGFloat = item.note != nil ? NoteLayout.cardWidth / 2 : Layout.cardWidth / 2
                            draggedX = min(max(margin, (dragOriginX ?? restingX) + translation),
                                           max(margin, width - margin))
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if line.reorderingID == item.id, let draggedX {
                                    line.move(item.id, to: line.slot(at: draggedX, width: width))
                                }
                                line.reorderingID = nil
                                dragOriginX = nil
                                draggedX = nil
                            }
                        }
                    })
                        .frame(width: item.note == nil ? Layout.cardWidth : 220,
                               height: Layout.panelHeight - ropeY, alignment: .top)
                        .position(x: x, y: ropeY - Layout.pinAbove + (Layout.panelHeight - ropeY) / 2)
                        .zIndex(moving ? 1 : 0)
                }
            }
            .frame(width: width, height: Layout.panelHeight)
            .animation(.spring(response: 0.55, dampingFraction: 0.78), value: line.items.map(\.id))
            .animation(.easeInOut(duration: 0.3), value: line.items.isEmpty)
            }
            .scrollDisabled(line.reorderingID != nil)
            .overlay(alignment: .topLeading) {
                if line.notesAvailable {
                    Button(action: line.onNewNote) {
                        phosphorIcon("plus").frame(width: 12, height: 12)
                            .frame(width: 28, height: 28)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("New Note")
                    .accessibilityLabel("New Note")
                    .position(x: geo.size.width - 24,
                              y: Layout.ropeY(x: geo.size.width - 24, width: geo.size.width) + 24)
                }
            }
            // Tucked away, the whole line waits above the top edge and slides
            // out from under the menu bar, the way an auto-hiding Dock does.
            .offset(y: line.revealed ? 0 : -(Layout.panelHeight + 12))
            .animation(line.revealed ? .spring(response: 0.42, dampingFraction: 0.82)
                                     : .easeIn(duration: 0.22), value: line.revealed)
        }
        .onPreferenceChange(HitRectsKey.self) { rects in
            line.hitRects = rects
        }
        .onPreferenceChange(ClipHitRectsKey.self) { rects in
            line.clipHitRects = rects
        }
        .coordinateSpace(.named("line"))
    }
}

private struct Hint: View {
    var body: some View {
        Text("Take a screenshot, copy an image, or add a note")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
    }
}

/// A thin, neutral line: a mid gray core with a faint highlight and a soft
/// shadow, so it reads on light and dark backgrounds alike. It fades out at
/// both ends so it seems to come from beyond the screen.
struct Rope: View {
    let width: CGFloat

    private var path: Path {
        Path { p in
            let top = Layout.ropeTop
            p.move(to: CGPoint(x: -20, y: top))
            p.addQuadCurve(
                to: CGPoint(x: width + 20, y: top),
                control: CGPoint(x: width / 2, y: top + 2 * Layout.sag(width: width)))
        }
    }

    var body: some View {
        ZStack {
            path.stroke(Color.black.opacity(0.22), lineWidth: 1.4).offset(y: 1.2).blur(radius: 1.2)
            path.stroke(Color(white: 0.55), lineWidth: 1.2)
            path.stroke(Color.white.opacity(0.45), lineWidth: 0.4).offset(y: -0.35)
        }
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 0.92),
                .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
        )
        .allowsHitTesting(false)
    }
}

struct HitRectsKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct ClipHitRectsKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
