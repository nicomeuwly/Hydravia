import Testing
@testable import HydraviaCore

@Suite("ReviewPrompt")
struct ReviewPromptTests {
    private let today = LocalDay(year: 2027, month: 1, day: 10)

    @Test func waitsForTheGoalToBeReachedOnAFewDays() {
        #expect(!ReviewPrompt.shouldAsk(goalDaysReached: 0, appVersion: "1.0.1", last: nil, today: today))
        #expect(!ReviewPrompt.shouldAsk(goalDaysReached: 2, appVersion: "1.0.1", last: nil, today: today))
        #expect(ReviewPrompt.shouldAsk(goalDaysReached: 3, appVersion: "1.0.1", last: nil, today: today))
    }

    @Test func asksOnlyOncePerVersion() {
        let last = ReviewPrompt.Record(day: today.adding(days: -200), version: "1.0.1")
        #expect(!ReviewPrompt.shouldAsk(goalDaysReached: 30, appVersion: "1.0.1", last: last, today: today))
    }

    @Test func aNewVersionStillWaitsLongEnoughSinceTheLastAsk() {
        let recent = ReviewPrompt.Record(day: today.adding(days: -(ReviewPrompt.minimumDaysBetween - 1)), version: "1.0.1")
        #expect(!ReviewPrompt.shouldAsk(goalDaysReached: 30, appVersion: "1.1", last: recent, today: today))
        let old = ReviewPrompt.Record(day: today.adding(days: -ReviewPrompt.minimumDaysBetween), version: "1.0.1")
        #expect(ReviewPrompt.shouldAsk(goalDaysReached: 30, appVersion: "1.1", last: old, today: today))
    }

    @Test func aClockSetBackDoesNotBlockTheNextVersion() {
        let future = ReviewPrompt.Record(day: today.adding(days: 30), version: "1.0.1")
        #expect(ReviewPrompt.shouldAsk(goalDaysReached: 30, appVersion: "1.1", last: future, today: today))
    }
}
