import SwiftUI

// The single source of design tokens. Values mirror the Expo theme
// (hydravia/src/theme/index.ts) so both apps share one identity: deep-blue
// palette, Space Grotesk, frosted surfaces floating on water.
//
// Light-only for now (Info.plist forces it), but every colour is read through
// `Palette`, so a dark variant is one place to change, not a hunt.

// MARK: - Colour

nonisolated enum Palette {
    static let primaryDark = Color(hex: 0x0B3D5C)
    static let secondaryBlue = Color(hex: 0x1F6E8C)
    static let accentCyan = Color(hex: 0x3E9BC7)
    static let background = Color(hex: 0xF3F7F9)
    static let backgroundElement = Color(hex: 0xEAF1F4)
    static let textPrimary = Color(hex: 0x0C1C26)
    static let textSecondary = Color(hex: 0x5C6F7A)
    static let textTertiary = Color(hex: 0x9DAAB2)
    static let border = Color(hex: 0xEBF0F2)
    static let amber = Color(hex: 0xDE9A2F)
    static let amberDeep = Color(hex: 0xBC6418)
    static let error = Color(hex: 0xD93025)
    static let success = Color(hex: 0x2E7D32)
    static let sunlight = Color(hex: 0xFFD27A)

    // Water rendering, shared by the home and unlock backgrounds.
    static let waterSurface = Color(hex: 0x1A6A8A)
    static let waterDeep = Color(hex: 0x07314A)
    static let nightOverlay = Color(red: 7 / 255, green: 20 / 255, blue: 30 / 255).opacity(0.38)
}

extension Color {
    /// sRGB colour from a 0xRRGGBB literal.
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Typography

/// Space Grotesk, scaled with Dynamic Type: every size is anchored to a system
/// text style, so accessibility sizes keep working with the brand font.
enum BrandFont: String, CaseIterable {
    case regular = "SpaceGrotesk-Regular"
    case medium = "SpaceGrotesk-Medium"
    case semiBold = "SpaceGrotesk-SemiBold"
    case bold = "SpaceGrotesk-Bold"
}

extension Font {
    static func brand(_ weight: BrandFont, size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    // The type scale used across screens. Named by role, not by size, so a
    // screen never hardcodes a number.
    static let displayNumber = brand(.bold, size: 46, relativeTo: .largeTitle)
    static let screenTitle = brand(.bold, size: 26, relativeTo: .title)
    static let sectionTitle = brand(.bold, size: 20, relativeTo: .title3)
    static let cardTitle = brand(.bold, size: 18, relativeTo: .headline)
    static let bodyEmphasis = brand(.semiBold, size: 17, relativeTo: .body)
    static let bodyRegular = brand(.regular, size: 16, relativeTo: .body)
    static let brandCaption = brand(.semiBold, size: 13, relativeTo: .caption)
    static let brandFootnote = brand(.regular, size: 14, relativeTo: .footnote)
    static let eyebrow = brand(.bold, size: 13, relativeTo: .caption)
}

// MARK: - Metrics

enum Radius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 28
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let screen: CGFloat = 22
}

enum ControlHeight {
    static let primary: CGFloat = 58
    static let unlock: CGFloat = 60
}

// MARK: - Motion

/// One motion vocabulary for the whole app. `press` mimics UIKit's responsive
/// touch-down; `gentle` settles layout; `bouncy` is reserved for celebratory
/// moments (goal reached, unlock). Same mass/stiffness/damping as the
/// Reanimated springs they replace.
enum Motion {
    static let press = Animation.interpolatingSpring(mass: 0.6, stiffness: 320, damping: 18)
    static let gentle = Animation.interpolatingSpring(mass: 1, stiffness: 180, damping: 22)
    static let bouncy = Animation.interpolatingSpring(mass: 1, stiffness: 160, damping: 12)

    static let fast = Animation.easeOut(duration: 0.18)
    static let base = Animation.easeInOut(duration: 0.28)
    static let slow = Animation.easeInOut(duration: 0.45)
    /// Rolling counters (consumed mL, dose).
    static let count = Animation.easeOut(duration: 0.65)
    /// The water level settling after an addition.
    static let level = Animation.timingCurve(0.33, 1, 0.68, 1, duration: 1.1)

    static let pressScale: CGFloat = 0.97
}
