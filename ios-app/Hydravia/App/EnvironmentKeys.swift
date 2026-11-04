import SwiftUI

extension EnvironmentValues {
    /// Reminder scheduling and permission. Not observable (it holds no view
    /// state), so it travels as a plain environment value.
    @Entry var reminders: ReminderService? = nil
}
