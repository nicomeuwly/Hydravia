import FamilyControls
import HydraviaCore
import Observation
import OSLog

/// The app's side of the Screen Time lock: permission, the apps to shield,
/// and lifting the shield once the dose is drunk. The rules themselves live
/// in `Blocker`, shared with the extensions that apply them when the app
/// isn't running.
///
/// Screen Time needs a real device: on the simulator authorization fails and
/// the lock simply stays off.
@MainActor
@Observable
final class BlockerService {
    enum Authorization { case notDetermined, granted, denied }

    private(set) var authorization: Authorization
    /// The picker's binding. Saved and applied by `setSelection`.
    private(set) var selection: FamilyActivitySelection
    /// The shield is up right now: opening the app should lead to the ritual.
    /// Read live — the monitor extension raises it while the app is away.
    var isShieldUp: Bool { Blocker.isShieldUp }

    var selectionCount: Int { Blocker.selectionCount(selection) }

    /// Hydravia Pro (or a dev build), as last handed over by `RootView`.
    private(set) var isPro = false

    /// Whether the plan covers `selection`: one app on the free plan,
    /// anything with Pro.
    func covers(_ selection: FamilyActivitySelection) -> Bool {
        isPro || Blocker.isWithinFreeLimit(selection)
    }

    /// The saved selection is past the free limit (picked during a trial, or
    /// before onboarding's paywall): the lock waits for the user to pick the
    /// one app the free plan locks, or for Pro.
    var needsAppChoice: Bool {
        authorization == .granted && selectionCount > 0 && !covers(selection)
    }

    /// The last schedule handed over by `RootView`, re-applied when the
    /// selection changes.
    @ObservationIgnored private var window: ActiveWindow?
    @ObservationIgnored private var wanted = false
    @ObservationIgnored private var scheduled: String?
    @ObservationIgnored private let logger = Logger(subsystem: "com.nicomeuwly.hydravia", category: "Blocker")

    init() {
        authorization = Self.read(AuthorizationCenter.shared.authorizationStatus)
        selection = Blocker.selection
    }

    private static func read(_ status: AuthorizationStatus) -> Authorization {
        switch status {
        case .approved: .granted
        case .denied: .denied
        default: .notDetermined
        }
    }

    /// Shows the system's Screen Time prompt (Face ID / passcode).
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            logger.error("Screen Time authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        authorization = Self.read(AuthorizationCenter.shared.authorizationStatus)
        apply()
        return authorization == .granted
    }

    /// Turns the lock off from the app (iOS Settings has no switch for it
    /// on the app's page). Screen Time lowers any shield itself.
    func revokeAuthorization() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            AuthorizationCenter.shared.revokeAuthorization { result in
                if case .failure(let error) = result {
                    Logger(subsystem: "com.nicomeuwly.hydravia", category: "Blocker")
                        .error("Screen Time revoke failed: \(error.localizedDescription, privacy: .public)")
                }
                done.resume()
            }
        }
        authorization = Self.read(AuthorizationCenter.shared.authorizationStatus)
        apply()
    }

    func setSelection(_ newValue: FamilyActivitySelection) {
        selection = newValue
        Blocker.selection = newValue
        apply()
    }

    /// Mirrors the reminder schedule: the lock runs during the same window,
    /// and only while the ritual is on.
    /// `force` re-registers the schedule even if nothing it depends on
    /// changed (a new time zone).
    func sync(window: ActiveWindow, enabled: Bool, isPro: Bool, force: Bool = false) {
        self.window = window
        wanted = enabled
        self.isPro = isPro
        // Permission can be revoked in iOS Settings while the app is away.
        authorization = Self.read(AuthorizationCenter.shared.authorizationStatus)
        if force { scheduled = nil }
        apply()
    }

    /// The dose is drunk: the phone is free until the next reminder, so
    /// that reminder finds the apps locked whenever the dose was drunk (at
    /// least `ActiveWindow.minimumBreakMin` away). After the day's last
    /// reminder, free until bedtime.
    func unlockAfterDrinking(window: ActiveWindow, now: Date = .now) {
        let calendar = Calendar.autoupdatingCurrent
        let minute = MinuteOfDay(now, calendar: calendar)
        let end = window.unlockEnd(after: minute) ?? window.sleep
        let until = calendar.date(bySettingHour: end.value / 60, minute: end.value % 60, second: 0, of: now)
            ?? now.addingTimeInterval(TimeInterval(window.intervalMin * 60))
        do {
            try Blocker.grantUnlock(until: until)
        } catch {
            logger.error("Could not schedule the relock: \(error.localizedDescription, privacy: .public)")
        }
    }

    #if DEBUG
    /// Dev only: drops the earned unlock so the shield comes back right away.
    func relockNow() { Blocker.revokeUnlock() }
    #endif

    /// Hands today's numbers to the shield, which can't read the database.
    func shareProgress(consumedMl: Int, goalMl: Int, streak: Int) {
        Blocker.setProgress(.init(consumedMl: consumedMl, goalMl: goalMl, streak: streak, day: .now))
    }

    private func apply() {
        if let window {
            Blocker.window = (window.wake.value, window.sleep.value)
        }
        Blocker.isEnabled = wanted && authorization == .granted && covers(selection)
        // Re-registering a running schedule restarts it, so only touch it
        // when what it depends on changed.
        let schedule = "\(Blocker.isEnabled)-\(selectionCount > 0)-\(window?.wake.value ?? -1)-\(window?.sleep.value ?? -1)"
        if schedule != scheduled {
            do {
                try Blocker.scheduleWindow()
                scheduled = schedule
            } catch {
                logger.error("Could not schedule the active window: \(error.localizedDescription, privacy: .public)")
            }
        }
        Blocker.refreshShield()
    }
}
