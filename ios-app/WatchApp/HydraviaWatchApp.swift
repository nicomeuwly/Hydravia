import SwiftUI
import WatchKit

@main
struct HydraviaWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environment(WatchModel.shared)
        }
    }
}

/// Starts the iPhone link at launch, and lets the system wake the app in the
/// background to receive the iPhone's numbers (a complication to redraw).
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchModel.shared.activate()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let task = task as? WKWatchConnectivityRefreshBackgroundTask {
                WatchModel.shared.hold(task)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
