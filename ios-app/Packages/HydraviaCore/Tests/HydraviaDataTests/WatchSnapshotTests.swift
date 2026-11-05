import Foundation
import HydraviaCore
import Testing
@testable import HydraviaData

@Suite("Apple Watch snapshot and local state")
struct WatchSnapshotTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: hour, minute: minute))!
    }

    private func snapshot(consumed: Int, counted: [UUID] = []) -> WatchSnapshot {
        let window = ActiveWindow(wake: MinuteOfDay(hour: 7, minute: 0), sleep: MinuteOfDay(hour: 22, minute: 0), intervalMin: 60)
        let state = WidgetState(goalMl: 2000, quickAddMl: 250, favoritesMl: [250, 330, 500], window: window,
                                remindersOn: true, isPro: true, proUntil: nil)
        return WatchSnapshot(state: state, day: LocalDay(date(8), calendar: calendar), consumedMl: consumed,
                             streak: 3, countedPours: counted)
    }

    @Test func travelsAsAPayload() {
        let value = snapshot(consumed: 750)
        #expect(WatchSnapshot.decode([WatchSnapshot.key: value.encoded()!]) == value)
        let pour = WatchPour(amountMl: 250, createdAt: date(9))
        #expect(WatchPour.decode([WatchPour.key: pour.encoded()!]) == pour)
        #expect(WatchPour.decode(["other": 1]) == nil)
    }

    @Test func countedPoursStopWaiting() {
        let counted = WatchPour(amountMl: 250, createdAt: date(9))
        let waiting = WatchPour(amountMl: 500, createdAt: date(9, 30))
        var local = WatchLocalState(pending: [counted, waiting])
        local.apply(snapshot(consumed: 1000, counted: [counted.id]), now: date(10))
        #expect(local.pending == [waiting])
        #expect(local.todayMl(at: date(10), calendar: calendar) == 1500)
    }

    @Test func nextReminderSkipsTodayOnceTheGoalIsReached() {
        let before = WatchLocalState(snapshot: snapshot(consumed: 1000))
        #expect(before.nextReminder(after: date(14, 30), calendar: calendar) == date(15))
        let after = WatchLocalState(snapshot: snapshot(consumed: 2000))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date(8))!
        #expect(after.nextReminder(after: date(14, 30), calendar: calendar) == tomorrow)
    }

    @Test func survivesTheTripThroughTheAppGroup() {
        let suite = "hydravia.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        #expect(WatchLocalState.load(from: defaults) == WatchLocalState())
        let local = WatchLocalState(snapshot: snapshot(consumed: 400), pending: [WatchPour(amountMl: 250, createdAt: date(9))])
        local.save(to: defaults)
        #expect(WatchLocalState.load(from: defaults) == local)
    }
}
