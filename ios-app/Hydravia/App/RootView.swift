import Combine
import HydraviaCore
import HydraviaData
import SwiftUI

/// Picks onboarding or the app, and keeps "today" fresh: returning to the
/// foreground or crossing midnight re-reads the day, so the home screen never
/// shows yesterday's water.
struct RootView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(HydrationStore.self) private var hydration
    @Environment(AppRouter.self) private var router
    @Environment(\.reminders) private var reminders
    @Environment(StoreService.self) private var store
    @Environment(BlockerService.self) private var blocker
    @Environment(\.scenePhase) private var scenePhase

    /// What the reminder schedule depends on: any change reschedules.
    private struct Schedule: Equatable {
        let window: ActiveWindow
        let enabled: Bool
        let isPro: Bool
        /// Every return to the foreground re-applies the schedule: permission
        /// re-granted in iOS Settings or a language change catch up at once.
        let active: Bool
        let entitlementsLoaded: Bool
    }

    /// Midnight passing, or the user landing in another time zone, both move
    /// "today".
    private static let dayOrZoneChanges = Publishers.Merge(
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged),
        NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
    )
    .receive(on: RunLoop.main)

    /// Reminders are free: they fire once onboarding is done and the user
    /// turned them on. (App Review guideline 4.10: notifications themselves
    /// can't be what the subscription sells.)
    private var areRemindersEnabled: Bool {
        settings.settings.onboardingDone && settings.settings.notificationsEnabled
    }

    /// The ritual is free on one app; Hydravia Pro locks any selection (dev
    /// builds count as Pro to test without a purchase).
    private var isPro: Bool {
        store.hasPro
    }

    /// A banner seen but not tapped still means "time to drink" — and so
    /// does a shield standing over the user's apps.
    private func checkUnansweredReminder() async {
        if await reminders?.hasUnansweredReminder() == true || blocker.isShieldUp || reminderPassedSinceLastDrink {
            router.reminderFired = true
        }
    }

    /// A reminder went off since the last glass: still due, whatever became
    /// of its notification (tapped, cleared, or the app relaunched).
    private var reminderPassedSinceLastDrink: Bool {
        guard areRemindersEnabled else { return false }
        let calendar = Calendar.autoupdatingCurrent
        let now = Date.now
        guard let slot = settings.settings.window.lastReminder(atOrBefore: MinuteOfDay(now, calendar: calendar)),
              let due = calendar.date(bySettingHour: slot.value / 60, minute: slot.value % 60, second: 0, of: now)
        else { return false }
        let lastDrink = hydration.todayEntries.map(\.createdAt).max()
        return lastDrink.map { $0 < due } ?? true
    }

    var body: some View {
        ZStack {
            if settings.settings.onboardingDone {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                OnboardingFlowView()
                    .transition(.opacity)
            }
        }
        .animation(Motion.slow, value: settings.settings.onboardingDone)
        // On launch (scenePhase starts out .active, so onChange alone would
        // miss a cold start) and on every return to the foreground.
        .task { await checkUnansweredReminder() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            hydration.refresh()
            Task { await checkUnansweredReminder() }
        }
        // Launch, and every change of window, cadence or switch: the system
        // schedule always mirrors the settings.
        .task(id: Schedule(window: settings.settings.window, enabled: areRemindersEnabled, isPro: isPro, active: scenePhase == .active, entitlementsLoaded: store.hasLoadedEntitlements)) {
            // Wait for the App Store's answer: rescheduling on a not-yet-known
            // entitlement would wipe a subscriber's reminders at every launch.
            guard scenePhase == .active, store.hasLoadedEntitlements else { return }
            // The Screen Time lock follows the same window and switch.
            blocker.sync(window: settings.settings.window, enabled: areRemindersEnabled, isPro: isPro)
            await reminders?.reschedule(window: settings.settings.window, enabled: areRemindersEnabled,
                                        ritual: true)
        }
        .onReceive(Self.dayOrZoneChanges) { _ in
            hydration.refresh()
            // The lock's window is wall-clock time: re-register it in the new
            // zone (DeviceActivity schedules otherwise keep the old offsets).
            if store.hasLoadedEntitlements {
                blocker.sync(window: settings.settings.window,
                             enabled: areRemindersEnabled, isPro: isPro, force: true)
            }
        }
        // The shield shows today's progress; every drink, goal change or new
        // day hands it fresh numbers.
        .onChange(of: ShieldProgress(revision: hydration.revision, goalMl: settings.dailyGoalMl), initial: true) {
            let goal = settings.dailyGoalMl
            blocker.shareProgress(
                consumedMl: hydration.todayTotalMl,
                goalMl: goal,
                streak: Streak.current(hydration.streakTotals, goalMl: goal, today: hydration.today)
            )
        }
    }

    private struct ShieldProgress: Equatable {
        let revision: Int
        let goalMl: Int
    }
}

#Preview("App") {
    RootView().injecting(AppDependencies.preview())
}

#Preview("First launch") {
    RootView().injecting(AppDependencies.preview(onboardingDone: false, todayMl: []))
}
