import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// The Screen Time lock, shared by the app and its three extensions.
///
/// Model (same as the Expo app): the apps the user picked are shielded for the
/// whole active window. Drinking lifts the shield for one reminder interval,
/// then the DeviceActivity monitor puts it back on its own — app running or
/// not. Every process reads the same state from the App Group, and the shield
/// lives in one named `ManagedSettingsStore`, so any of them can raise or lift
/// it.
///
/// Compiled into four targets with different default isolation, so it stays
/// explicitly `nonisolated` and keeps no shared mutable state.
nonisolated enum Blocker {
    static let appGroup = "group.com.nicomeuwly.hydravia.blocker"

    /// The daily active window, `[wake, sleep]`, repeating.
    static var windowActivity: DeviceActivityName { .init("hydravia.window") }
    /// A one-shot interval starting when an earned unlock runs out.
    static var relockActivity: DeviceActivityName { .init("hydravia.relock") }

    /// Starts with the reminder prefix on purpose: the app treats it as an
    /// unanswered reminder (the ritual card lights up, tapping it opens the
    /// unlock, drinking clears it) without any special case.
    static let shieldNotificationIdentifier = "hydration-reminder-shield"
    static let unlockRoute = "unlock"

    private enum Key {
        static let selection = "blocker.selection.v1"
        static let enabled = "blocker.enabled.v1"
        static let wakeMinute = "blocker.wakeMinute.v1"
        static let sleepMinute = "blocker.sleepMinute.v1"
        static let unlockedUntil = "blocker.unlockedUntil.v1"
        static let progress = "blocker.progress.v1"
        static let proUntil = "blocker.proUntil.v1"
    }

    /// Today's numbers, copied from the app so the shield can talk about them.
    struct Progress: Codable, Equatable {
        var consumedMl: Int
        var goalMl: Int
        /// Days in a row the goal was reached, today excluded.
        var streak: Int
        /// Any moment of the day these numbers belong to.
        var day: Date
    }

    /// Today's progress, or nil when the app hasn't shared any since midnight
    /// (the numbers would be yesterday's).
    static func progress(at date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Progress? {
        guard let data = defaults?.data(forKey: Key.progress),
              let value = try? JSONDecoder().decode(Progress.self, from: data),
              calendar.isDate(value.day, inSameDayAs: date)
        else { return nil }
        return value
    }

    static func setProgress(_ value: Progress) {
        defaults?.set(try? JSONEncoder().encode(value), forKey: Key.progress)
    }

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }
    private static var store: ManagedSettingsStore { ManagedSettingsStore(named: .init("hydravia")) }

    // MARK: State

    /// What the user picked in the system picker. The tokens are opaque: the
    /// app can't tell which apps they are, only hand them back to the system.
    static var selection: FamilyActivitySelection {
        get {
            guard let data = defaults?.data(forKey: Key.selection),
                  let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return value
        }
        set { defaults?.set(try? JSONEncoder().encode(newValue), forKey: Key.selection) }
    }

    /// The lock is wanted (ritual on, Hydravia Pro active, access granted).
    static var isEnabled: Bool {
        get { defaults?.bool(forKey: Key.enabled) ?? false }
        set { defaults?.set(newValue, forKey: Key.enabled) }
    }

    /// The active window in minutes since midnight, copied from the settings
    /// so the extensions can read it.
    static var window: (wake: Int, sleep: Int)? {
        get {
            guard let defaults, defaults.object(forKey: Key.sleepMinute) != nil else { return nil }
            return (defaults.integer(forKey: Key.wakeMinute), defaults.integer(forKey: Key.sleepMinute))
        }
        set {
            defaults?.set(newValue?.wake, forKey: Key.wakeMinute)
            defaults?.set(newValue?.sleep, forKey: Key.sleepMinute)
        }
    }

    /// When the Hydravia Pro entitlement last seen by the app runs out (plus
    /// a renewal margin). Nil: no known limit — `isEnabled` alone decides.
    static var proUntil: Date? {
        get { defaults?.object(forKey: Key.proUntil) as? Date }
        set { defaults?.set(newValue, forKey: Key.proUntil) }
    }

    /// The end of the unlock earned by the last dose, if any.
    static var unlockedUntil: Date? {
        get { defaults?.object(forKey: Key.unlockedUntil) as? Date }
        set { defaults?.set(newValue, forKey: Key.unlockedUntil) }
    }

    static func selectionCount(_ selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    static func isWithinWindow(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard let window else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minute >= window.wake && minute < window.sleep
    }

    static func isUnlocked(at date: Date) -> Bool {
        guard let until = unlockedUntil else { return false }
        return date < until
    }

    /// Whether the selected apps should be shielded right now.
    static func shouldShield(at date: Date = .now) -> Bool {
        isEnabled
            && (proUntil.map { date < $0 } ?? true)
            && selectionCount(selection) > 0
            && isWithinWindow(date)
            && !isUnlocked(at: date)
    }

    static var isShieldUp: Bool {
        store.shield.applications != nil
            || store.shield.applicationCategories != nil
            || store.shield.webDomains != nil
    }

    // MARK: Shield

    /// Makes the shield match `shouldShield()`. Idempotent; every process
    /// calls it whenever something it knows about changed.
    static func refreshShield(at date: Date = .now) {
        shouldShield(at: date) ? raiseShield() : lowerShield()
    }

    static func raiseShield() {
        let selection = selection
        let store = store
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    static func lowerShield() {
        store.clearAllSettings()
    }

    // MARK: Monitoring

    /// Registers (or replaces) the daily window, or stops everything when the
    /// lock is off.
    static func scheduleWindow() throws {
        let center = DeviceActivityCenter()
        guard isEnabled, let window, selectionCount(selection) > 0 else {
            center.stopMonitoring([windowActivity, relockActivity])
            return
        }
        try center.startMonitoring(windowActivity, during: DeviceActivitySchedule(
            intervalStart: DateComponents(hour: window.wake / 60, minute: window.wake % 60),
            intervalEnd: DateComponents(hour: window.sleep / 60, minute: window.sleep % 60),
            repeats: true
        ))
    }

    /// The dose was drunk: lift the shield for `minutes`, and have the monitor
    /// put it back afterwards. An unlock running past bedtime simply ends with
    /// the window.
    static func grantUnlock(until: Date, calendar: Calendar = .autoupdatingCurrent) throws {
        unlockedUntil = until
        lowerShield()

        let center = DeviceActivityCenter()
        center.stopMonitoring([relockActivity])
        guard isEnabled, isWithinWindow(until, calendar: calendar) else { return }
        // DeviceActivity intervals last at least 15 minutes; only the start
        // matters here.
        let start = calendar.dateComponents([.hour, .minute, .second], from: until)
        let end = calendar.dateComponents([.hour, .minute, .second], from: until.addingTimeInterval(16 * 60))
        try center.startMonitoring(relockActivity, during: DeviceActivitySchedule(
            intervalStart: start, intervalEnd: end, repeats: false
        ))
    }

    /// Ends the current unlock now (dev testing: see the shield again without
    /// waiting out the interval).
    static func revokeUnlock() {
        unlockedUntil = nil
        DeviceActivityCenter().stopMonitoring([relockActivity])
        refreshShield()
    }

    // MARK: Shield copy

    /// The shield's strings live in their own catalog, compiled into every
    /// extension, so the shield follows the device language.
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: "Shield")
    }
}
