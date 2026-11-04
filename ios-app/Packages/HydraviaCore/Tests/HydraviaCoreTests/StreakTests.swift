import Foundation
import Testing
@testable import HydraviaCore

@Suite("Streak")
struct StreakTests {
    private let goal = 2500
    private let today = LocalDay(year: 2026, month: 8, day: 13)

    private func totals(_ pairs: [(Int, Int)]) -> [DayTotal] {
        pairs.map { DayTotal(day: LocalDay(year: 2026, month: 8, day: $0.0), totalMl: $0.1) }
    }

    @Test func localDayUsesTheLocalCalendarNotUTC() {
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!
        let halfPastMidnight = paris.date(from: DateComponents(year: 2026, month: 8, day: 14, hour: 0, minute: 30))!
        #expect(LocalDay(halfPastMidnight, calendar: paris) == LocalDay(year: 2026, month: 8, day: 14))
    }

    @Test func dayArithmeticCrossesMonthAndYearBoundaries() {
        #expect(LocalDay(year: 2026, month: 3, day: 1).adding(days: -1) == LocalDay(year: 2026, month: 2, day: 28))
        #expect(LocalDay(year: 2028, month: 3, day: 1).adding(days: -1) == LocalDay(year: 2028, month: 2, day: 29))
        #expect(LocalDay(year: 2026, month: 12, day: 31).adding(days: 1) == LocalDay(year: 2027, month: 1, day: 1))
        #expect(LocalDay(year: 1970, month: 1, day: 1).ordinal == 0)
    }

    @Test func localDayIsGregorianWhateverTheDeviceCalendar() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        let date = buddhist.date(from: DateComponents(year: 2569, month: 2, day: 28, hour: 12))!
        let day = LocalDay(date, calendar: buddhist)
        #expect(day == LocalDay(year: 2026, month: 2, day: 28))
        #expect(day.adding(days: 1) == LocalDay(year: 2026, month: 3, day: 1))
    }

    @Test func outOfRangeDatesAreNormalisedSoEqualityMatchesOrdering() {
        #expect(LocalDay(year: 2026, month: 2, day: 31) == LocalDay(year: 2026, month: 3, day: 3))
        #expect(LocalDay(year: 2026, month: 13, day: 1) == LocalDay(year: 2027, month: 1, day: 1))
        #expect(LocalDay(year: 2026, month: 1, day: 0) == LocalDay(year: 2025, month: 12, day: 31))
    }

    @Test func nonPositiveGoalReachesNothing() {
        let stats = totals([(12, 0)])
        #expect(Streak.current(stats, goalMl: 0, today: today) == 0)
    }

    @Test func countsConsecutiveDaysBackFromYesterday() {
        let stats = totals([(10, 2500), (11, 2500), (12, 2500), (13, 500)])
        #expect(Streak.current(stats, goalMl: goal, today: today) == 3)
    }

    @Test func aMissedDayBreaksTheStreakEvenThoughItIsAbsent() {
        // The 11th has no entry at all — the regression this module exists for.
        let stats = totals([(9, 2500), (10, 2500), (12, 2500), (13, 750)])
        #expect(Streak.current(stats, goalMl: goal, today: today) == 1)
    }

    @Test func todayIsIgnoredSoAPartialDayNeverBreaksTheStreak() {
        let stats = totals([(12, 2500), (13, 10)])
        #expect(Streak.current(stats, goalMl: goal, today: today) == 1)
    }

    @Test func zeroWhenYesterdayFellShort() {
        let stats = totals([(11, 2500), (12, 1000)])
        #expect(Streak.current(stats, goalMl: goal, today: today) == 0)
    }

    @Test func zeroWithNoData() {
        #expect(Streak.current([], goalMl: goal, today: today) == 0)
        #expect(Streak.best([], goalMl: goal, today: today) == 0)
    }

    @Test func countsGoalMeetingDaysExcludingToday() {
        let stats = totals([(9, 2500), (10, 1000), (12, 2600), (13, 2600)])
        #expect(Streak.daysReached(stats, goalMl: goal, today: today) == 2)
    }

    @Test func bestRunIsBrokenByGaps() {
        let stats = totals([(7, 2500), (8, 2500), (10, 2500), (11, 2500), (12, 2500)])
        #expect(Streak.best(stats, goalMl: goal, today: today) == 3)
    }

    @Test func bestIsNeverSmallerThanCurrent() {
        let stats = totals([(11, 2500), (12, 2500)])
        #expect(Streak.best(stats, goalMl: goal, today: today) >= Streak.current(stats, goalMl: goal, today: today))
    }
}
