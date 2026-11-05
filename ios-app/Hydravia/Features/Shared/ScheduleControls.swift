import HydraviaCore
import HydraviaData
import SwiftUI

// Controls shared by the settings sheets and the onboarding steps, so both
// edit the active window, the cadence and the weight the same way.

// MARK: - Time stepper

/// One end of the active window, nudged in 15-minute steps.
struct TimeStepperCard: View {
    static let step = 15

    let title: LocalizedStringResource
    let icon: String
    @Binding var minute: MinuteOfDay
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: Spacing.md) {
            Label { Text(title) } icon: { Image(systemName: icon) }
                .font(.brandCaption)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true) // carried by the time's label

            HStack(spacing: Spacing.lg) {
                stepButton("minus", delta: -Self.step, label: .scheduleA11YEarlier)
                Text(minute.formatted)
                    .font(.brand(.bold, size: 32, relativeTo: .title))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText(value: Double(minute.value)))
                    .frame(minWidth: 96)
                    // VoiceOver: one adjustable element (swipe up / down).
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(minute.formatted)
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: nudge(Self.step)
                        case .decrement: nudge(-Self.step)
                        @unknown default: break
                        }
                    }
                stepButton("plus", delta: Self.step, label: .scheduleA11YLater)
            }
        }
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        // The buttons stay in the tree, named, so Voice Control and Switch
        // Control can reach them too.
        .accessibilityElement(children: .contain)
    }

    private func stepButton(_ symbol: String, delta: Int, label: LocalizedStringResource) -> some View {
        let next = minute.value + delta
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
        .disabled(!range.contains(next))
        .opacity(range.contains(next) ? 1 : 0.35)
        .buttonRepeatBehavior(.enabled)
        .sensoryFeedback(.selection, trigger: minute)
    }

    private func nudge(_ delta: Int) {
        let next = minute.value + delta
        guard range.contains(next) else { return }
        withAnimation(Motion.press) { minute = MinuteOfDay(next) }
    }
}

extension MinuteOfDay {
    /// Localised clock time ("07:30", "7:30 AM"). Formatted from a fixed
    /// reference in GMT, so no daylight-saving gap can shift it.
    var formatted: String {
        Date(timeIntervalSinceReferenceDate: Double(value) * 60)
            .formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: .gmt))
    }
}

/// Wake and sleep steppers, kept at least one step apart, with the summary
/// and the midnight note for night owls.
struct ActiveWindowEditor: View {
    @Binding var window: ActiveWindow

    var body: some View {
        VStack(spacing: Spacing.md) {
            TimeStepperCard(
                title: .scheduleWake, icon: "sunrise.fill",
                minute: $window.wake,
                range: Self.range(0, window.sleep.value - TimeStepperCard.step)
            )
            TimeStepperCard(
                title: .scheduleSleep, icon: "moon.stars.fill",
                minute: $window.sleep,
                range: Self.range(window.wake.value + TimeStepperCard.step, ActiveWindow.latestSleep.value)
            )

            Text(.settingsScheduleSummary(window.wake.formatted, window.sleep.formatted, hoursLabel))
                .font(.brandFootnote)
                .foregroundStyle(Palette.textSecondary)
                .contentTransition(.numericText())
                .padding(.top, Spacing.xs)

            if ActiveWindow.isLateBedtime(window.sleep) {
                Text(.scheduleMidnightNote)
                    .font(.brandFootnote)
                    .foregroundStyle(Palette.amberDeep)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(Motion.gentle, value: ActiveWindow.isLateBedtime(window.sleep))
    }

    /// Never an inverted range (which would trap), whatever the window.
    private static func range(_ lower: Int, _ upper: Int) -> ClosedRange<Int> {
        lower...max(lower, upper)
    }

    private var hoursLabel: String {
        let hours = Double(window.sleep.value - window.wake.value) / 60
        return hours.formatted(.number.precision(.fractionLength(0...1)))
    }
}

// MARK: - Interval

/// The three reminder cadences.
enum ReminderInterval: Int, CaseIterable, Identifiable {
    case hourly = 60
    case ninetyMinutes = 90
    case twoHours = 120

    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .hourly: .intervalEvery1H
        case .ninetyMinutes: .intervalEvery1H30
        case .twoHours: .intervalEvery2H
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .hourly: .intervalMostRegular
        case .ninetyMinutes: .intervalBalanced
        case .twoHours: .intervalDiscreet
        }
    }

    /// Short label for a settings row ("1 h", "1 h 30", "2 h").
    var shortLabel: String {
        Duration.seconds(rawValue * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}

struct IntervalPicker: View {
    @Binding var minutes: Int

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(ReminderInterval.allCases) { option in
                let selected = option.rawValue == minutes
                Button {
                    withAnimation(Motion.press) { minutes = option.rawValue }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.cardTitle)
                                .foregroundStyle(selected ? .white : Palette.textPrimary)
                            Text(option.subtitle)
                                .font(.brandFootnote)
                                .foregroundStyle(selected ? .white.opacity(0.7) : Palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(selected ? .white : Palette.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.lg)
                    .background(selected ? Palette.primaryDark : .white,
                                in: .rect(cornerRadius: Radius.lg, style: .continuous))
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: minutes)
    }
}

// MARK: - Weight

struct WeightPicker: View {
    static let range = UserSettings.weightRangeKg
    @Binding var weightKg: Int

    var body: some View {
        Picker(selection: $weightKg) {
            ForEach(Self.range, id: \.self) { kg in
                Text(Measurement(value: Double(kg), unit: UnitMass.kilograms),
                     format: .measurement(width: .abbreviated, usage: .asProvided))
                    .tag(kg)
            }
        } label: {
            Text(.weightCardLabel)
        }
        .pickerStyle(.wheel)
        .accessibilityLabel(Text(.weightA11YSlider))
    }
}
