import Combine
import FamilyControls
import HydraviaCore
import ManagedSettings
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

    /// The saved pick, counted by kind (what Settings shows).
    var selectionSize: BlockSelectionSize { Self.size(of: selection) }

    static func size(of selection: FamilyActivitySelection) -> BlockSelectionSize {
        BlockSelectionSize(apps: selection.applicationTokens.count,
                           categories: selection.categoryTokens.count,
                           webDomains: selection.webDomainTokens.count)
    }

    /// Screen Time can shield all of `selection` (at most 50 single apps,
    /// 50 websites and 50 categories). A bigger pick would leave some of
    /// the picked apps free, so the picker doesn't save it.
    func canEnforce(_ selection: FamilyActivitySelection) -> Bool {
        Self.size(of: selection).isEnforceable
    }

    /// A pick saved before the picker checked the limit is too big: only
    /// part of it is shielded until the user trims it.
    var needsSmallerSelection: Bool {
        authorization == .granted && !selectionSize.isEnforceable
    }

    /// Hydravia Pro (or a dev build), as last handed over by `RootView`.
    private(set) var isPro = false

    /// Whether the plan covers all of `selection`: one app on the free plan,
    /// anything with Pro. The picker only saves such a pick.
    func covers(_ selection: FamilyActivitySelection) -> Bool {
        isPro || Blocker.isWithinFreeLimit(selection)
    }

    /// What the lock shields of the saved pick on the current plan.
    var coverage: LockCoverage { selectionSize.coverage(isPro: isPro) }

    /// The saved selection is past the free limit with no single app in it
    /// (categories or websites only): nothing the free plan can lock, so
    /// the lock waits for the user to pick one app, or for Pro.
    var needsAppChoice: Bool {
        authorization == .granted && selectionCount > 0 && coverage == .none
    }

    /// Several apps picked on the free plan: only this one is locked (the
    /// first, in a stable order). Nil when the whole pick is locked.
    var freePlanLockedApp: ApplicationToken? {
        guard authorization == .granted, coverage == .firstApp else { return nil }
        return Blocker.shieldedTokens(of: selection, isPro: false).applications.first
    }

    /// iOS lets Hydravia show notifications (as last checked by `RootView`).
    /// The lock only engages with them: every reminder and the shield's
    /// "Drink now" go through one.
    private(set) var notificationsUsable = Blocker.notificationsUsable

    // MARK: Try the lock now

    /// The end of the running test, if any.
    private(set) var trialUntil: Date?
    @ObservationIgnored private var trialTimer: Task<Void, Never>?

    var trialAvailability: LockTrial.Availability {
        LockTrial.availability(screenTimeGranted: authorization == .granted, selection: selectionSize, isPro: isPro)
    }

    /// Shields the picked apps for a minute, now, whatever the hour: the
    /// whole chain (shield → "Drink now" → ritual → unlock) without waiting
    /// for a reminder. The ritual ends it early.
    func startTrial(now: Date = .now) {
        guard trialAvailability == .available else { return }
        let until = LockTrial.end(startingAt: now)
        do {
            try Blocker.startTrial(until: until)
        } catch {
            // The shield is up anyway; only the monitor's fallback is missing,
            // and the timer below and every return to the app cover it.
            logger.error("Could not schedule the end of the test: \(error.localizedDescription, privacy: .public)")
        }
        trialUntil = until
        trialTimer?.cancel()
        trialTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, until.timeIntervalSinceNow) + 0.5))
            guard !Task.isCancelled else { return }
            self?.endTrialIfOver()
        }
    }

    func endTrial() {
        trialTimer?.cancel()
        trialTimer = nil
        trialUntil = nil
        Blocker.endTrial()
    }

    /// The monitor or the clock may have ended the test while the app was
    /// away: picks that up.
    private func endTrialIfOver() {
        if Blocker.isTrialActive() {
            trialUntil = Blocker.trialUntil
        } else if trialUntil != nil || Blocker.trialUntil != nil {
            endTrial()
        }
    }

    /// The last schedule handed over by `RootView`, re-applied when the
    /// selection changes.
    @ObservationIgnored private var window: ActiveWindow?
    @ObservationIgnored private var wanted = false
    @ObservationIgnored private var scheduled: String?
    @ObservationIgnored private let logger = Logger(subsystem: "com.nicomeuwly.hydravia", category: "Blocker")
    @ObservationIgnored private var statusUpdates: AnyCancellable?

    init() {
        let status = Self.read(AuthorizationCenter.shared.authorizationStatus)
        // A lock left on by the last run was approved: FamilyControls may
        // simply not have loaded the status yet (see `readAuthorization`).
        authorization = status == .notDetermined && Blocker.isEnabled ? .granted : status
        selection = Blocker.selection
        trialUntil = Blocker.isTrialActive() ? Blocker.trialUntil : nil
        // The real status arrives a moment after launch.
        statusUpdates = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                MainActor.assumeIsolated {
                    guard let self, self.readAuthorization(status) else { return }
                    self.apply()
                }
            }
    }

    /// Takes in a status read from FamilyControls; true when it changed.
    ///
    /// Right after launch FamilyControls can report `.notDetermined` for an
    /// app it has approved, until it has loaded the real status. Taken at
    /// face value, that read turned the lock off: `apply` stopped the window
    /// and the pending relock and lowered the shield, so the apps stayed
    /// free at the next reminders, depending on how quickly the status
    /// loaded at each launch. An approved app only goes back to
    /// `.notDetermined` through `revokeAuthorization`, which sets the status
    /// itself (a revoke in iOS Settings reads `.denied`).
    @discardableResult
    private func readAuthorization(_ status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus) -> Bool {
        let value = Self.read(status)
        guard value != authorization, !(value == .notDetermined && authorization == .granted) else { return false }
        authorization = value
        return true
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
    /// `notificationsUsable`: what iOS allows right now (nil keeps the last
    /// known answer).
    func sync(window: ActiveWindow, enabled: Bool, isPro: Bool, notificationsUsable: Bool? = nil,
              force: Bool = false) {
        self.window = window
        wanted = enabled
        self.isPro = isPro
        if let notificationsUsable {
            self.notificationsUsable = notificationsUsable
            Blocker.notificationsUsable = notificationsUsable
        }
        Blocker.hasProFlag = isPro
        endTrialIfOver()
        // Permission can be revoked in iOS Settings while the app is away.
        readAuthorization()
        if force { scheduled = nil }
        apply()
    }

    /// The dose is drunk: the phone is free until the next reminder, so
    /// that reminder finds the apps locked whenever the dose was drunk (at
    /// least `ActiveWindow.answerWindowMin` away). After the day's last
    /// reminder, free until bedtime.
    func unlockAfterDrinking(window: ActiveWindow, now: Date = .now) {
        // The ritual done during "Try the lock now" ends the test too.
        endTrial()
        grantUnlock(until: Self.unlockEnd(window: window, drinkAt: now))
    }

    /// A glass logged without the ritual (by hand, from the watch or a
    /// widget) just before the reminder that ends the running unlock answers
    /// that reminder: the break runs on to the next one, which still comes.
    /// The notifications skip the same reminder (`ReminderPlan`). A shield
    /// that is up stays up: only the ritual lifts it.
    func extendUnlock(window: ActiveWindow, drinkAt: Date) {
        guard let until = Blocker.unlockedUntil, Blocker.isUnlocked(at: .now), drinkAt < until else { return }
        let extended = Self.unlockEnd(window: window, drinkAt: drinkAt)
        guard extended > until else { return }
        grantUnlock(until: extended)
    }

    /// The first reminder a drink at `drinkAt` doesn't answer, or bedtime.
    private static func unlockEnd(window: ActiveWindow, drinkAt: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let end = window.unlockEnd(after: MinuteOfDay(drinkAt, calendar: calendar)) ?? window.sleep
        return calendar.date(bySettingHour: end.value / 60, minute: end.value % 60, second: 0, of: drinkAt)
            ?? drinkAt.addingTimeInterval(TimeInterval(window.intervalMin * 60))
    }

    private func grantUnlock(until: Date) {
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
        // Goal reached: the lock rests for the rest of the day; a raised goal
        // or a deleted glass brings it back.
        // Refreshed every time: a widget pour may have reached the goal while
        // the app was closed, and the widget can't lower a raised shield.
        let reached = goalMl > 0 && consumedMl >= goalMl
        if reached != Blocker.isGoalReached(at: .now) {
            Blocker.goalReachedOn = reached ? .now : nil
        }
        Blocker.refreshShield()
    }

    private func apply() {
        if let window {
            Blocker.window = (window.wake.value, window.sleep.value)
        }
        Blocker.isEnabled = LockGate.isEngaged(remindersWanted: wanted, screenTimeGranted: authorization == .granted,
                                               notificationsUsable: notificationsUsable, coverage: coverage)
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
