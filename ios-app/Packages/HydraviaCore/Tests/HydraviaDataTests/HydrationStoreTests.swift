import Foundation
import HydraviaCore
import SwiftData
import Testing
@testable import HydraviaData

@MainActor
@Suite("HydrationStore")
struct HydrationStoreTests {
    private let paris: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    /// A clock the test can move.
    private final class Clock {
        var date: Date
        init(_ date: Date) { self.date = date }
    }

    private func makeStore(at clock: Clock) throws -> HydrationStore {
        HydrationStore(container: try Persistence.makeContainer(inMemory: true), calendar: paris, now: { clock.date })
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        paris.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }

    @Test func addingUpdatesTodayTotalRecentTotalsAndRevision() throws {
        let clock = Clock(date(13, 9))
        let store = try makeStore(at: clock)
        let initialRevision = store.revision
        try store.add(250, source: .manual)
        try store.add(330, source: .unlock)
        #expect(store.todayTotalMl == 580)
        #expect(store.todayEntries.map(\.source) == [.manual, .unlock])
        #expect(store.recentTotals == [DayTotal(day: LocalDay(year: 2026, month: 8, day: 13), totalMl: 580)])
        #expect(store.revision == initialRevision + 2)
    }

    @Test func nonPositiveAmountsAreRejected() throws {
        let store = try makeStore(at: Clock(date(13, 9)))
        #expect(throws: HydrationStoreError.invalidAmount(0)) { try store.add(0, source: .manual) }
        #expect(throws: HydrationStoreError.invalidAmount(-50)) { try store.add(-50, source: .manual) }
        #expect(store.todayTotalMl == 0)
    }

    @Test func halfPastMidnightCountsTowardTheNewDay() throws {
        let clock = Clock(date(13, 23, 50))
        let store = try makeStore(at: clock)
        try store.add(200, source: .manual)
        clock.date = date(14, 0, 30)
        try store.add(300, source: .manual)
        #expect(store.todayTotalMl == 300)
        #expect(store.entries(on: LocalDay(year: 2026, month: 8, day: 13)).map(\.amountMl) == [200])
    }

    @Test func refreshPicksUpADayChange() throws {
        let clock = Clock(date(13, 20))
        let store = try makeStore(at: clock)
        try store.add(500, source: .manual)
        clock.date = date(14, 8)
        store.refresh()
        #expect(store.today == LocalDay(year: 2026, month: 8, day: 14))
        #expect(store.todayTotalMl == 0)
        #expect(store.recentTotals.count == 1) // yesterday's 500 is still recent
    }

    @Test func streaksSeeFurtherBackThanTheWeek() throws {
        // Goal met every day from Aug 1 to Aug 20, then "today" is Aug 21.
        let clock = Clock(date(1, 12))
        let store = try makeStore(at: clock)
        for day in 1...20 {
            clock.date = date(day, 12)
            try store.add(2_000, source: .manual)
        }
        clock.date = date(21, 9)
        store.refresh()
        #expect(store.recentTotals.count == 6) // Aug 15–20; today is empty
        #expect(Streak.current(store.streakTotals, goalMl: 2_000, today: store.today) == 20)
        #expect(Streak.best(store.streakTotals, goalMl: 2_000, today: store.today) == 20)
    }

    @Test func dailyTotalsGroupByLocalDayAndOmitEmptyDays() throws {
        let clock = Clock(date(10, 9))
        let store = try makeStore(at: clock)
        try store.add(1000, source: .manual)
        clock.date = date(10, 18)
        try store.add(1500, source: .manual)
        clock.date = date(12, 9) // the 11th is skipped entirely
        try store.add(700, source: .manual)
        clock.date = date(13, 9)

        let totals = store.dailyTotals(lastDays: 7)
        #expect(totals == [
            DayTotal(day: LocalDay(year: 2026, month: 8, day: 10), totalMl: 2500),
            DayTotal(day: LocalDay(year: 2026, month: 8, day: 12), totalMl: 700),
        ])
    }

    @Test func dailyTotalsRespectTheWindow() throws {
        let clock = Clock(date(1, 9))
        let store = try makeStore(at: clock)
        try store.add(1000, source: .manual)
        clock.date = date(13, 9)
        #expect(store.dailyTotals(lastDays: 7).isEmpty)
    }

    @Test func deleteAndDeleteAll() throws {
        let store = try makeStore(at: Clock(date(13, 9)))
        try store.add(250, source: .manual)
        try store.add(250, source: .manual)
        try store.delete(store.todayEntries[0])
        #expect(store.todayTotalMl == 250)
        try store.deleteAll()
        #expect(store.todayEntries.isEmpty)
    }
}
