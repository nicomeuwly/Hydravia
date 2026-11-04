import HydraviaCore
import HydraviaData
import SwiftUI

// MARK: - Welcome

/// The first screen is already the product: the phone is a glass, half full.
struct WelcomeStep: View {
    let onStart: () -> Void

    @State private var physics = WaterPhysics()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            LiveWater(physics: physics, isActive: scenePhase == .active)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.xl) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Palette.primaryDark, in: .rect(cornerRadius: Radius.lg, style: .continuous))
                    .padding(.top, Spacing.xxxl)
                    .accessibilityHidden(true)

                Text(.welcomeHeadline)
                    .font(.brand(.bold, size: 44, relativeTo: .largeTitle))
                    .kerning(-1)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(.welcomeBody)
                    .font(.bodyRegular)
                    .foregroundStyle(Palette.textSecondary)

                Spacer()

                Button(action: onStart) { Text(.welcomeCta) }
                    .buttonStyle(.primaryLight)
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.lg)
        }
        .onAppear { physics.setLevel(0.42, splash: false) }
    }
}

// MARK: - Weight

struct WeightStep: View {
    let onNext: () -> Void
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        OnboardingScaffold(step: .weight, title: .weightTitle, subtitle: .weightSubtitle,
                           primary: .commonContinue, onPrimary: onNext) {
            VStack(spacing: Spacing.md) {
                WeightPicker(weightKg: $settings.settings.weightKg)
                    .frame(height: 180)
                    .padding(.horizontal, Spacing.lg)
                    .background(.white, in: .rect(cornerRadius: Radius.xl, style: .continuous))

                HStack {
                    Text(.weightGoalLabel)
                        .font(.eyebrow)
                        .kerning(1.2)
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text("\(settings.dailyGoalMl.formatted()) \(String(localized: .commonMl))")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.primaryDark)
                        .contentTransition(.numericText(value: Double(settings.dailyGoalMl)))
                        .animation(Motion.count, value: settings.dailyGoalMl)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.lg)
                .background(Palette.backgroundElement, in: .rect(cornerRadius: Radius.lg, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Schedule

struct ScheduleStep: View {
    let onNext: () -> Void
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        OnboardingScaffold(step: .schedule, title: .scheduleTitle, subtitle: .scheduleSubtitle,
                           primary: .commonContinue, onPrimary: onNext) {
            ActiveWindowEditor(window: $settings.settings.window)
        }
    }
}

// MARK: - Interval

struct IntervalStep: View {
    let onNext: () -> Void
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        let window = settings.settings.window

        OnboardingScaffold(step: .interval, title: .intervalTitle, subtitle: .intervalSubtitle,
                           primary: .commonContinue, onPrimary: onNext) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                IntervalPicker(minutes: $settings.settings.window.intervalMin)
                Text(.intervalSummary(window.reminderSlots.count, window.wake.formatted, window.sleep.formatted))
                    .font(.brandFootnote)
                    .foregroundStyle(Palette.textSecondary)
                    .contentTransition(.numericText())
                    .animation(Motion.base, value: window.intervalMin)
            }
        }
    }
}

// MARK: - Location

struct LocationStep: View {
    let onNext: () -> Void
    @Environment(LocationPermission.self) private var location
    @State private var waitingForAnswer = false

    var body: some View {
        OnboardingScaffold(step: .location, title: .locationTitle, subtitle: .locationBody,
                           primary: .locationAllow, secondary: .commonLater,
                           onPrimary: allow, onSecondary: onNext) {
            HStack(spacing: Spacing.md) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.amber)
                    .frame(width: 44, height: 44)
                    .background(Palette.amber.opacity(0.12), in: .rect(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(.locationToday)
                        .font(.brandCaption)
                        .foregroundStyle(Palette.textSecondary)
                    Text(.locationExample)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                    Text(.locationDoseBadge)
                        .font(.brand(.bold, size: 11, relativeTo: .caption2))
                        .kerning(0.8)
                        .foregroundStyle(Palette.amberDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Palette.amber.opacity(0.15), in: .capsule)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.lg)
            .background(.white, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        }
        // The system prompt answers asynchronously: move on once it has.
        .onChange(of: location.status) { _, new in
            if waitingForAnswer, new != .notDetermined { onNext() }
        }
    }

    private func allow() {
        guard location.status == .notDetermined else { return onNext() }
        waitingForAnswer = true
        location.requestOrOpenSettings()
    }
}

// MARK: - Notifications

/// Asks for notifications only on an explicit tap: iOS shows its prompt once,
/// so burning it on a low-intent screen would lose it for good.
struct NotificationsStep: View {
    let onGranted: () -> Void
    let onDeclined: () -> Void
    @Environment(SettingsStore.self) private var settings
    @Environment(\.reminders) private var reminders

    var body: some View {
        OnboardingScaffold(step: .notifications, title: .notifPrimeTitle, subtitle: .notifPrimeBody,
                           primary: .notifPrimeActivate, secondary: .commonLater,
                           onPrimary: activate, onSecondary: onDeclined) {
            NotificationPreview()
        }
    }

    private func activate() {
        Task {
            let granted: Bool
            switch await reminders?.permission() ?? .denied {
            case .granted: granted = true
            case .notDetermined: granted = await reminders?.requestPermission() ?? false
            case .denied: granted = false
            }
            settings.settings.notificationsEnabled = granted
            granted ? onGranted() : onDeclined()
        }
    }
}

/// What a reminder looks like — the same copy the real one uses.
private struct NotificationPreview: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "drop.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Palette.primaryDark, in: .rect(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "Hydravia").font(.system(.subheadline, weight: .semibold))
                    Spacer()
                    Text(.commonNow).font(.system(.caption)).foregroundStyle(.secondary)
                }
                Text(.notifReminderBody1).font(.system(.subheadline))
            }
        }
        .padding(Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct NotificationsRecoverStep: View {
    let onNext: () -> Void
    @Environment(SettingsStore.self) private var settings
    @Environment(\.reminders) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @State private var sentToSettings = false

    var body: some View {
        OnboardingScaffold(step: .notificationsRecover, title: .notifRecoverTitle, subtitle: .notifRecoverBody,
                           primary: .notifRecoverActivate, secondary: .notifRecoverSkip,
                           onPrimary: activate, onSecondary: onNext) {
            HStack(spacing: 14) {
                comparison(level: 0.86, title: .notifRecoverWithReminders, days: 6, muted: false)
                comparison(level: 0.22, title: .notifRecoverWithoutReminders, days: 2, muted: true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { recheckAfterSettings() }
        }
    }

    private func comparison(level: Double, title: LocalizedStringResource, days: Int, muted: Bool) -> some View {
        VStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(Palette.backgroundElement)
                .frame(width: 46, height: 62)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(LinearGradient(colors: [Palette.waterSurface, Palette.waterDeep],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: 62 * level)
                }
                .clipShape(.rect(cornerRadius: Radius.sm, style: .continuous))
            Text(title)
                .font(.brandCaption)
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(days, format: .number)
                    .font(.brand(.bold, size: 30, relativeTo: .title))
                    .foregroundStyle(muted ? Palette.textTertiary : Palette.primaryDark)
                Text(.notifRecoverOutOfSevenDays)
                    .font(.brand(.medium, size: 14, relativeTo: .footnote))
                    .foregroundStyle(Palette.textTertiary)
            }
            Text(.notifRecoverGoalHit)
                .font(.brandFootnote)
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(.white, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func activate() {
        Task {
            switch await reminders?.permission() ?? .denied {
            case .granted:
                settings.settings.notificationsEnabled = true
                onNext()
            case .notDetermined:
                let granted = await reminders?.requestPermission() ?? false
                settings.settings.notificationsEnabled = granted
                onNext()
            case .denied:
                // iOS won't ask again: the switch lives in Settings now.
                sentToSettings = true
                LocationPermission.openSettings()
            }
        }
    }

    /// Back from iOS Settings with notifications turned on: carry on.
    private func recheckAfterSettings() {
        guard sentToSettings else { return }
        Task {
            if await reminders?.permission() == .granted {
                sentToSettings = false
                settings.settings.notificationsEnabled = true
                onNext()
            }
        }
    }
}

// MARK: - Goal reveal

/// The payoff: the computed goal rising in a glass of water, with the
/// rhythm it implies.
struct GoalRevealStep: View {
    let onNext: () -> Void
    @Environment(SettingsStore.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var physics = WaterPhysics()
    @State private var shownGoal = 0
    @State private var revealed = false

    var body: some View {
        let window = settings.settings.window

        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(.goalRevealEyebrow)
                    .font(.eyebrow)
                    .kerning(1.5)
                    .foregroundStyle(Palette.accentCyan)
                Text(.goalRevealTitle)
                    .font(.brand(.bold, size: 30, relativeTo: .largeTitle))
                    .kerning(-0.7)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.top, Spacing.xxl)

            ZStack {
                Palette.backgroundElement
                LiveWater(physics: physics, isActive: scenePhase == .active)
                VStack(spacing: 4) {
                    Text(.goalRevealGoalLabel)
                        .font(.eyebrow)
                        .kerning(1.2)
                        .foregroundStyle(Palette.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(shownGoal, format: .number)
                            .font(.displayNumber)
                            .foregroundStyle(Palette.primaryDark)
                            .contentTransition(.numericText(value: Double(shownGoal)))
                        Text(.commonMl)
                            .font(.brand(.medium, size: 18, relativeTo: .headline))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, Spacing.xl)
                .glassCard(radius: Radius.xl, legibility: 0.85)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(.goalRevealGoalLabel))
                .accessibilityValue("\(settings.dailyGoalMl.formatted()) \(String(localized: .commonMl))")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipShape(.rect(cornerRadius: Radius.xxl, style: .continuous))
            .scaleEffect(revealed ? 1 : 0.9)
            .opacity(revealed ? 1 : 0)

            HStack(spacing: Spacing.md) {
                metric("\(window.reminderSlots.count)", label: .goalRevealRemindersPerDay)
                metric(ReminderInterval(rawValue: window.intervalMin)?.shortLabel ?? "—", label: .goalRevealPace)
                metric(window.wake.formatted, label: .goalRevealStart)
            }

            Spacer()

            Button(action: onNext) {
                Text(.commonContinue)
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.lg)
        .background(Palette.background)
        .onAppear {
            physics.setLevel(0.72, splash: false)
            withAnimation(reduceMotion ? nil : Motion.bouncy) { revealed = true }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.9).delay(0.25)) {
                shownGoal = settings.dailyGoalMl
            }
        }
        .sensoryFeedback(.success, trigger: revealed)
    }

    private func metric(_ value: String, label: LocalizedStringResource) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.brand(.bold, size: 20, relativeTo: .title3))
                .foregroundStyle(Palette.primaryDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.brandFootnote)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(.white, in: .rect(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
