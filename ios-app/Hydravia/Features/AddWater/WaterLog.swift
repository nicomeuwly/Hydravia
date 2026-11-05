import HydraviaData

/// Water logged by hand, from the home screen's quick add or the add sheet:
/// the entry, plus what drinking means for the reminder.
enum WaterLog {
    @discardableResult
    static func addManual(
        _ ml: Int,
        hydration: HydrationStore,
        router: AppRouter,
        blocker: BlockerService,
        reminders: ReminderService?
    ) throws -> WaterEntry {
        let entry = try hydration.add(ml, source: .manual)
        // Drinking answers the reminder. The apps stay locked, though (only
        // the ritual lifts the shield): while it's up the ritual card stays lit.
        router.reminderFired = blocker.isShieldUp
        router.lastManualAdd = AppRouter.ManualAdd(entry: entry, ml: ml)
        Task { await reminders?.clearDeliveredReminders() }
        return entry
    }
}
