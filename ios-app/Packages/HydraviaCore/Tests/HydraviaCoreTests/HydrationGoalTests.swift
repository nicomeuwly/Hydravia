import Testing
@testable import HydraviaCore

@Suite("HydrationGoal")
struct HydrationGoalTests {
    @Test("weight × 33 mL, rounded to the nearest 100 mL", arguments: [
        (70, 2300), // 2310
        (60, 2000), // 1980
        (75, 2500), // 2475
        (63, 2100), // 2079
    ])
    func rounding(weightKg: Int, expected: Int) {
        #expect(HydrationGoal.dailyMl(weightKg: weightKg) == expected)
    }

    @Test func clampsToMinimum() {
        #expect(HydrationGoal.dailyMl(weightKg: 40) == HydrationGoal.minimumMl)
    }

    @Test func clampsToMaximum() {
        #expect(HydrationGoal.dailyMl(weightKg: 130) == HydrationGoal.maximumMl)
    }

    @Test func progressIsClamped() {
        #expect(HydrationGoal.progress(consumedMl: 0, goalMl: 2000) == 0)
        #expect(HydrationGoal.progress(consumedMl: 1000, goalMl: 2000) == 0.5)
        #expect(HydrationGoal.progress(consumedMl: 3000, goalMl: 2000) == 1)
        #expect(HydrationGoal.progress(consumedMl: 500, goalMl: 0) == 0)
    }
}
