import Foundation
import HydraviaCore
import HydraviaData
import SwiftData
import WidgetKit

/// One moment of a widget's day.
struct HydrationEntry: TimelineEntry {
    let date: Date
    let consumedMl: Int
    let state: WidgetState
    let nextReminder: Date?

    var goalMl: Int { max(state.goalMl, 1) }
    var progress: Double { Double(consumedMl) / Double(goalMl) }
    var isGoalReached: Bool { consumedMl >= goalMl }
    var hasPro: Bool { state.hasPro(at: date) }

    static let preview = HydrationEntry(
        date: .now, consumedMl: 1250,
        state: WidgetState(goalMl: 2300, quickAddMl: 330, favoritesMl: [200, 330, 500],
                           window: UserSettings.defaults.window, remindersOn: true, isPro: true, proUntil: nil),
        nextReminder: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now)
    )
}

/// Reads today's water from the shared store and plans the day ahead: a new
/// entry at each remaining reminder (the "next reminder" moves on) and at
/// midnight (the count starts over). Drinks logged in the app reload the
/// timelines right away.
struct HydrationProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        completion(context.isPreview ? .preview : Self.entries(from: .now).first ?? .preview)
    }

    /// How stale a widget may get. A pour from one widget reloads that one
    /// at once; the others only get a reload request, which iOS is free to
    /// postpone (it often does on a device). Re-reading the store this often
    /// bounds the gap without spending the whole daily reload budget.
    static let refreshInterval: TimeInterval = 20 * 60

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        let now = Date.now
        completion(Timeline(entries: Self.entries(from: now), policy: .after(now.addingTimeInterval(Self.refreshInterval))))
    }

    static func entries(from now: Date, calendar: Calendar = .autoupdatingCurrent) -> [HydrationEntry] {
        let state = WidgetState.load() ?? .placeholder
        let today = calendar.startOfDay(for: now)
        let consumed = todayTotalMl(since: today)
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: today) else {
            return [entry(at: now, consumedMl: consumed, state: state, calendar: calendar)]
        }
        let slots = state.window.reminderSlots.compactMap {
            calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: now)
        }
        let moments = [now] + slots.filter { $0 > now }
        return moments.map { entry(at: $0, consumedMl: consumed, state: state, calendar: calendar) }
            + [entry(at: midnight, consumedMl: 0, state: state, calendar: calendar)]
    }

    private static func entry(at date: Date, consumedMl: Int, state: WidgetState, calendar: Calendar) -> HydrationEntry {
        HydrationEntry(date: date, consumedMl: consumedMl, state: state,
                       nextReminder: state.remindersOn
                           ? nextReminder(after: date, window: state.window, goalReached: consumedMl >= state.goalMl, calendar: calendar)
                           : nil)
    }

    /// Goal reached: today's reminders are off, the next is tomorrow's first.
    private static func nextReminder(after date: Date, window: ActiveWindow, goalReached: Bool, calendar: Calendar) -> Date? {
        if goalReached {
            guard let first = window.reminderSlots.first,
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)
            else { return nil }
            return calendar.date(bySettingHour: first.hour, minute: first.minute, second: 0, of: tomorrow)
        }
        switch window.nextReminder(after: MinuteOfDay(date, calendar: calendar)) {
        case .today(let minute):
            return calendar.date(bySettingHour: minute.hour, minute: minute.minute, second: 0, of: date)
        case .tomorrow(let minute):
            return calendar.date(byAdding: .day, value: 1, to: date).flatMap {
                calendar.date(bySettingHour: minute.hour, minute: minute.minute, second: 0, of: $0)
            }
        case .none:
            return nil
        }
    }

    private static func todayTotalMl(since start: Date) -> Int {
        guard let container = Persistence.makeExtensionContainer() else { return 0 }
        let context = ModelContext(container)
        let entries = (try? context.fetch(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.createdAt >= start }))) ?? []
        return entries.reduce(0) { $0 + $1.amountMl }
    }
}
