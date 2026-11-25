/// When to ask for an App Store rating: right after today's goal is reached
/// (a good moment, never during a lock), once the goal has been reached on a
/// few days, at most once per app version and with a long gap between two
/// asks. iOS still decides whether the prompt shows (at most three times a
/// year), so this only keeps Hydravia from asking at the wrong time.
public enum ReviewPrompt {
    /// Days the goal must have been reached, today included.
    public static let minimumGoalDays = 3
    /// Days between two asks, even across versions.
    public static let minimumDaysBetween = 120

    /// The last time a rating was asked for.
    public struct Record: Codable, Equatable, Sendable {
        public let day: LocalDay
        public let version: String

        public init(day: LocalDay, version: String) {
            self.day = day
            self.version = version
        }
    }

    public static func shouldAsk(goalDaysReached: Int, appVersion: String, last: Record?, today: LocalDay) -> Bool {
        guard goalDaysReached >= minimumGoalDays else { return false }
        guard let last, last.version != appVersion else { return last == nil }
        // A last ask "in the future" means the device clock was set back:
        // don't let it block every later ask.
        let gap = today.ordinal - last.day.ordinal
        return gap < 0 || gap >= minimumDaysBetween
    }
}
