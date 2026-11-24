import AppIntents
import HydraviaData
import HydraviaCore
import SwiftData
import UserNotifications
import WidgetKit

/// A widget button's pour: logs the water straight into the shared store,
/// without opening the app. Hydravia Pro.
struct AddWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "widget.intent.title"
    static let isDiscoverable = false

    @Parameter(title: "widget.intent.amount")
    var amountMl: Int

    init() {}

    init(amountMl: Int) {
        self.amountMl = amountMl
    }

    func perform() async throws -> some IntentResult {
        let state = WidgetState.load() ?? .placeholder
        guard state.hasPro(at: .now), (1...2000).contains(amountMl),
              let container = Persistence.makeExtensionContainer()
        else { return .result() }
        let context = ModelContext(container)
        context.insert(WaterEntry(amountMl: amountMl, createdAt: .now, source: .widget))
        try context.save()
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: .now)
        let today = (try? context.fetch(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.createdAt >= start }))) ?? []
        let todayMl = today.reduce(0, { $0 + $1.amountMl })
        Self.shareProgress(consumedMl: todayMl, goalMl: state.goalMl, context: context, calendar: calendar)
        if todayMl >= state.goalMl {
            Self.restForToday(calendar: calendar)
        }
        // Every widget shows today's total, not just the one tapped. Only the
        // tapped one is sure to reload now; the rest is a request iOS may
        // postpone (the timelines' refresh interval catches up).
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    /// Hands the shield today's new numbers (what `RootView` does in the
    /// app), so a shield shown after this pour doesn't read the old total.
    private static func shareProgress(consumedMl: Int, goalMl: Int, context: ModelContext, calendar: Calendar) {
        let todayDay = LocalDay(.now, calendar: calendar)
        let firstDay = todayDay.adding(days: -400)
        let since = firstDay.startDate(in: calendar) ?? .distantPast
        let entries = (try? context.fetch(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.createdAt >= since }))) ?? []
        var byDay: [LocalDay: Int] = [:]
        for entry in entries { byDay[LocalDay(entry.createdAt, calendar: calendar), default: 0] += entry.amountMl }
        let totals = byDay.map { DayTotal(day: $0.key, totalMl: $0.value) }
        ShieldProgressMirror(
            consumedMl: consumedMl,
            goalMl: goalMl,
            streak: Streak.current(totals, goalMl: goalMl, today: todayDay),
            day: .now
        ).save()
    }

    /// This pour reached the goal: the rest of today's reminders go, and the
    /// lock rests. The widget can't touch the shield itself (no Family
    /// Controls here): one already up drops at its next button press (the
    /// shield action checks the goal first), when the app next opens, or at
    /// the next lock event.
    private static func restForToday(calendar: Calendar) {
        // `Blocker.goalReachedOn`'s key (Blocker isn't compiled here).
        UserDefaults(suiteName: Persistence.appGroup)?.set(Date.now, forKey: "blocker.goalReachedOn.v1")
        let center = UNUserNotificationCenter.current()
        let prefix = ReminderPlan.dayPrefix(for: .now, calendar: calendar)
        center.getPendingNotificationRequests { requests in
            center.removePendingNotificationRequests(
                withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            )
        }
    }
}
