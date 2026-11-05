import SwiftUI
import WidgetKit

// The few tokens the widgets need, mirroring the app's `Palette` and brand
// font (Hydravia/Design/Theme.swift): the extension doesn't compile the
// app's design folder.

enum WidgetPalette {
    static let primaryDark = Color(hex: 0x0B3D5C)
    static let secondaryBlue = Color(hex: 0x1F6E8C)
    static let background = Color(hex: 0xF3F7F9)
    static let textSecondary = Color(hex: 0x5C6F7A)
    static let waterSurface = Color(hex: 0x1A6A8A)
    static let waterDeep = Color(hex: 0x07314A)
    static let amber = Color(hex: 0xDE9A2F)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Font {
    /// Space Grotesk, registered through the extension's `UIAppFonts`.
    enum BrandWeight: String {
        case regular = "SpaceGrotesk-Regular"
        case semiBold = "SpaceGrotesk-SemiBold"
        case bold = "SpaceGrotesk-Bold"
    }

    static func brand(_ weight: BrandWeight, size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
}

/// The water filling a widget to today's progress: a gentle swell on top of
/// a deep gradient, still (widgets don't animate on their own).
struct WaterShape: Shape {
    /// 0...1 of the goal.
    var level: Double

    func path(in rect: CGRect) -> Path {
        // Never quite empty (a strip of water says "this is the water
        // widget"), never over the brim.
        let fill = 0.1 + 0.8 * min(max(level, 0), 1)
        let surface = rect.maxY - rect.height * fill
        let amplitude = min(rect.height * 0.025, 4)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: surface))
        let steps = 48
        for step in 0...steps {
            let x = rect.minX + rect.width * Double(step) / Double(steps)
            let phase = Double(step) / Double(steps) * 2 * .pi
            let y = surface + amplitude * (sin(phase * 1.3 + 0.6) + 0.35 * sin(phase * 2.7 + 1.9))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The water. In full colour, a deep gradient over the widget's light
/// background; tinted or clear (the Home Screen recolours everything and
/// drops the background), a translucent swell in the accent colour, so it
/// still reads as water without hiding the numbers.
struct WaterFill: View {
    var level: Double
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        if mode == .fullColor {
            WaterShape(level: level)
                .fill(LinearGradient(colors: [WidgetPalette.waterSurface, WidgetPalette.waterDeep],
                                     startPoint: .top, endPoint: .bottom))
        } else {
            WaterShape(level: level)
                .fill(.white.opacity(0.28))
                .widgetAccentable()
        }
    }
}

/// The widget's background: the light page and its water.
struct WaterBackground: View {
    var level: Double
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        ZStack {
            if mode == .fullColor { WidgetPalette.background }
            WaterFill(level: level)
        }
    }
}

/// Text that turns white where the water covers it, like the app's header:
/// readable at any level. Tinted or clear, everything is drawn in one
/// colour anyway: a single copy.
struct Waterline<Content: View>: View {
    var level: Double
    @ViewBuilder var content: (_ tint: Color, _ secondary: Color) -> Content
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        if mode == .fullColor {
            ZStack {
                content(WidgetPalette.primaryDark, WidgetPalette.textSecondary)
                content(.white, .white.opacity(0.8))
                    .mask { WaterShape(level: level) }
            }
        } else {
            content(.white, .white.opacity(0.75))
        }
    }
}

/// A white surface (button, plate) that stays one: tinted or clear, an
/// opaque white would be drawn over its own label, so it turns into a veil.
struct Plate<S: Shape>: View {
    var shape: S
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        shape.fill(.white.opacity(mode == .fullColor ? 1 : 0.16))
    }
}

/// The ink on a plate: dark blue in full colour, white once recoloured.
struct PlateInk {
    let mode: WidgetRenderingMode
    var primary: Color { mode == .fullColor ? WidgetPalette.primaryDark : .white }
    var secondary: Color { mode == .fullColor ? WidgetPalette.textSecondary : .white.opacity(0.75) }
}

/// A drop filling up with today's progress: what says "Hydravia" once a
/// tinted or clear Home Screen has taken the water away. A hard-edged
/// gradient fills it from the bottom (a mask would leave a ghost frame).
struct DropGauge: View {
    var level: Double
    var tint: Color
    var size: CGFloat = 30

    var body: some View {
        let surface = 1 - min(max(level, 0), 1)
        Image(systemName: "drop.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(LinearGradient(stops: [
                .init(color: tint.opacity(0.3), location: 0),
                .init(color: tint.opacity(0.3), location: surface),
                .init(color: tint, location: surface),
                .init(color: tint, location: 1),
            ], startPoint: .top, endPoint: .bottom))
            .widgetAccentable()
            .accessibilityHidden(true)
    }
}
