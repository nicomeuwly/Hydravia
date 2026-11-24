import Foundation
import HydraviaCore
import Observation
import OSLog

/// Everything the user configures. A plain value: easy to diff, to preview
/// and to test.
public struct UserSettings: Codable, Equatable, Sendable {
    public var weightKg: Int
    /// The exact pounds when the weight was picked in pounds (see `BodyWeight`).
    public var weightLb: Int?
    public var window: ActiveWindow
    public var notificationsEnabled: Bool
    public var onboardingDone: Bool
    /// The three amounts the add-water sheet offers, smallest first.
    public var favoriteAmountsMl: [Int]
    /// Millilitres or fluid ounces on screen; storage stays metric.
    public var unitPreference: UnitPreference

    public static let defaultFavoriteAmountsMl = UnitSystem.metric.defaultFavoritesMl
    public static let favoriteCount = 3
    public static let favoriteRangeMl = 50...1000
    public static let favoriteStepMl = 10

    public static let defaults = UserSettings(
        weightKg: 70,
        window: ActiveWindow(
            wake: MinuteOfDay(hour: 7, minute: 0),
            sleep: MinuteOfDay(hour: 22, minute: 0),
            intervalMin: 60
        ),
        notificationsEnabled: false,
        onboardingDone: false,
        favoriteAmountsMl: defaultFavoriteAmountsMl,
        unitPreference: .automatic
    )

    public init(
        weightKg: Int,
        window: ActiveWindow,
        notificationsEnabled: Bool,
        onboardingDone: Bool,
        favoriteAmountsMl: [Int] = UserSettings.defaultFavoriteAmountsMl,
        unitPreference: UnitPreference = .automatic,
        weightLb: Int? = nil
    ) {
        self.weightKg = weightKg
        self.weightLb = weightLb
        self.window = window
        self.notificationsEnabled = notificationsEnabled
        self.onboardingDone = onboardingDone
        self.favoriteAmountsMl = favoriteAmountsMl
        self.unitPreference = unitPreference
    }

    /// The presets as the screens offer them: untouched metric defaults
    /// become 8 / 12 / 16 oz for imperial, rather than 6.8 / 11 / 17 oz.
    public func favoriteAmountsMl(for system: UnitSystem) -> [Int] {
        favoriteAmountsMl == Self.defaultFavoriteAmountsMl ? system.defaultFavoritesMl : favoriteAmountsMl
    }

    public var dailyGoalMl: Int { HydrationGoal.dailyMl(weightKg: weightKg) }

    public var bodyWeight: BodyWeight {
        get { BodyWeight(kg: weightKg, pounds: weightLb) }
        set {
            weightKg = newValue.kg
            weightLb = newValue.pounds
        }
    }

    public static let weightRangeKg = 30...250

    /// Settings forced back into what the screens can express (weight within
    /// the picker's range, a possible active window), whatever was stored.
    public var sanitized: UserSettings {
        var copy = self
        copy.weightKg = min(max(weightKg, Self.weightRangeKg.lowerBound), Self.weightRangeKg.upperBound)
        // Pounds that no longer match the kilograms (changed in kg since) go.
        if let pounds = weightLb, UnitSystem.kg(fromPounds: pounds) != copy.weightKg { copy.weightLb = nil }
        copy.window = window.sanitized
        copy.favoriteAmountsMl = Self.sanitizedFavorites(favoriteAmountsMl)
        return copy
    }

    /// Exactly three amounts, each within range on the 10 ml grid (or on a
    /// whole fluid ounce, as the imperial stepper sets them), smallest
    /// first. Missing ones come from the defaults.
    static func sanitizedFavorites(_ amounts: [Int]) -> [Int] {
        var list = Array(amounts.prefix(favoriteCount))
        if list.count < favoriteCount {
            list += defaultFavoriteAmountsMl.suffix(favoriteCount - list.count)
        }
        let range = favoriteRangeMl, step = favoriteStepMl
        return list
            .map { amount in
                let ounce = UnitSystem.ml(fromFluidOunces: UnitSystem.fluidOunces(fromMl: Double(amount)).rounded())
                let snapped = ounce == amount ? amount : (amount + step / 2) / step * step
                return min(max(snapped, range.lowerBound), range.upperBound)
            }
            .sorted()
    }

    // Every field falls back to its default when absent, so adding a setting
    // in a later version never wipes the ones a user already chose.
    private enum CodingKeys: String, CodingKey {
        case weightKg, weightLb, window, notificationsEnabled, onboardingDone, favoriteAmountsMl, unitPreference
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.defaults
        weightKg = try container.decodeIfPresent(Int.self, forKey: .weightKg) ?? fallback.weightKg
        weightLb = try? container.decodeIfPresent(Int.self, forKey: .weightLb)
        window = try container.decodeIfPresent(ActiveWindow.self, forKey: .window) ?? fallback.window
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled)
            ?? fallback.notificationsEnabled
        onboardingDone = try container.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? fallback.onboardingDone
        favoriteAmountsMl = try container.decodeIfPresent([Int].self, forKey: .favoriteAmountsMl)
            ?? fallback.favoriteAmountsMl
        // An unknown raw value (a later version's option) falls back too.
        unitPreference = (try? container.decodeIfPresent(UnitPreference.self, forKey: .unitPreference))
            ?? fallback.unitPreference
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
    /// Where "Automatic" units come from: the region's measurement system.
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let logger = Logger(subsystem: "com.nicomeuwly.hydravia", category: "Settings")
    static let storageKey = "userSettings.v1"

    /// `.standard` on purpose: no extension reads these settings. If one ever
    /// must, switch to the App Group suite and copy the value over once.
    public init(defaults: UserDefaults = .standard, locale: Locale = .autoupdatingCurrent) {
        self.defaults = defaults
        self.locale = locale
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

    /// The units every screen formats with, the preference resolved
    /// against the region.
    public var unitSystem: UnitSystem { settings.unitPreference.resolved(for: locale.measurementSystem) }

    /// The add-water presets in the current units.
    public var favoriteAmountsMl: [Int] { settings.favoriteAmountsMl(for: unitSystem) }

    private func persist() {
        do {
            defaults.set(try JSONEncoder().encode(settings), forKey: Self.storageKey)
        } catch {
            logger.error("Could not persist settings: \(error.localizedDescription, privacy: .public)")
        }
    }
}
