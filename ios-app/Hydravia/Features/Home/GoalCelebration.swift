import Foundation
import HydraviaCore

/// The goal-reached celebration plays once a day, on the home screen, however
/// the goal was reached: a glass poured while watching, the unlock ritual
/// (its full-screen cover hides the home screen at that moment), a widget
/// button or the watch while the app was closed. The home screen plays it the
/// next time it is on screen if today's hasn't been seen yet.
///
/// Only the day it was last shown is kept: a goal reached, lost (a deleted
/// glass) and reached again the same day doesn't celebrate twice.
enum GoalCelebration {
    private static let key = "home.goalCelebratedDay.v1"

    static func wasShown(on day: LocalDay, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Int == day.ordinal
    }

    static func markShown(on day: LocalDay, defaults: UserDefaults = .standard) {
        defaults.set(day.ordinal, forKey: key)
    }
}

/// The last App Store rating request (`ReviewPrompt` decides when the next
/// one may come).
enum ReviewPromptRecord {
    private static let key = "home.reviewPrompt.v1"

    static func load(defaults: UserDefaults = .standard) -> ReviewPrompt.Record? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReviewPrompt.Record.self, from: data)
    }

    static func save(_ record: ReviewPrompt.Record, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    /// The version the user runs (CFBundleShortVersionString).
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
