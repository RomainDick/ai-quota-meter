import AppKit
import SwiftUI

struct GaugeItem {
    let letter: String
    let percent: Double
    let color: Color
    let stale: Bool
}

enum MenuLabel {
    case image(NSImage)
    case text(String)
    case idle
}

struct GaugeStrip: View {
    private static let barHeight: CGFloat = 14
    private static let barWidth: CGFloat = 5
    let items: [GaugeItem]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 2) {
                    Text(item.letter)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(item.color)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 1.5).fill(Color.gray.opacity(0.35))
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(item.color)
                            .frame(height: max(1.5, Self.barHeight * min(item.percent, 100) / 100))
                    }
                    .frame(width: Self.barWidth, height: Self.barHeight)
                }
                .opacity(item.stale ? 0.5 : 1)
            }
        }
        .frame(height: 18)
    }
}

enum MenuBarImage {
    @MainActor
    static func render(_ items: [GaugeItem]) -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let renderer = ImageRenderer(content: GaugeStrip(items: items))
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale))
        image.isTemplate = false
        return image
    }
}
