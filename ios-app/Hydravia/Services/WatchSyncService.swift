import HydraviaCore
import HydraviaData
import OSLog
import WatchConnectivity
import WidgetKit

/// The iPhone's side of the Apple Watch app: it counts the watch's pours
/// into the history and sends the watch today's numbers.
///
/// The iPhone holds the history; the watch keeps a copy (`WatchSnapshot`)
/// and the pours it couldn't deliver yet. Nothing leaves the two devices.
@MainActor
final class WatchSyncService: NSObject {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let hydration: HydrationStore
    private let settings: SettingsStore
    private let blocker: BlockerService
    private let reminders: ReminderService
    private let logger = Logger(subsystem: "com.nicomeuwly.hydravia", category: "Watch")
    /// The last numbers sent to the watch face, so complication updates
    /// (a few dozen a day) are only spent on a change.
    private var lastComplication: String?

    /// The watch pours already counted, by when (forgotten after two days).
    private static let countedKey = "watch.countedPours.v1"
    private var counted: [UUID: Date] {
        get {
            (UserDefaults.standard.data(forKey: Self.countedKey))
                .flatMap { try? JSONDecoder().decode([UUID: Date].self, from: $0) } ?? [:]
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: Self.countedKey) }
    }

    init(hydration: HydrationStore, settings: SettingsStore, blocker: BlockerService, reminders: ReminderService) {
        self.hydration = hydration
        self.settings = settings
        self.blocker = blocker
        self.reminders = reminders
        super.init()
        // At launch: a pour sent while the app was closed wakes it, and is
        // delivered once the session is active.
        session?.delegate = self
        session?.activate()
    }

    /// Today's numbers for the watch, once the widgets' copy of the settings
    /// and plan exists (written by the app after the App Store answers).
    private func snapshot() -> WatchSnapshot? {
        guard let state = WidgetState.load() else { return nil }
        return WatchSnapshot(
            state: state,
            day: hydration.today,
            consumedMl: hydration.todayTotalMl,
            streak: Streak.current(hydration.streakTotals, goalMl: state.goalMl, today: hydration.today),
            countedPours: Array(counted.keys)
        )
    }

    /// Sends the watch the latest numbers. Called on every drink and every
    /// change of goal, amounts, schedule or plan. Only the latest matters,
    /// so the system delivers it when the watch app next runs.
    func push() {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let snapshot = snapshot(), let data = snapshot.encoded()
        else { return }
        do {
            try session.updateApplicationContext([WatchSnapshot.key: data])
        } catch {
            logger.error("Could not update the watch: \(error.localizedDescription, privacy: .public)")
        }
        // A complication on the watch face: wake the watch app to redraw it.
        let face = "\(snapshot.day)-\(snapshot.consumedMl)-\(snapshot.state.goalMl)-\(snapshot.state.hasPro(at: .now))"
        if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0, face != lastComplication {
            session.transferCurrentComplicationUserInfo([WatchSnapshot.key: data])
            lastComplication = face
        }
    }

    /// A pour from the watch: counted once (the watch may send it again),
    /// and only with Pro, like the widget buttons.
    private func receive(_ pour: WatchPour) {
        guard WidgetState.load()?.hasPro(at: .now) == true else { return }
        let result = WatchTally.receive(pour, counted: counted, now: .now)
        counted = result.counted
        guard result.isNew else { return }
        do {
            try hydration.restore(amountMl: pour.amountMl, createdAt: pour.createdAt, source: .watch)
        } catch {
            counted[pour.id] = nil
            logger.error("Could not save a watch pour: \(error.localizedDescription, privacy: .public)")
            return
        }
        // The app may be in the background (woken by the watch): what
        // RootView does on a drink is done here too. The shield follows the
        // goal, and a goal reached drops today's reminders.
        let goal = settings.dailyGoalMl
        blocker.shareProgress(
            consumedMl: hydration.todayTotalMl,
            goalMl: goal,
            streak: Streak.current(hydration.streakTotals, goalMl: goal, today: hydration.today)
        )
        if hydration.todayTotalMl >= goal {
            Task { await reminders.restForToday() }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// A value crossing from WatchConnectivity's queue to the main actor. The
/// reply handler is only ever called once, on the main actor.
private nonisolated struct Unchecked<Value>: @unchecked Sendable {
    let value: Value
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in self.push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Switching to another watch: activate again for the new one.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// The watch app installed or a complication added: send it the numbers.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.push() }
    }

    /// A live pour (the watch reached the iPhone): the reply carries the new
    /// count, so the watch shows it at once.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        let pour = WatchPour.decode(message)
        let reply = Unchecked(value: replyHandler)
        Task { @MainActor in
            if let pour { self.receive(pour) }
            let data = self.snapshot()?.encoded()
            reply.value(data.map { [WatchSnapshot.key: $0] } ?? [:])
            self.push()
        }
    }

    /// A queued pour (sent while the iPhone was out of reach).
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let pour = WatchPour.decode(userInfo)
        Task { @MainActor in
            if let pour { self.receive(pour) }
            self.push()
        }
    }
}
