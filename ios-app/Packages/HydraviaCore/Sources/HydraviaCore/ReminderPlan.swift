import Foundation

/// When the hydration reminders fire: one dated notification per slot and
/// day, not one repeating notification per slot. A repeating trigger can't
/// skip a day, and a day whose goal is reached must go quiet.
public enum ReminderPlan {
    /// Every reminder identifier starts with this, so rescheduling never
    /// touches unrelated notifications (the trial-end heads-up).
    public static let identifierPrefix = "hydration-reminder-"

    /// iOS keeps at most 64 pending notifications per app. One is the
    /// trial-end heads-up; the rest of the margin is for safety. The app
    /// tops the plan up on every launch and return to the foreground,
    /// so it only runs out after days without opening the app.
    public static let budget = 60

    /// The coming reminders, earliest first: today's still ahead (none once
    /// the goal is reached), then the following days', up to `budget`. The
    /// reminder `lastDrink` answered (`answeredDate`) is left out: drinking
    /// just before a reminder skips it, the following ones still come.
    public static func fireDates(
        window: ActiveWindow,
        now: Date,
        goalReachedToday: Bool,
        lastDrink: Date? = nil,
        calendar: Calendar,
        budget: Int = budget
    ) -> [Date] {
        let answered = lastDrink.flatMap { answeredDate(byDrinkAt: $0, window: window, calendar: calendar) }
        let calendar = calendar.gregorianInSameTimeZone
        let slots = window.reminderSlots
        guard !slots.isEmpty, budget > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        var dates: [Date] = []
        // A day has at least one slot, so `budget` days always fill it.
        for offset in (goalReachedToday ? 1 : 0)...budget {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            for slot in slots {
                guard let date = calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day),
                      date > now,
                      // A slot that doesn't exist on a DST night (02:30 when
                      // the clocks jump to 03:00) is moved by the calendar
                      // onto another slot: skip it rather than fire twice.
                      calendar.isDate(date, inSameDayAs: day),
                      calendar.component(.hour, from: date) == slot.hour,
                      calendar.component(.minute, from: date) == slot.minute
                else { continue }
                guard date != answered else { continue }
                dates.append(date)
                if dates.count == budget { return dates }
            }
        }
        return dates
    }

    /// The reminder a drink at `drink` answers
    /// (`ActiveWindow.reminderAnswered`), on the drink's day.
    public static func answeredDate(byDrinkAt drink: Date, window: ActiveWindow, calendar: Calendar) -> Date? {
        let calendar = calendar.gregorianInSameTimeZone
        guard let slot = window.reminderAnswered(byDrinkAt: MinuteOfDay(drink, calendar: calendar)) else { return nil }
        return calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: drink)
    }

    /// "hydration-reminder-2026-11-05-0930": the day is in the identifier so
    /// a pour from a widget can drop that day's remaining reminders.
    public static func identifier(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.gregorianInSameTimeZone.dateComponents([.hour, .minute], from: date)
        return dayPrefix(for: date, calendar: calendar)
            + String(format: "%02d%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// The identifiers of `date`'s reminders all start with this.
    public static func dayPrefix(for date: Date, calendar: Calendar) -> String {
        "\(identifierPrefix)\(LocalDay(date, calendar: calendar))-"
    }
}
