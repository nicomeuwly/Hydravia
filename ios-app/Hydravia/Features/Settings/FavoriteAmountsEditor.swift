import HydraviaCore
import HydraviaData
import SwiftUI

/// The three add-water presets, each nudged 10 ml (or one fluid ounce) at a
/// time (hold to run).
/// Saving sorts them, so the add sheet always reads smallest to largest.
struct FavoriteAmountsEditor: View {
    @Binding var amounts: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(amounts.indices, id: \.self) { index in
                AmountStepperCard(position: index + 1, ml: $amounts[index])
            }
            Text(.settingsFavoritesHint)
                .font(.brandFootnote)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, Spacing.xs)
        }
    }
}

private struct AmountStepperCard: View {
    let position: Int
    @Binding var ml: Int
    @Environment(SettingsStore.self) private var settings

    private let range = UserSettings.favoriteRangeMl
    private var units: UnitSystem { settings.unitSystem }

    /// `ml` moved by `steps` nudges, in the user's units.
    private func moved(_ steps: Int) -> Int {
        units.stepped(ml: ml, by: steps, metricStep: UserSettings.favoriteStepMl)
    }

    var body: some View {
        HStack(spacing: Spacing.lg) {
            BottleGlyph(fill: BottleGlyph.fill(forMl: ml), width: 30, height: 44)
                .animation(Motion.gentle, value: ml)

            Text(verbatim: units.volume(ml: ml))
                .font(.brand(.bold, size: 22, relativeTo: .title3))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText(value: Double(ml)))
                .frame(maxWidth: .infinity, alignment: .leading)
                // VoiceOver: one adjustable element (swipe up / down).
                .accessibilityLabel(Text(.settingsFavoriteA11Y(position)))
                .accessibilityValue(Text(verbatim: units.volume(ml: ml)))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: nudge(1)
                    case .decrement: nudge(-1)
                    @unknown default: break
                    }
                }

            stepButton("minus", delta: -1, label: .commonDecrease)
            stepButton("plus", delta: 1, label: .commonIncrease)
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.xl)
        .background(.white, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func stepButton(_ symbol: String, delta: Int, label: LocalizedStringResource) -> some View {
        let allowed = range.contains(moved(delta))
        return Button {
            nudge(delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.primaryDark)
                .frame(width: 44, height: 44)
                .background(Palette.backgroundElement, in: .circle)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .accessibilityLabel(Text(label))
        .disabled(!allowed)
        .opacity(allowed ? 1 : 0.35)
        .buttonRepeatBehavior(.enabled)
        .sensoryFeedback(.selection, trigger: ml)
    }

    private func nudge(_ delta: Int) {
        let next = moved(delta)
        guard range.contains(next) else { return }
        withAnimation(Motion.fast) { ml = next }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var amounts = [200, 330, 500]
    FavoriteAmountsEditor(amounts: $amounts)
        .padding()
        .background(Palette.background)
        .injecting(AppDependencies.preview())
}
#endif
