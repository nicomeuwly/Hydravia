import Foundation
import Testing
@testable import HydraviaCore

@Suite("WatchTally")
struct WatchTallyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    @Test func addsTodaysPendingPoursToThePhonesCount() {
        let pending = [WatchPour(amountMl: 250, createdAt: date(5, 10)), WatchPour(amountMl: 300, createdAt: date(4, 21))]
        let total = WatchTally.todayMl(phoneDay: LocalDay(date(5, 8), calendar: calendar), phoneMl: 1000,
                                       pending: pending, now: date(5, 11), calendar: calendar)
        #expect(total == 1250)
    }

    @Test func yesterdaysCountIsNotToday() {
        let total = WatchTally.todayMl(phoneDay: LocalDay(date(4, 20), calendar: calendar), phoneMl: 1800,
                                       pending: [], now: date(5, 7), calendar: calendar)
        #expect(total == 0)
    }

    @Test func countedAndStalePoursAreDropped() {
        let counted = WatchPour(amountMl: 250, createdAt: date(5, 10))
        let waiting = WatchPour(amountMl: 200, createdAt: date(5, 10))
        let stale = WatchPour(amountMl: 200, createdAt: date(1, 10))
        let left = WatchTally.stillPending([counted, waiting, stale], counted: [counted.id], now: date(5, 11))
        #expect(left == [waiting])
    }

    @Test func aPourCountsOnce() {
        let pour = WatchPour(amountMl: 250, createdAt: date(5, 10))
        let first = WatchTally.receive(pour, counted: [:], now: date(5, 10))
        #expect(first.isNew)
        let again = WatchTally.receive(pour, counted: first.counted, now: date(5, 11))
        #expect(!again.isNew)
    }

    @Test func oldMemoryIsForgotten() {
        let old = UUID()
        let result = WatchTally.receive(WatchPour(amountMl: 250, createdAt: date(5, 10)),
                                        counted: [old: date(1, 10)], now: date(5, 10))
        #expect(result.counted[old] == nil)
    }

    @Test func implausiblePoursAreRefused() {
        #expect(!WatchTally.receive(WatchPour(amountMl: 0, createdAt: date(5, 10)), counted: [:], now: date(5, 10)).isNew)
        #expect(!WatchTally.receive(WatchPour(amountMl: 5000, createdAt: date(5, 10)), counted: [:], now: date(5, 10)).isNew)
        #expect(!WatchTally.receive(WatchPour(amountMl: 250, createdAt: date(1, 10)), counted: [:], now: date(5, 10)).isNew)
        #expect(!WatchTally.receive(WatchPour(amountMl: 250, createdAt: date(5, 12)), counted: [:], now: date(5, 10)).isNew)
    }
}
