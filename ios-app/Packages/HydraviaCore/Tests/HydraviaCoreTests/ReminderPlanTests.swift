import Foundation
import Testing
@testable import HydraviaCore

@Suite("ReminderPlan")
struct ReminderPlanTests {
    private let window = ActiveWindow(
        wake: MinuteOfDay(hour: 7, minute: 0),
        sleep: MinuteOfDay(hour: 22, minute: 0),
        intervalMin: 60
    ) // 14 slots, 08:00 to 21:00

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func startsWithTodaysRemainingSlots() {
        let dates = ReminderPlan.fireDates(window: window, now: date(5, 14, 30), goalReachedToday: false, calendar: calendar)
        #expect(dates.first == date(5, 15))
        #expect(dates.prefix(7).last == date(5, 21))
        #expect(dates.dropFirst(7).first == date(6, 8))
    }

    @Test func aSlotAtNowIsNotRescheduled() {
        let dates = ReminderPlan.fireDates(window: window, now: date(5, 15), goalReachedToday: false, calendar: calendar)
        #expect(dates.first == date(5, 16))
    }

    @Test func goalReachedSkipsTheRestOfToday() {
        let dates = ReminderPlan.fireDates(window: window, now: date(5, 9, 10), goalReachedToday: true, calendar: calendar)
        #expect(dates.first == date(6, 8))
        #expect(dates.allSatisfy { !calendar.isDate($0, inSameDayAs: date(5, 12)) })
    }

    @Test func staysWithinTheBudget() {
        let dates = ReminderPlan.fireDates(window: window, now: date(5, 6), goalReachedToday: false, calendar: calendar)
        #expect(dates.count == ReminderPlan.budget)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
        // 60 reminders at 14 a day: today and three full days, then four.
        #expect(dates.last == date(9, 11))
    }

    @Test func noSlotsNoReminders() {
        let empty = ActiveWindow(wake: MinuteOfDay(hour: 7, minute: 0), sleep: MinuteOfDay(hour: 7, minute: 30), intervalMin: 60)
        #expect(ReminderPlan.fireDates(window: empty, now: date(5, 6), goalReachedToday: false, calendar: calendar).isEmpty)
    }

    @Test func springForwardNightNeverDuplicates() {
        // Paris skips 02:00 to 03:00 on 29 March 2026.
        let night = ActiveWindow(wake: MinuteOfDay(hour: 1, minute: 0), sleep: MinuteOfDay(hour: 4, minute: 0), intervalMin: 30)
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 0))!
        let dates = ReminderPlan.fireDates(window: night, now: now, goalReachedToday: false, calendar: calendar, budget: 10)
        #expect(Set(dates).count == dates.count)
        #expect(dates == dates.sorted())
    }

    @Test func identifiersCarryTheDay() {
        #expect(ReminderPlan.identifier(for: date(5, 9, 30), calendar: calendar) == "hydration-reminder-2026-11-05-0930")
        #expect(ReminderPlan.identifier(for: date(5, 9, 30), calendar: calendar)
            .hasPrefix(ReminderPlan.dayPrefix(for: date(5, 23), calendar: calendar)))
    }
}
