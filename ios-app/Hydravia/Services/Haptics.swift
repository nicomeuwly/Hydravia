import UIKit

/// Haptic patterns that SwiftUI's `sensoryFeedback` can't express.
///
/// Haptics are reserved for meaningful moments (dose drunk, goal reached,
/// unlock); routine taps use `sensoryFeedback` on the control itself.
enum Haptics {
    /// Ceremonial pattern for the big moments: goal at 100 %, unlock
    /// confirmed. A medium knock, a lighter echo, then success.
    static func celebrate() {
        let medium = UIImpactFeedbackGenerator(style: .medium)
        let light = UIImpactFeedbackGenerator(style: .light)
        let success = UINotificationFeedbackGenerator()
        light.prepare()
        success.prepare()
        Task {
            medium.impactOccurred()
            try? await Task.sleep(for: .milliseconds(110))
            light.impactOccurred()
            try? await Task.sleep(for: .milliseconds(90))
            success.notificationOccurred(.success)
        }
    }
}
