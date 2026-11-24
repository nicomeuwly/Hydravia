import Foundation

/// Today's numbers as the Screen Time shield reads them, for the processes
/// that don't compile `Blocker` (the quick-add widget): same key, same
/// fields as `Blocker.Progress`. Keep the two in step.
public struct ShieldProgressMirror: Codable, Equatable, Sendable {
    public var consumedMl: Int
    public var goalMl: Int
    /// Consecutive days with the goal reached (`Streak.current`).
    public var streak: Int
    /// Any moment of the day these numbers belong to.
    public var day: Date

    public init(consumedMl: Int, goalMl: Int, streak: Int, day: Date) {
        self.consumedMl = consumedMl
        self.goalMl = goalMl
        self.streak = streak
        self.day = day
    }

    /// `Blocker`'s key for the same value.
    public static let key = "blocker.progress.v1"

    public static func load(from defaults: UserDefaults? = UserDefaults(suiteName: Persistence.appGroup)) -> ShieldProgressMirror? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ShieldProgressMirror.self, from: data)
    }

    public func save(to defaults: UserDefaults? = UserDefaults(suiteName: Persistence.appGroup)) {
        defaults?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
