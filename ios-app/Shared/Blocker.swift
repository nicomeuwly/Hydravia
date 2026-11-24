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
    /// A one-shot interval starting when "Try the lock now" runs out.
    static var trialActivity: DeviceActivityName { .init("hydravia.trial") }

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
        static let hasPro = "blocker.hasPro.v1"
        static let notificationsUsable = "blocker.notificationsUsable.v1"
        static let trialUntil = "blocker.trialUntil.v1"
        static let imperialUnits = "blocker.imperialUnits.v1"
        /// Also written by the quick-add widget (which doesn't compile this
        /// file): keep the two in step.
        static let goalReachedOn = "blocker.goalReachedOn.v1"
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

    /// The lock is wanted (reminders on and allowed by iOS, access granted,
    /// and a selection the plan covers at least in part: `LockGate`).
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

    /// Hydravia Pro as last seen by the app. Nil for installs that predate
    /// this flag: `proUntil` alone decides then.
    static var hasProFlag: Bool? {
        get { defaults?.object(forKey: Key.hasPro) as? Bool }
        set { defaults?.set(newValue, forKey: Key.hasPro) }
    }

    /// Whether the whole pick may be shielded at `date`.
    static func hasPro(at date: Date) -> Bool {
        (hasProFlag ?? true) && (proUntil.map { date < $0 } ?? true)
    }

    /// iOS lets Hydravia show notifications, as last checked by the app (or
    /// found out by the shield's button). The shield's "Drink now" works
    /// through one; without it the shield tells the user to open the app.
    /// Unknown counts as usable.
    static var notificationsUsable: Bool {
        get { defaults?.object(forKey: Key.notificationsUsable) as? Bool ?? true }
        set { defaults?.set(newValue, forKey: Key.notificationsUsable) }
    }

    /// The app's resolved units, mirrored for the shield's copy (the
    /// extensions here don't link HydraviaCore). False until the app says.
    static var imperialUnits: Bool {
        get { defaults?.bool(forKey: Key.imperialUnits) ?? false }
        set { defaults?.set(newValue, forKey: Key.imperialUnits) }
    }

    /// "350 ml", or "12 oz" in imperial: the same rounding as HydraviaCore's
    /// `UnitSystem` (US fluid ounces, a tenth under 10 oz). Keep the two in
    /// step.
    static func amount(ml: Int, imperial: Bool = imperialUnits) -> String {
        guard imperial else { return "\(ml.formatted()) ml" }
        let oz = Double(ml) / 29.5735
        let shown = abs(oz) < 9.95 ? (oz * 10).rounded() / 10 : oz.rounded()
        return "\(shown.formatted(.number.precision(.fractionLength(0...1)))) oz"
    }

    /// The end of the running "Try the lock now", if any.
    static var trialUntil: Date? {
        get { defaults?.object(forKey: Key.trialUntil) as? Date }
        set { defaults?.set(newValue, forKey: Key.trialUntil) }
    }

    /// Same rule as `LockTrial.isActive` in HydraviaCore (not linked here):
    /// at most a minute ahead.
    static func isTrialActive(at date: Date = .now) -> Bool {
        guard let until = trialUntil else { return false }
        return date < until && until.timeIntervalSince(date) <= trialDuration
    }

    /// `LockTrial.duration`.
    static let trialDuration: TimeInterval = 60

    /// The end of the unlock earned by the last dose, if any.
    static var unlockedUntil: Date? {
        get { defaults?.object(forKey: Key.unlockedUntil) as? Date }
        set { defaults?.set(newValue, forKey: Key.unlockedUntil) }
    }

    /// When today's goal was last seen reached (by the app or a widget
    /// pour). Nil once a raised goal or a deleted glass puts it out of reach.
    static var goalReachedOn: Date? {
        get { defaults?.object(forKey: Key.goalReachedOn) as? Date }
        set { defaults?.set(newValue, forKey: Key.goalReachedOn) }
    }

    /// The goal is reached for `date`'s day: the lock rests until tomorrow.
    static func isGoalReached(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard let reached = goalReachedOn else { return false }
        return calendar.isDate(reached, inSameDayAs: date)
    }

    /// Apps, categories and websites added up. Not a number of apps: with
    /// everything picked it is the dozen or so categories.
    static func selectionCount(_ selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    /// The free plan locks one app: no category (a whole family of apps),
    /// no website. Hydravia Pro locks any selection.
    static let freeAppLimit = 1

    static func isWithinFreeLimit(_ selection: FamilyActivitySelection) -> Bool {
        selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
            && selection.applicationTokens.count <= freeAppLimit
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

    /// An earned break is running and no test overrides it: the shield
    /// still on screen is only ManagedSettings catching up.
    static func isOnBreak(at date: Date) -> Bool {
        isUnlocked(at: date) && !isTrialActive(at: date)
    }

    /// The tokens the lock shields: the whole pick with Pro or within the
    /// free limit, else its first app (`BlockSelectionSize.coverage` in
    /// HydraviaCore holds the same rule), else nothing.
    struct Tokens {
        var applications: Set<ApplicationToken> = []
        var categories: Set<ActivityCategoryToken> = []
        var webDomains: Set<WebDomainToken> = []
        var isEmpty: Bool { applications.isEmpty && categories.isEmpty && webDomains.isEmpty }
    }

    static func shieldedTokens(at date: Date = .now) -> Tokens {
        shieldedTokens(of: selection, isPro: hasPro(at: date))
    }

    static func shieldedTokens(of selection: FamilyActivitySelection, isPro: Bool) -> Tokens {
        if isPro || isWithinFreeLimit(selection) {
            return Tokens(applications: selection.applicationTokens,
                          categories: selection.categoryTokens,
                          webDomains: selection.webDomainTokens)
        }
        // The same app every time, in every process: a `Set`'s order isn't.
        guard let first = ordered(selection.applicationTokens).first else { return Tokens() }
        return Tokens(applications: [first])
    }

    /// Whether the selected apps should be shielded right now. A selection
    /// past the free limit needs Pro: a lapse while the app is closed
    /// shields only the first app, what the free plan covers. Once today's
    /// goal is reached the lock rests until the next wake. "Try the lock
    /// now" shields for its minute whatever the hour, goal or break.
    static func shouldShield(at date: Date = .now) -> Bool {
        guard !shieldedTokens(at: date).isEmpty else { return false }
        if isTrialActive(at: date) { return true }
        return isEnabled
            && isWithinWindow(date)
            && !isUnlocked(at: date)
            && !isGoalReached(at: date)
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

    static func raiseShield(at date: Date = .now) {
        let tokens = shieldedTokens(at: date)
        let store = store
        store.shield.applications = tokens.applications.isEmpty ? nil : capped(tokens.applications)
        store.shield.applicationCategories = tokens.categories.isEmpty
            ? nil : .specific(capped(tokens.categories))
        store.shield.webDomains = tokens.webDomains.isEmpty ? nil : capped(tokens.webDomains)
    }

    /// Screen Time shields at most 50 tokens of each kind (Apple's
    /// `ShieldSettings` documentation); `BlockSelectionSize.shieldLimit` in
    /// HydraviaCore, which the extensions don't link, holds the same rule.
    static let shieldTokenLimit = 50

    /// The picker refuses to save a pick past the limit, but one saved
    /// before that guard can still be larger. Handing the system more than
    /// it holds shields an unpredictable part of it, and a `Set`'s order
    /// changes with every process: the app and the monitor would each
    /// leave different apps free. Keep the same tokens every time instead,
    /// ordered by their (opaque but stable) encoding.
    private static func capped<Token: Encodable & Hashable>(_ tokens: Set<Token>) -> Set<Token> {
        guard tokens.count > shieldTokenLimit else { return tokens }
        return Set(ordered(tokens).prefix(shieldTokenLimit))
    }

    private static func ordered<Token: Encodable & Hashable>(_ tokens: Set<Token>) -> [Token] {
        let encoder = JSONEncoder()
        return tokens
            .map { (token: $0, key: (try? encoder.encode($0)) ?? Data()) }
            .sorted { $0.key.lexicographicallyPrecedes($1.key) }
            .map(\.token)
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
        // Turning the lock off stops the relock too: turned back on, an
        // unlock still running must still end at its reminder, or the apps
        // stay free until the app is next opened.
        if let until = unlockedUntil, until > .now {
            try scheduleRelock(at: until)
        }
    }

    /// The dose was drunk: lift the shield until `until`, and have the
    /// monitor put it back then. An unlock running past bedtime simply ends
    /// with the window.
    static func grantUnlock(until: Date, calendar: Calendar = .autoupdatingCurrent) throws {
        unlockedUntil = until
        lowerShield()
        try scheduleRelock(at: until, calendar: calendar)
    }

    private static func scheduleRelock(at until: Date, calendar: Calendar = .autoupdatingCurrent) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([relockActivity])
        guard isEnabled, isWithinWindow(until, calendar: calendar) else { return }
        // DeviceActivity intervals last at least 15 minutes; only the start
        // matters here. A one-shot carries its full date: with the time of
        // day alone the system has to guess which day is meant.
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let start = calendar.dateComponents(parts, from: until)
        let end = calendar.dateComponents(parts, from: until.addingTimeInterval(16 * 60))
        try center.startMonitoring(relockActivity, during: DeviceActivitySchedule(
            intervalStart: start, intervalEnd: end, repeats: false
        ))
    }

    // MARK: Try the lock now

    /// Shields the pick right away until `until` (or until the ritual ends
    /// the test), and has the monitor lower it then, app running or not.
    static func startTrial(until: Date, calendar: Calendar = .autoupdatingCurrent) throws {
        trialUntil = until
        refreshShield()
        let center = DeviceActivityCenter()
        center.stopMonitoring([trialActivity])
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        try center.startMonitoring(trialActivity, during: DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(parts, from: until),
            intervalEnd: calendar.dateComponents(parts, from: until.addingTimeInterval(16 * 60)),
            repeats: false
        ))
    }

    /// The test is over (its minute ran out, or the ritual was done): the
    /// shield goes back to what the real lock wants.
    static func endTrial() {
        guard trialUntil != nil else { return }
        trialUntil = nil
        DeviceActivityCenter().stopMonitoring([trialActivity])
        refreshShield()
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
