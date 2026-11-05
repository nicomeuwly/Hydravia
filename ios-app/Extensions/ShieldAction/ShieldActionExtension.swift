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
        switch action {
        case .primaryButtonPressed:
            // After an unlock the lingering shield's only button is "OK".
            guard !Blocker.isUnlocked(at: .now) else { return completionHandler(.close) }
            // The system hands over a plain closure; it's called exactly once.
            nonisolated(unsafe) let completionHandler = completionHandler
            postUnlockNotification { posted in
                // Keep the shield up: the notification is the way through.
                completionHandler(posted ? .none : .close)
            }
        default:
            // "Not now", and any button a future iOS adds.
            completionHandler(.close)
        }
    }

    private func postUnlockNotification(completion: @escaping @Sendable (Bool) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = Blocker.string("shield.notifTitle")
        content.body = Blocker.string("shield.notifBody")
        content.sound = .default
        content.userInfo = ["route": Blocker.unlockRoute]
        content.threadIdentifier = "hydration"

        let center = UNUserNotificationCenter.current()
        // With notifications off nothing would appear: report failure so the
        // shield closes the app instead of leaving the user on a dead button.
        center.getNotificationSettings { settings in
            guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus),
                  settings.alertSetting == .enabled
            else { return completion(false) }
            center.removeDeliveredNotifications(withIdentifiers: [Blocker.shieldNotificationIdentifier])
            center.add(UNNotificationRequest(identifier: Blocker.shieldNotificationIdentifier,
                                             content: content, trigger: nil)) { error in
                completion(error == nil)
            }
        }
    }
}
