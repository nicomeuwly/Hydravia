import HydraviaCore
import OSLog
import UserNotifications

/// Local hydration reminders and their taps.
///
/// Set as the notification-center delegate at launch (before the first scene
/// exists) so a reminder tapped while the app was closed still opens the
/// unlock ritual.
@MainActor
final class ReminderService: NSObject {
    enum Permission { case notDetermined, granted, denied }

    /// Reminder identifiers share this prefix, so rescheduling never wipes
    /// unrelated one-shots (like the trial-end heads-up).
    nonisolated static let identifierPrefix = "hydration-reminder-"
    nonisolated static let trialEndIdentifier = "trial-end-reminder"
    nonisolated static let unlockRoute = "unlock"

    private let center = UNUserNotificationCenter.current()
    /// The schedule being applied. Calls are serialised through it so two
    /// quick settings changes can never interleave and leave the older one
    /// winning.
    private var rescheduleTask: Task<Void, Never>?
    private let router: AppRouter
    private let logger = Logger(subsystem: "com.nicomeuwly.hydravia", category: "Reminders")

    /// Bodies rotate across the day's slots so reminders never go stale.
    /// With the ritual (Pro) they talk about the paused apps…
    private static let bodies: [LocalizedStringResource] = [
        .notifReminderBody1, .notifReminderBody2, .notifReminderBody3, .notifReminderBody4,
    ]
    /// …without it there's no lock, so they just say it's time to drink.
    private static let freeBodies: [LocalizedStringResource] = [
        .notifFreeBody1, .notifFreeBody2, .notifFreeBody3,
    ]

    init(router: AppRouter) {
        self.router = router
        super.init()
        center.delegate = self
    }

    // MARK: Permission

    func permission() async -> Permission {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorized, .provisional, .ephemeral: .granted
        default: .denied
        }
    }

    /// Shows the system prompt. iOS only ever shows it once — callers check
    /// `permission()` first and send a `.denied` user to Settings instead.
    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: Scheduling

    /// Makes the hydration reminders match `window`: one daily repeating
    /// notification per slot. `enabled == false` (user choice, no
    /// permission) just clears them. `ritual` (Hydravia Pro) picks the copy
    /// and makes a tap open the unlock ritual; free reminders open the app.
    ///
    /// Serialised: a newer call cancels the one in flight and waits for it,
    /// so the latest settings always win.
    func reschedule(window: ActiveWindow, enabled: Bool, ritual: Bool) async {
        let previous = rescheduleTask
        previous?.cancel()
        let task = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await self.apply(window: window, enabled: enabled, ritual: ritual)
        }
        rescheduleTask = task
        await task.value
    }

    private func apply(window: ActiveWindow, enabled: Bool, ritual: Bool) async {
        let granted = enabled ? await permission() == .granted : false
        let wanted = granted ? requests(for: window, ritual: ritual) : []
        guard !Task.isCancelled else { return }

        // Remove only what is no longer wanted; `add` replaces same-id
        // requests, so there is never a window with no reminders scheduled.
        let wantedIDs = Set(wanted.map(\.identifier))
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) && !wantedIDs.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        for request in wanted {
            guard !Task.isCancelled else { return }
            do {
                try await center.add(request)
            } catch {
                logger.error("Could not schedule \(request.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Copy is resolved now, in the current language; the app reschedules on
    /// every return to the foreground, so a language change catches up.
    /// Triggers carry no time zone: they follow the device's, so 08:00 stays
    /// 08:00 wall-clock after travelling.
    private func requests(for window: ActiveWindow, ritual: Bool) -> [UNNotificationRequest] {
        let bodies = ritual ? Self.bodies : Self.freeBodies
        return window.reminderSlots.enumerated().map { index, slot in
            let content = UNMutableNotificationContent()
            content.title = String(localized: .notifReminderTitle)
            content.body = String(localized: bodies[index % bodies.count])
            content.sound = .default
            if ritual { content.userInfo = ["route": Self.unlockRoute] }
            content.threadIdentifier = "hydration"

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: slot.hour, minute: slot.minute),
                repeats: true
            )
            return UNNotificationRequest(
                identifier: "\(Self.identifierPrefix)\(slot.hour)-\(slot.minute)",
                content: content,
                trigger: trigger
            )
        }
    }

    #if DEBUG
    /// Dev only: one reminder in `seconds`, identical to a real one, to test
    /// the banner → tap → ritual chain without waiting for a slot.
    func scheduleTestReminder(in seconds: TimeInterval = 10) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: .notifReminderTitle)
        content.body = String(localized: Self.bodies[0])
        content.sound = .default
        content.userInfo = ["route": Self.unlockRoute]
        let request = UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)test",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        try? await center.add(request)
    }
    #endif

    /// The heads-up the paywall's timeline promises, at `date` (computed by
    /// StoreService from the real trial end). Re-adding replaces it, so this
    /// is safe to call on every entitlement refresh. Best-effort: no-op
    /// without permission.
    func scheduleTrialEndReminder(at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: .notifTrialEndTitle)
        content.body = String(localized: .notifTrialEndBody)
        let parts = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(
            identifier: Self.trialEndIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        try? await center.add(request)
    }

    /// Trial cancelled, refunded or over: no heads-up about a charge that
    /// won't happen.
    func cancelTrialEndReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.trialEndIdentifier])
    }

    // MARK: Delivered reminders

    /// Whether a reminder was delivered and not answered yet — a banner the
    /// user saw but didn't tap still means "time to drink" when they open
    /// the app.
    func hasUnansweredReminder() async -> Bool {
        let delivered = await center.deliveredNotifications()
        return delivered.contains { $0.request.identifier.hasPrefix(Self.identifierPrefix) }
    }

    /// Called once the dose is drunk: the delivered reminders are answered.
    func clearDeliveredReminders() async {
        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(
            withIdentifiers: delivered.map(\.request.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        )
    }
}

extension ReminderService: UNUserNotificationCenterDelegate {
    // Completion-handler variants on purpose. With the `async` variants, Swift
    // resumes the system's completion handler from a background executor, and
    // UIKit asserts it runs on the main thread — a cold launch from a tapped
    // reminder crashed on a black screen. iOS calls this delegate on the main
    // queue, so everything below runs synchronously there.

    /// A reminder arriving while the app is open: show it, and turn the home
    /// screen's ritual card into the way into the unlock.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let isReminder = notification.request.identifier.hasPrefix(Self.identifierPrefix)
        MainActor.assumeIsolated {
            if isReminder { router.reminderFired = true }
        }
        completionHandler([.banner, .list, .sound])
    }

    /// A reminder tapped (app open or closed): straight into the ritual.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let isUnlock = response.notification.request.content.userInfo["route"] as? String == Self.unlockRoute
        if isUnlock {
            // Recorded, not presented: on a cold launch no view exists yet,
            // and before onboarding there's no ritual to open. The tab shell
            // consumes it once it's on screen.
            MainActor.assumeIsolated { router.requestUnlockFromReminder() }
        }
        completionHandler()
    }
}
