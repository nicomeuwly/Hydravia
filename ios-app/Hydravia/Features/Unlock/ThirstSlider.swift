import HydraviaCore
import SwiftUI

/// "How thirsty are you?" as a column of water the user raises with a thumb:
/// three bands, bottom to top — hydrated, drying out, dry. The water follows
/// the finger, then settles on the band it was released in, with a tick each
/// time it crosses into another. Tapping a band works too, and VoiceOver gets
/// one adjustable element.
///
/// Only the chosen level's label shows, above the track: a thumb coming up
/// from below never covers it.
struct ThirstSlider: View {
    @Binding var feeling: Feeling

    static let levels: [Feeling] = [.fine, .hot, .veryThirsty]

    @State private var dragFraction: Double?
    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 240
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trackWidth: CGFloat = 84

    var body: some View {
        let index = Self.index(of: feeling)
        let fill = dragFraction ?? Self.fillFraction(index)

        VStack(spacing: Spacing.lg) {
            label(selected: index)
            track(fill: fill)
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: feeling)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.unlockThirstLevel))
        .accessibilityValue(Text(Self.label(feeling)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(min(index + 1, Self.levels.count - 1))
            case .decrement: select(max(index - 1, 0))
            @unknown default: break
            }
        }
    }

    // MARK: Track

    private func track(fill: Double) -> some View {
        ZStack(alignment: .bottom) {
            // The water, with a bright meniscus on top.
            LinearGradient(
                colors: [Palette.accentCyan, Palette.waterSurface],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: trackHeight * fill)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: trackWidth * 0.42, height: 4)
                    .padding(.top, 10)
            }

            // Band dividers, faint, so the three steps read at a glance.
            VStack(spacing: 0) {
                ForEach(0..<Self.levels.count, id: \.self) { band in
                    Color.clear
                        .frame(maxHeight: .infinity)
                        .overlay(alignment: .top) {
                            if band > 0 {
                                Rectangle().fill(.white.opacity(0.14)).frame(height: 1)
                            }
                        }
                }
            }
        }
        .frame(width: trackWidth, height: trackHeight)
        .clipShape(.rect(cornerRadius: trackWidth / 2.4, style: .continuous))
        .glassEffect(.clear.tint(.white.opacity(0.06)), in: .rect(cornerRadius: trackWidth / 2.4, style: .continuous))
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let fraction = min(max(1 - value.location.y / trackHeight, 0.08), 1)
                    dragFraction = fraction
                    let band = Self.band(atFraction: fraction)
                    if band != Self.index(of: feeling) { feeling = Self.levels[band] }
                }
                .onEnded { _ in
                    withAnimation(reduceMotion ? nil : Motion.bouncy) { dragFraction = nil }
                }
        )
    }

    // MARK: Label

    /// All three stacked and only the chosen one visible: the height never
    /// changes, so the track doesn't jump when a longer label comes in.
    private func label(selected: Int) -> some View {
        ZStack {
            ForEach(Self.levels.indices, id: \.self) { band in
                Text(Self.label(Self.levels[band]))
                    .font(.brand(.bold, size: 22, relativeTo: .title3))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(band == selected ? 1 : 0)
                    .scaleEffect(band == selected ? 1 : 0.94)
                    .blur(radius: band == selected || reduceMotion ? 0 : 4)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : Motion.base, value: selected)
    }

    // MARK: Model

    private func select(_ band: Int) {
        withAnimation(reduceMotion ? nil : Motion.bouncy) {
            dragFraction = nil
            feeling = Self.levels[band]
        }
    }

    static func index(of feeling: Feeling) -> Int {
        levels.firstIndex(of: feeling) ?? 0
    }

    /// The water fills its band to the top: a third, two thirds, full.
    static func fillFraction(_ band: Int) -> Double {
        Double(band + 1) / Double(levels.count)
    }

    static func band(atFraction fraction: Double) -> Int {
        min(Int(fraction * Double(levels.count)), levels.count - 1)
    }

    static func label(_ feeling: Feeling) -> LocalizedStringResource {
        switch feeling {
        case .fine: .unlockRessentiOk
        case .hot: .unlockRessentiChaud
        case .veryThirsty: .unlockRessentiTresSoif
        }
    }
}

#Preview {
    @Previewable @State var feeling = Feeling.fine
    ThirstSlider(feeling: $feeling)
        .padding(26)
        .background(Palette.waterDeep)
}
