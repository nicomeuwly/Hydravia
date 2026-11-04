import Foundation
import HydraviaCore
import Testing
@testable import HydraviaData

@MainActor
@Suite("SettingsStore")
struct SettingsStoreTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "hydravia.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func startsWithDefaults() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.settings == .defaults)
        #expect(store.dailyGoalMl == 2300)
    }

    @Test func changesSurviveARelaunch() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.settings.weightKg = 82
        store.settings.window.intervalMin = 45
        store.settings.onboardingDone = true

        let relaunched = SettingsStore(defaults: defaults)
        #expect(relaunched.settings.weightKg == 82)
        #expect(relaunched.settings.window.intervalMin == 45)
        #expect(relaunched.settings.onboardingDone)
    }

    @Test func missingFieldsFallBackToDefaultsInsteadOfWipingEverything() throws {
        let defaults = freshDefaults()
        defaults.set(Data(#"{"weightKg": 90}"#.utf8), forKey: SettingsStore.storageKey)
        let store = SettingsStore(defaults: defaults)
        #expect(store.settings.weightKg == 90)
        #expect(store.settings.window == UserSettings.defaults.window)
    }

    @Test func impossibleStoredValuesAreRepairedOnLoad() {
        let defaults = freshDefaults()
        let json = #"{"weightKg": 900, "window": {"wake": 1420, "sleep": 1430, "intervalMin": 60}}"#
        defaults.set(Data(json.utf8), forKey: SettingsStore.storageKey)
        let store = SettingsStore(defaults: defaults)
        #expect(store.settings.weightKg == UserSettings.weightRangeKg.upperBound)
        #expect(store.settings.window.wake < store.settings.window.sleep)
    }

    @Test func assignmentsAreRepairedToo() {
        let store = SettingsStore(defaults: freshDefaults())
        store.settings.weightKg = 5
        #expect(store.settings.weightKg == UserSettings.weightRangeKg.lowerBound)
    }

    @Test func corruptDataFallsBackToDefaults() {
        let defaults = freshDefaults()
        defaults.set(Data("not json".utf8), forKey: SettingsStore.storageKey)
        #expect(SettingsStore(defaults: defaults).settings == .defaults)
    }
}
