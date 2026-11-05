import SwiftUI

// The few tokens the watch needs, mirroring the app's `Palette` and brand
// font (Hydravia/Design/Theme.swift): the watch doesn't compile the app's
// design folder.

enum WatchPalette {
    static let waterSurface = Color(hex: 0x1A6A8A)
    static let waterDeep = Color(hex: 0x07314A)
    static let secondaryBlue = Color(hex: 0x1F6E8C)
    static let foam = Color(hex: 0x5FC8D9)
    static let amber = Color(hex: 0xDE9A2F)
    static let track = Color.white.opacity(0.16)

    /// Behind every screen: deep water.
    static let background = LinearGradient(colors: [waterSurface.opacity(0.55), waterDeep.opacity(0.35)],
                                            startPoint: .top, endPoint: .bottom)
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
    /// Space Grotesk, registered through the app's `UIAppFonts`.
    enum BrandWeight: String {
        case regular = "SpaceGrotesk-Regular"
        case semiBold = "SpaceGrotesk-SemiBold"
        case bold = "SpaceGrotesk-Bold"
    }

    static func brand(_ weight: BrandWeight, size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
}
