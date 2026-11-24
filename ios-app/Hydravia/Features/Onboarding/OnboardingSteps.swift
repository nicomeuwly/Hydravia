import HydraviaCore
import HydraviaData
import SwiftUI

// MARK: - Welcome

/// The first screen is already the product: the phone is a glass, half full.
struct WelcomeStep: View {
    let onStart: () -> Void

    @State private var physics = WaterPhysics()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Lower at accessibility sizes, where the text runs further down and
    /// grey on dark water would be unreadable.
    private var waterLevel: Double { typeSize.isAccessibilitySize ? 0.16 : 0.42 }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            LiveWater(physics: physics, isActive: scenePhase == .active)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Scrolls only at large text sizes, so the button below can
                // never be pushed off screen.
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        AppLogo(size: 64)
                            .padding(.top, Spacing.xxxl)

                        Text(.welcomeHeadline)
                            .font(.brand(.bold, size: 44, relativeTo: .largeTitle))
                            .kerning(-1)
                            .foregroundStyle(Palette.textPrimary)
                            // Three one-word lines: shrink rather than break a word.
                            .lineLimit(3)
                            .minimumScaleFactor(0.5)
                            .accessibilityAddTraits(.isHeader)
                        Text(.welcomeBody)
                            .font(.bodyRegular)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Lets the last line scroll clear of the wave.
                    .padding(.bottom, typeSize.isAccessibilitySize ? 80 : 0)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)

                Button(action: onStart) { Text(.welcomeCta) }
                    .buttonStyle(.primaryLight)
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.lg)
        }
        .onAppear { physics.setLevel(waterLevel, splash: false) }
        .onChange(of: waterLevel) { _, level in physics.setLevel(level, splash: false) }
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

// MARK: - Notifications

/// Explains reminders, then "Continue" shows the system prompt: declining
/// happens there, never on our screen (App Review guideline 5.1.1(iv)).
struct NotificationsStep: View {
    /// Called with the answer: a decline leads to the recovery screen.
    let onNext: (Bool) -> Void
    @Environment(SettingsStore.self) private var settings
    @Environment(\.reminders) private var reminders

    var body: some View {
        OnboardingScaffold(step: .notifications, title: .notifPrimeTitle, subtitle: .notifPrimeBody,
                           primary: .commonContinue, onPrimary: activate) {
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
            onNext(granted)
        }
    }
}

/// After a decline: what reminders change over a week, and, plainly, that
/// the app lock goes through them. iOS won't ask twice, so the way back is
/// the app's page in iOS Settings; coming back with notifications allowed
/// moves on by itself. Continuing without them stays one tap away.
struct NotificationsRecoverStep: View {
    let onNext: () -> Void
    @Environment(SettingsStore.self) private var settings
    @Environment(\.reminders) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @State private var finished = false

    var body: some View {
        OnboardingScaffold(step: .notificationsRecover, title: .notifRecoverTitle, subtitle: .notifRecoverBody,
                           primary: .settingsOpenSettings, secondary: .notifRecoverSkip,
                           onPrimary: LocationPermission.openSettings, onSecondary: finish) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HStack(spacing: Spacing.md) {
                    week(.notifRecoverWithReminders, days: 6, level: 0.86, muted: false)
                    week(.notifRecoverWithoutReminders, days: 2, level: 0.22, muted: true)
                }
                Label {
                    Text(.notifRecoverLock)
                        .font(.brandFootnote)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Palette.primaryDark)
                }
                .padding(Spacing.lg)
                .background(Palette.backgroundElement, in: .rect(cornerRadius: Radius.lg, style: .continuous))
            }
        }
        // Back from iOS Settings with notifications allowed: reminders on,
        // and on with the flow.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                guard await reminders?.permission() == .granted else { return }
                settings.settings.notificationsEnabled = true
                finish()
            }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onNext()
    }

    private func week(_ label: LocalizedStringResource, days: Int, level: Double, muted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottom) {
                Palette.backgroundElement
                Palette.accentCyan.opacity(muted ? 0.35 : 1)
                    .frame(height: 62 * level)
            }
            .frame(width: 46, height: 62)
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
            .padding(.bottom, Spacing.sm)
            .accessibilityHidden(true)

            Text(label)
                .font(.brandCaption)
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(days, format: .number)
                    .font(.brand(.bold, size: 26, relativeTo: .title2))
                    .foregroundStyle(muted ? Palette.textTertiary : Palette.primaryDark)
                Text(.notifRecoverOutOfSevenDays)
                    .font(.bodyRegular)
                    .foregroundStyle(Palette.textTertiary)
            }
            Text(.notifRecoverGoalHit)
                .font(.brandFootnote)
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(.white, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// What a reminder looks like — the same copy the real one uses.
private struct NotificationPreview: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            AppLogo(size: 38)
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

// MARK: - Goal reveal

/// The payoff: the computed goal rising in a glass of water, with the
/// rhythm it implies.
struct GoalRevealStep: View {
    let onNext: () -> Void
    @Environment(SettingsStore.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var physics = WaterPhysics()
    @State private var shownGoal = 0
    @State private var revealed = false

    var body: some View {
        let window = settings.settings.window

        VStack(alignment: .leading, spacing: Spacing.xl) {
          // Scrolls only at large text sizes; Continue stays on screen.
          ScrollView {
           VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(.goalRevealEyebrow)
                    .font(.eyebrow)
                    .kerning(1.5)
                    .foregroundStyle(Palette.secondaryBlue)
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

            // Side by side normally; stacked at accessibility text sizes.
            AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Spacing.md))
                                                    : AnyLayout(HStackLayout(spacing: Spacing.md))) {
                metric("\(window.reminderSlots.count)", label: .goalRevealRemindersPerDay)
                metric(ReminderInterval(rawValue: window.intervalMin)?.shortLabel ?? "–", label: .goalRevealPace)
                metric(window.wake.formatted, label: .goalRevealStart)
            }

            // App Review guideline 1.4.1: the goal is guidance, not medicine.
            Text(.healthDisclaimerShort)
                .font(.brandFootnote)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity)
           }
          }
          .scrollBounceBehavior(.basedOnSize)
          .scrollIndicators(.hidden)

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
