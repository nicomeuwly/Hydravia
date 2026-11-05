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
        if today.reduce(0, { $0 + $1.amountMl }) >= state.goalMl {
            Self.restForToday(calendar: calendar)
        }
        // Every widget shows today's total, not just the one tapped. Only the
        // tapped one is sure to reload now; the rest is a request iOS may
        // postpone (the timelines' refresh interval catches up).
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    /// This pour reached the goal: the rest of today's reminders go, and the
    /// lock rests. The widget can't touch the shield itself: one already up
    /// drops when the app next opens or the next lock event runs.
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
