import Foundation
import Testing
@testable import HydraviaCore

@Suite("Dose")
struct DoseTests {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func at(_ hour: Int, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: hour, minute: minute))!
    }

    private let base = DoseInput(
        goalMl: 2000,
        drunkMl: 800,
        now: at(10),
        windowEnd: at(22),
        intervalMin: 60,
        feeling: .fine,
        temperatureC: nil
    )

    private func dose(_ change: (inout DoseInput) -> Void = { _ in }) -> Int {
        var input = base
        change(&input)
        return Dose.ml(for: input)
    }

    @Test func nominalDoseWithoutWeather() {
        // remaining 1200, 12 reminders → 100, × 0.9 = 90 → floor 100
        #expect(dose() == 100)
    }

    @Test func hotFeelingRaisesTheDose() {
        // 100 × 1.15 is 114.999… in floating point → rounds to 110, exactly
        // like the original TypeScript engine.
        #expect(dose { $0.feeling = .hot } == 110)
    }

    @Test func veryThirstyRaisesItFurther() {
        #expect(dose { $0.feeling = .veryThirsty } == 130)
    }

    @Test func heatAboveThresholdNeverDropsBelowMinimum() {
        #expect(dose { $0.temperatureC = 32 } >= Int(Dose.minimumMl))
    }

    @Test("goal reached or exceeded → minimum dose", arguments: [2000, 2500])
    func goalReached(drunk: Int) {
        #expect(dose { $0.drunkMl = drunk } == Int(Dose.minimumMl))
    }

    @Test func pastBedtimeCountsAsOneReminderLeft() {
        let result = dose {
            $0.now = Self.at(23)
            $0.drunkMl = 1000
        }
        let expected = Int((Dose.baseMaximumMl * Dose.multiplier(for: .fine) / 10).rounded() * 10)
        #expect(result == expected)
    }

    @Test func feelingDifferentiatesWhenTheBaseSaturatesHigh() {
        func saturated(_ feeling: Feeling) -> Int {
            dose {
                $0.now = Self.at(23)
                $0.drunkMl = 0
                $0.feeling = feeling
            }
        }
        #expect(saturated(.fine) < saturated(.hot))
        #expect(saturated(.hot) < saturated(.veryThirsty))
        #expect(saturated(.veryThirsty) == Int(Dose.maximumMl))
    }

    @Test func feelingDifferentiatesWhenTheBaseHitsTheFloor() {
        func floored(_ feeling: Feeling) -> Int {
            dose {
                $0.drunkMl = 1950
                $0.feeling = feeling
            }
        }
        #expect(floored(.fine) == Int(Dose.minimumMl))
        #expect(floored(.hot) > floored(.fine))
        #expect(floored(.veryThirsty) > floored(.hot))
    }

    @Test func neverExceedsMaximum() {
        let result = dose {
            $0.drunkMl = 0
            $0.feeling = .veryThirsty
            $0.temperatureC = 35
            $0.now = Self.at(21, 30)
        }
        #expect(result <= Int(Dose.maximumMl))
    }

    @Test func unknownTemperatureMatchesColdWeather() {
        #expect(dose { $0.temperatureC = nil } == dose { $0.temperatureC = 10 })
    }

    @Test func alwaysAMultipleOfTen() {
        let result = dose {
            $0.drunkMl = 500
            $0.feeling = .hot
            $0.temperatureC = 30
        }
        #expect(result % 10 == 0)
    }

    @Test func windowEndIsTonightBeforeBedtime() {
        let end = Dose.windowEnd(sleep: MinuteOfDay(hour: 22, minute: 0), now: Self.at(10), calendar: Self.utc)
        #expect(end == Self.at(22))
    }

    @Test("bedtime stays at 22:00 wall clock across daylight-saving switches", arguments: [
        (2026, 3, 29), // spring forward in Europe/Paris
        (2026, 10, 25), // fall back
    ])
    func windowEndSurvivesDaylightSaving(year: Int, month: Int, day: Int) {
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!
        let morning = paris.date(from: DateComponents(year: year, month: month, day: day, hour: 10))!
        let end = Dose.windowEnd(sleep: MinuteOfDay(hour: 22, minute: 0), now: morning, calendar: paris)
        let parts = paris.dateComponents([.day, .hour, .minute], from: end)
        #expect(parts.day == day)
        #expect(parts.hour == 22)
        #expect(parts.minute == 0)
    }

    @Test func nonPositiveIntervalCountsAsOneReminder() {
        let zero = dose { $0.intervalMin = 0 }
        let negative = dose { $0.intervalMin = -30 }
        let single = dose { $0.now = Self.at(21, 59) } // < 1 interval left → 1 reminder
        #expect(zero == single)
        #expect(negative == single)
    }

    @Test func windowEndRollsToTomorrowAfterBedtime() {
        let end = Dose.windowEnd(sleep: MinuteOfDay(hour: 22, minute: 0), now: Self.at(23), calendar: Self.utc)
        #expect(end == Self.at(22).addingTimeInterval(24 * 3600))
    }
}
