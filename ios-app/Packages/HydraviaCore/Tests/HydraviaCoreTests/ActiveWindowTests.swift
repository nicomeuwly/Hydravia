import Foundation
import Testing
@testable import HydraviaCore

@Suite("ActiveWindow")
struct ActiveWindowTests {
    private let window = ActiveWindow(
        wake: MinuteOfDay(hour: 7, minute: 0),
        sleep: MinuteOfDay(hour: 22, minute: 0),
        intervalMin: 60
    )

    @Test func slotsStartOneIntervalAfterWakeAndStopBeforeSleep() {
        let slots = window.reminderSlots
        #expect(slots.first == MinuteOfDay(hour: 8, minute: 0))
        #expect(slots.last == MinuteOfDay(hour: 21, minute: 0))
        #expect(slots.count == 14)
    }

    @Test func slotsHonourOddIntervals() {
        let w = ActiveWindow(wake: MinuteOfDay(hour: 7, minute: 30), sleep: MinuteOfDay(hour: 10, minute: 0), intervalMin: 45)
        #expect(w.reminderSlots == [
            MinuteOfDay(hour: 8, minute: 15),
            MinuteOfDay(hour: 9, minute: 0),
            MinuteOfDay(hour: 9, minute: 45),
        ])
    }

    @Test func nextReminderIsStrictlyAfterNow() {
        #expect(window.nextReminder(after: MinuteOfDay(hour: 8, minute: 0)) == .today(MinuteOfDay(hour: 9, minute: 0)))
        #expect(window.nextReminder(after: MinuteOfDay(hour: 6, minute: 0)) == .today(MinuteOfDay(hour: 8, minute: 0)))
    }

    @Test func nextReminderRollsOverToTomorrow() {
        #expect(window.nextReminder(after: MinuteOfDay(hour: 21, minute: 30)) == .tomorrow(MinuteOfDay(hour: 8, minute: 0)))
    }

    @Test func tooShortWindowHasNoReminder() {
        let w = ActiveWindow(wake: MinuteOfDay(hour: 21, minute: 30), sleep: MinuteOfDay(hour: 22, minute: 0), intervalMin: 60)
        #expect(w.reminderSlots.isEmpty)
        #expect(w.nextReminder(after: MinuteOfDay(hour: 9, minute: 0)) == .none)
    }

    @Test func ordinaryBedtimesStayQuiet() {
        #expect(!ActiveWindow.isLateBedtime(MinuteOfDay(hour: 21, minute: 45)))
        #expect(!ActiveWindow.isLateBedtime(MinuteOfDay(hour: 18, minute: 0)))
    }

    @Test func theDefaultBedtimeStaysQuietSoTheNoteNeverBecomesWallpaper() {
        #expect(!ActiveWindow.isLateBedtime(MinuteOfDay(hour: 22, minute: 0)))
    }

    @Test func lateBedtimesWarn() {
        #expect(ActiveWindow.isLateBedtime(ActiveWindow.lateBedtimeThreshold))
        #expect(ActiveWindow.isLateBedtime(MinuteOfDay(hour: 23, minute: 45)))
    }

    @Test func sanitizedKeepsValidWindowsUntouched() {
        #expect(window.sanitized == window)
    }

    @Test func sanitizedRepairsImpossibleWindows() {
        let lateWake = ActiveWindow(wake: MinuteOfDay(hour: 23, minute: 50), sleep: MinuteOfDay(hour: 23, minute: 55), intervalMin: 0)
        let fixed = lateWake.sanitized
        #expect(fixed.sleep == ActiveWindow.latestSleep)
        #expect(fixed.wake.value == ActiveWindow.latestSleep.value - ActiveWindow.minimumGapMin)
        #expect(fixed.intervalMin == 60)

        let inverted = ActiveWindow(wake: MinuteOfDay(hour: 9, minute: 0), sleep: MinuteOfDay(hour: 0, minute: 5), intervalMin: 90)
        #expect(inverted.sanitized.sleep.value >= ActiveWindow.minimumGapMin)
        #expect(inverted.sanitized.wake.value <= inverted.sanitized.sleep.value - ActiveWindow.minimumGapMin)
    }

    @Test func minuteOfDayCodesAsANormalisedInteger() throws {
        let encoded = try JSONEncoder().encode(MinuteOfDay(hour: 7, minute: 30))
        #expect(String(decoding: encoded, as: UTF8.self) == "450")
        let decoded = try JSONDecoder().decode(MinuteOfDay.self, from: Data("1445".utf8))
        #expect(decoded == MinuteOfDay(hour: 0, minute: 5))
    }

    @Test func minuteOfDayWrapsAroundMidnight() {
        #expect(MinuteOfDay(24 * 60 + 5) == MinuteOfDay(hour: 0, minute: 5))
        #expect(MinuteOfDay(-15) == MinuteOfDay(hour: 23, minute: 45))
    }
}
