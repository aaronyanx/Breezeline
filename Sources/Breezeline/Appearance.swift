import AppKit
import CoreText
import SwiftUI

enum Handwriting {
    static func register() {
        for name in ["Caveat", "LongCang-Regular"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    static func font(_ size: CGFloat) -> Font {
        let descriptor = NSFontDescriptor(fontAttributes: [
            .name: "Caveat-Regular",
            .cascadeList: [NSFontDescriptor(name: "LongCang-Regular", size: size)],
        ])
        if let font = NSFont(descriptor: descriptor, size: size) {
            return Font(font)
        }
        return .custom("Caveat-Regular", size: size)
    }
}

struct PaperSurface: View {
    let color: Int
    private static let texture = Bundle.main.url(forResource: "natural-paper", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }

    var body: some View {
        paperColor(color)
            .overlay {
                if let texture = Self.texture {
                    Image(nsImage: texture)
                        .resizable(resizingMode: .tile)
                        .blendMode(.multiply)
                        .opacity(0.82)
                }
            }
            .overlay {
                LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.035)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

func paperColor(_ index: Int) -> Color {
    [
        Color(red: 0.97, green: 0.94, blue: 0.82),
        Color(red: 0.87, green: 0.93, blue: 0.85),
        Color(red: 0.97, green: 0.88, blue: 0.85),
        Color(red: 0.87, green: 0.93, blue: 0.97),
    ][max(0, min(3, index))]
}

func phosphorIcon(_ name: String) -> some View {
    let image = Bundle.main.url(forResource: name, withExtension: "svg")
        .flatMap { NSImage(contentsOf: $0) } ?? NSImage(size: NSSize(width: 1, height: 1))
    return Image(nsImage: image).renderingMode(.template).resizable().scaledToFit()
}

extension View {
    @ViewBuilder func noteGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular,
                        in: .rect(cornerRadius: cornerRadius))
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder func glassDoneButton() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        } else {
            buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }
}
