import BackgroundTasks
import HydraviaData
import OSLog

/// Tops the reminder plan up while the app stays closed. The plan holds 60
/// dated one-shots (about four days); without this, reminders stopped for
/// anyone who didn't open the app for that long. iOS decides when (and
/// whether) the refresh runs, so the plan also ends with a notice asking to
/// open the app (`ReminderService.continueIdentifier`).
///
/// The identifier is listed under `BGTaskSchedulerPermittedIdentifiers` in
/// `Hydravia-Info.plist`, with the `fetch` background mode.
enum BackgroundRefresh {
    nonisolated static let identifier = "com.nicomeuwly.hydravia.reminders-refresh"

    /// Asks for the next run, at the earliest `delay` from now. Submitting
    /// again replaces the pending request.
    static func schedule(after delay: TimeInterval = 12 * 3600) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: delay)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // The simulator refuses background tasks; so do devices with
            // Background App Refresh turned off.
            Logger(subsystem: "com.nicomeuwly.hydravia", category: "Reminders")
                .info("Background refresh not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension AppDependencies {
    /// The refresh itself: today's water re-read, then the same reschedule
    /// a return to the foreground does.
    func refreshRemindersInBackground() async {
        BackgroundRefresh.schedule()
        hydration.refresh()
        let current = settings.settings
        guard current.onboardingDone else { return }
        await reminders.reschedule(
            window: current.window,
            enabled: current.notificationsEnabled,
            ritual: true,
            goalReachedToday: hydration.todayTotalMl >= settings.dailyGoalMl,
            lastDrink: hydration.todayEntries.map(\.createdAt).max()
        )
    }
}
