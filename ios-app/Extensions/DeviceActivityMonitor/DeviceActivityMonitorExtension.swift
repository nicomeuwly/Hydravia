import DeviceActivity
import Foundation

/// Raises and lowers the shield on schedule, with no app process running.
///
/// The class name must match `NSExtensionPrincipalClass` in Info.plist, or iOS
/// can't instantiate the extension and no callback ever fires.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        switch activity {
        case Blocker.windowActivity:
            // A new day's window: yesterday's unlock doesn't carry over.
            if let until = Blocker.unlockedUntil, !Calendar.autoupdatingCurrent.isDateInToday(until) {
                Blocker.unlockedUntil = nil
            }
            Blocker.refreshShield()
        case Blocker.relockActivity:
            // The earned break is over.
            Blocker.unlockedUntil = nil
            Blocker.refreshShield()
        default:
            break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // `startMonitoring` replacing the window (a settings change) also
        // ends the running interval: only bedtime really lowers the shield.
        // `refreshShield` decides from the clock, so both cases come out right.
        guard activity == Blocker.windowActivity else { return }
        Blocker.refreshShield(at: Date().addingTimeInterval(60))
    }
}
