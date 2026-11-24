import ManagedSettings
import UserNotifications

/// The shield's buttons.
///
/// A shield can't open an app, so "Drink my dose" posts a notification that
/// does: tapping it opens the unlock ritual. "Not now" closes the blocked app.
///
/// The class name must match `NSExtensionPrincipalClass` in Info.plist.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, completionHandler: completionHandler)
    }

    private func handle(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Fresh state first: a widget pour may have reached the goal, or a
        // test may have run out, since this shield went up. Nothing to
        // drink for any more: lower it and let the user back in.
        Blocker.refreshShield()
        switch action {
        case .primaryButtonPressed:
            // After an unlock (or the goal reached) the lingering shield's
            // only button is "OK".
            guard Blocker.shouldShield(), !Blocker.isOnBreak(at: .now) else {
                Blocker.lowerShield()
                return completionHandler(.close)
            }
            // The system hands over a plain closure; it's called exactly once.
            nonisolated(unsafe) let completionHandler = completionHandler
            postUnlockNotification { posted in
                // Keep the shield up: the notification is the way through.
                // Without one the shield now says to open Hydravia, and the
                // blocked app closes so the user can.
                completionHandler(posted ? .none : .close)
            }
        default:
            // "Not now", and any button a future iOS adds.
            completionHandler(.close)
        }
    }

    private func postUnlockNotification(completion: @escaping @Sendable (Bool) -> Void) {
        Task { completion(await Self.postUnlockNotification()) }
    }

    /// Everything is created inside the task: the notification types aren't
    /// Sendable, so none of them crosses into it.
    private static func postUnlockNotification() async -> Bool {
        let center = UNUserNotificationCenter.current()
        // With notifications off nothing would appear: report failure so the
        // shield closes the app instead of leaving the user on a dead button.
        let settings = await center.notificationSettings()
        let usable = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
            && settings.alertSetting == .enabled
        // The shield's copy follows: "open Hydravia" when nothing can appear.
        Blocker.notificationsUsable = usable
        guard usable else { return false }

        let content = UNMutableNotificationContent()
        content.title = Blocker.string("shield.notifTitle")
        content.body = Blocker.string("shield.notifBody")
        content.sound = .default
        content.userInfo = ["route": Blocker.unlockRoute]
        content.threadIdentifier = "hydration"
        // Asked for from inside a blocked app: show it even under a Focus.
        content.interruptionLevel = .timeSensitive

        center.removeDeliveredNotifications(withIdentifiers: [Blocker.shieldNotificationIdentifier])
        do {
            try await center.add(UNNotificationRequest(identifier: Blocker.shieldNotificationIdentifier,
                                                       content: content, trigger: nil))
            return true
        } catch {
            return false
        }
    }
}
