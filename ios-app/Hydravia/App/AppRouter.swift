import Observation

/// App-level navigation state: the selected tab and the modal routes that can
/// be opened from anywhere (a notification tap, the Screen Time shield, the
/// home screen) — the native counterpart of the Expo Router stack.
@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case home, history, settings
    }

    enum Sheet: String, Identifiable {
        case addWater
        case paywall
        var id: String { rawValue }
    }

    var tab: Tab = .home
    var sheet: Sheet?
    /// The unlock ritual is a full-screen cover with no way back but drinking.
    var isUnlockPresented = false
    /// A hydration reminder fired and hasn't been answered yet: the home
    /// screen's ritual card turns into the way into the unlock.
    var reminderFired = false

    /// Set when the unlock is requested while a sheet is up: SwiftUI drops a
    /// full-screen cover presented while a sheet is still dismissing, so the
    /// cover waits for the sheet's `onDismiss`.
    @ObservationIgnored private var unlockPending = false

    /// A reminder was tapped; the ritual opens as soon as the app shell is on
    /// screen (see `MainTabView`).
    private(set) var unlockRequestedByReminder = false

    func requestUnlockFromReminder() {
        reminderFired = true
        unlockRequestedByReminder = true
    }

    func consumeReminderUnlockRequest() {
        guard unlockRequestedByReminder else { return }
        unlockRequestedByReminder = false
        presentUnlock()
    }

    func presentUnlock() {
        guard sheet != nil else {
            isUnlockPresented = true
            return
        }
        unlockPending = true
        sheet = nil
    }

    /// Wire to the sheet's `onDismiss`.
    func sheetDidDismiss() {
        guard unlockPending else { return }
        unlockPending = false
        isUnlockPresented = true
    }
}
