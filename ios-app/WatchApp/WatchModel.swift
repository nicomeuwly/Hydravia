import HydraviaCore
import HydraviaData
import Observation
import OSLog
import WatchConnectivity
import WatchKit
import WidgetKit

/// The watch's state and its link to the iPhone.
///
/// The iPhone holds the history: the watch shows its last snapshot plus the
/// pours it hasn't confirmed yet, and keeps sending those until it does.
@MainActor
@Observable
final class WatchModel: NSObject {
    static let shared = WatchModel()

    private(set) var local = WatchLocalState.load()

    @ObservationIgnored private let session: WCSession? = WCSession.isSupported() ? .default : nil
    /// System wake-ups to receive the iPhone's data, completed once it's in.
    @ObservationIgnored private var backgroundTasks: [WKWatchConnectivityRefreshBackgroundTask] = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.nicomeuwly.hydravia.watch", category: "Sync")

    var hasSnapshot: Bool { local.snapshot != nil }
    var hasPro: Bool { local.state.hasPro(at: .now) }
    var favoritesMl: [Int] { Array(local.state.favoritesMl.prefix(3)) }

    func activate() {
        guard let session, session.activationState != .activated else { return }
        session.delegate = self
        session.activate()
    }

    /// Water poured from the watch: counted here at once, then delivered.
    func pour(_ amountMl: Int) {
        guard hasPro, WatchPour.validAmounts.contains(amountMl) else { return }
        let reachedBefore = local.isGoalReached(at: .now)
        let pour = WatchPour(amountMl: amountMl, createdAt: .now)
        local.pending.append(pour)
        persist()
        WKInterfaceDevice.current().play(!reachedBefore && local.isGoalReached(at: .now) ? .success : .click)
        send(pour)
    }

    // MARK: Delivery

    /// Live when the iPhone is in reach (the reply carries its new count),
    /// otherwise queued by the system until it is.
    private func send(_ pour: WatchPour) {
        guard let session, session.activationState == .activated, let data = pour.encoded() else { return }
        guard session.isReachable else { return queue(data, id: pour.id) }
        Self.sendLive(data, on: session) { [weak self] snapshot in
            guard let snapshot else { return }
            Task { @MainActor in self?.apply(snapshot) }
        } failed: { [weak self] in
            Task { @MainActor in self?.queue(data, id: pour.id) }
        }
    }

    /// Built outside the main actor: WatchConnectivity calls these back on
    /// its own queue.
    private nonisolated static func sendLive(
        _ data: Data,
        on session: WCSession,
        reply: @escaping @Sendable (WatchSnapshot?) -> Void,
        failed: @escaping @Sendable () -> Void
    ) {
        session.sendMessage([WatchPour.key: data], replyHandler: { reply(WatchSnapshot.decode($0)) },
                            errorHandler: { _ in failed() })
    }

    private func queue(_ data: Data, id: UUID) {
        guard let session, session.activationState == .activated else { return }
        let queued = session.outstandingUserInfoTransfers.contains { WatchPour.decode($0.userInfo)?.id == id }
        if !queued { session.transferUserInfo([WatchPour.key: data]) }
    }

    /// Everything not confirmed yet goes out again (the iPhone counts a pour
    /// once, however often it arrives).
    private func resendPending() {
        for pour in local.pending {
            if let data = pour.encoded() { queue(data, id: pour.id) }
        }
    }

    // MARK: State

    private func apply(_ snapshot: WatchSnapshot) {
        local.apply(snapshot, now: .now)
        persist()
    }

    /// Saved where the complications read it, and redrawn.
    private func persist() {
        local.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Background

    func hold(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        backgroundTasks.append(task)
        activate()
        finishBackgroundTasksIfDone()
        // Never keep a wake-up open for long, whatever happens.
        Task {
            try? await Task.sleep(for: .seconds(10))
            self.finishBackgroundTasks()
        }
    }

    private func finishBackgroundTasksIfDone() {
        guard let session, session.activationState == .activated, !session.hasContentPending else { return }
        finishBackgroundTasks()
    }

    private func finishBackgroundTasks() {
        for task in backgroundTasks { task.setTaskCompletedWithSnapshot(false) }
        backgroundTasks.removeAll()
    }
}

extension WatchModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: (any Error)?) {
        let snapshot = WatchSnapshot.decode(session.receivedApplicationContext)
        Task { @MainActor in
            if let snapshot { self.apply(snapshot) }
            self.resendPending()
            self.finishBackgroundTasksIfDone()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let snapshot = WatchSnapshot.decode(context)
        Task { @MainActor in
            if let snapshot { self.apply(snapshot) }
            self.finishBackgroundTasksIfDone()
        }
    }

    /// The iPhone's complication updates arrive this way.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let snapshot = WatchSnapshot.decode(userInfo)
        Task { @MainActor in
            if let snapshot { self.apply(snapshot) }
            self.finishBackgroundTasksIfDone()
        }
    }

    /// The iPhone came into reach: deliver what waited.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in self.resendPending() }
    }
}
