import SwiftUI

// MARK: - Pressable

/// The app-wide touch response: a quick spring scale-down on touch, released
/// with the same spring. Applied to every tappable surface that isn't a system
/// control, so the whole app feels physically consistent.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = Motion.pressScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

// MARK: - Primary button

/// Full-width call to action. `filled` is the dark brand button on light
/// backgrounds; `light` is the white button that sits on dark water (home
/// screen bottom, unlock ritual).
struct PrimaryButtonStyle: ButtonStyle {
    enum Variant { case filled, light }

    var variant: Variant = .filled
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.brand(.bold, size: 17, relativeTo: .headline))
            .foregroundStyle(variant == .filled ? Color.white : Palette.primaryDark)
            .frame(maxWidth: .infinity, minHeight: ControlHeight.primary)
            .contentShape(.rect(cornerRadius: Radius.md, style: .continuous))
            .background(
                variant == .filled ? Palette.primaryDark : Color.white,
                in: .rect(cornerRadius: Radius.md, style: .continuous)
            )
            .shadow(color: Palette.waterDeep.opacity(variant == .light ? 0.28 : 0.12), radius: 15, y: 10)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? Motion.pressScale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primaryLight: PrimaryButtonStyle { PrimaryButtonStyle(variant: .light) }
}

// MARK: - Glass card

/// A surface floating on the water. Native Liquid Glass picks up the colour of
/// the water behind it and refracts the waves as they pass — the effect the
/// Expo app could only fake with a blur and a translucent fill.
///
/// `legibility` raises the white tint for cards that end up fully submerged
/// (the stats card once the goal is reached), where plain glass let the dark
/// water wash out secondary text.
struct GlassCardModifier: ViewModifier {
    var radius: CGFloat
    var legibility: Double
    var interactive: Bool

    func body(content: Content) -> some View {
        content.glassEffect(
            interactive
                ? .regular.tint(.white.opacity(legibility)).interactive()
                : .regular.tint(.white.opacity(legibility)),
            in: .rect(cornerRadius: radius, style: .continuous)
        )
    }
}

extension View {
    func glassCard(radius: CGFloat = Radius.lg, legibility: Double = 0.55, interactive: Bool = false) -> some View {
        modifier(GlassCardModifier(radius: radius, legibility: legibility, interactive: interactive))
    }
}
