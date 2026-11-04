import Foundation
import HydraviaCore
import Observation
import OSLog

/// Everything the user configures. A plain value: easy to diff, to preview
/// and to test.
public struct UserSettings: Codable, Equatable, Sendable {
    public var weightKg: Int
    public var window: ActiveWindow
    public var notificationsEnabled: Bool
    public var onboardingDone: Bool

    public static let defaults = UserSettings(
        weightKg: 70,
        window: ActiveWindow(
            wake: MinuteOfDay(hour: 7, minute: 0),
            sleep: MinuteOfDay(hour: 22, minute: 0),
            intervalMin: 60
        ),
        notificationsEnabled: false,
        onboardingDone: false
    )

    public init(weightKg: Int, window: ActiveWindow, notificationsEnabled: Bool, onboardingDone: Bool) {
        self.weightKg = weightKg
        self.window = window
        self.notificationsEnabled = notificationsEnabled
        self.onboardingDone = onboardingDone
    }

    public var dailyGoalMl: Int { HydrationGoal.dailyMl(weightKg: weightKg) }

    public static let weightRangeKg = 30...250

    /// Settings forced back into what the screens can express (weight within
    /// the picker's range, a possible active window), whatever was stored.
    public var sanitized: UserSettings {
        var copy = self
        copy.weightKg = min(max(weightKg, Self.weightRangeKg.lowerBound), Self.weightRangeKg.upperBound)
        copy.window = window.sanitized
        return copy
    }

    // Every field falls back to its default when absent, so adding a setting
    // in a later version never wipes the ones a user already chose.
    private enum CodingKeys: String, CodingKey {
        case weightKg, window, notificationsEnabled, onboardingDone
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.defaults
        weightKg = try container.decodeIfPresent(Int.self, forKey: .weightKg) ?? fallback.weightKg
        window = try container.decodeIfPresent(ActiveWindow.self, forKey: .window) ?? fallback.window
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled)
            ?? fallback.notificationsEnabled
        onboardingDone = try container.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? fallback.onboardingDone
    }
}

/// Persists `UserSettings` as one JSON document in `UserDefaults`.
///
/// Settings are a handful of scalars read synchronously at launch (to pick
/// onboarding vs. home), which is exactly what `UserDefaults` is for; they
/// don't belong in the SwiftData store next to the entries.
@MainActor
@Observable
public final class SettingsStore {
    public var settings: UserSettings {
        didSet {
            // Anything assigned is forced back into range first; the
            // re-assignment re-enters didSet once, already clean.
            let clean = settings.sanitized
            if clean != settings { settings = clean; return }
            guard settings != oldValue else { return }
            persist()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let logger = Logger(subsystem: "com.nicomeuwly.hydravia", category: "Settings")
    static let storageKey = "userSettings.v1"

    /// `.standard` on purpose: no extension reads these settings. If one ever
    /// must, switch to the App Group suite and copy the value over once.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded = UserSettings.defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            do {
                loaded = try JSONDecoder().decode(UserSettings.self, from: data)
            } catch {
                // Corrupt settings would silently re-run onboarding: say so.
                logger.fault("Stored settings unreadable, using defaults: \(error.localizedDescription, privacy: .public)")
            }
        }
        settings = loaded.sanitized
    }

    public var dailyGoalMl: Int { settings.dailyGoalMl }

    private func persist() {
        do {
            defaults.set(try JSONEncoder().encode(settings), forKey: Self.storageKey)
        } catch {
            logger.error("Could not persist settings: \(error.localizedDescription, privacy: .public)")
        }
    }
}
