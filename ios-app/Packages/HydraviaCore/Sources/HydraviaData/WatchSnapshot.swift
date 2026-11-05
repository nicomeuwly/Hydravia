import Foundation
import HydraviaCore

/// What the iPhone tells the Apple Watch: today's count and what the
/// widgets get (goal, amounts, schedule, plan), plus the watch pours it has
/// counted so the watch stops adding them on top.
public struct WatchSnapshot: Codable, Equatable, Sendable {
    public var state: WidgetState
    public var day: LocalDay
    public var consumedMl: Int
    /// Days in a row the goal was reached, today excluded.
    public var streak: Int
    public var countedPours: [UUID]

    public init(state: WidgetState, day: LocalDay, consumedMl: Int, streak: Int, countedPours: [UUID]) {
        self.state = state
        self.day = day
        self.consumedMl = consumedMl
        self.streak = streak
        self.countedPours = countedPours
    }

    public static let key = "snapshot"

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func decode(_ payload: [String: Any]) -> WatchSnapshot? {
        (payload[key] as? Data).flatMap { try? JSONDecoder().decode(WatchSnapshot.self, from: $0) }
    }
}

extension WatchPour {
    public static let key = "pour"

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func decode(_ payload: [String: Any]) -> WatchPour? {
        (payload[key] as? Data).flatMap { try? JSONDecoder().decode(WatchPour.self, from: $0) }
    }
}

/// The watch's own copy, in its App Group so the complications read it: the
/// iPhone's last snapshot and the pours not counted by the iPhone yet.
public struct WatchLocalState: Codable, Equatable, Sendable {
    public var snapshot: WatchSnapshot?
    public var pending: [WatchPour]

    public init(snapshot: WatchSnapshot? = nil, pending: [WatchPour] = []) {
        self.snapshot = snapshot
        self.pending = pending
    }

    public var state: WidgetState { snapshot?.state ?? .placeholder }

    public func todayMl(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        WatchTally.todayMl(phoneDay: snapshot?.day, phoneMl: snapshot?.consumedMl ?? 0,
                           pending: pending, now: now, calendar: calendar)
    }

    public func progress(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Double {
        HydrationGoal.progress(consumedMl: todayMl(at: now, calendar: calendar), goalMl: state.goalMl)
    }

    public func isGoalReached(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        todayMl(at: now, calendar: calendar) >= state.goalMl
    }

    /// The next reminder the iPhone will send: none left today once the goal
    /// is reached. Nil with reminders off.
    public func nextReminder(after now: Date, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        guard state.remindersOn else { return nil }
        return ReminderPlan.fireDates(window: state.window, now: now,
                                      goalReachedToday: isGoalReached(at: now, calendar: calendar),
                                      calendar: calendar, budget: 1).first
    }

    /// A new snapshot from the iPhone: the pours it counted stop waiting.
    public mutating func apply(_ snapshot: WatchSnapshot, now: Date) {
        self.snapshot = snapshot
        pending = WatchTally.stillPending(pending, counted: Set(snapshot.countedPours), now: now)
    }

    private static let key = "watch.state.v1"

    public static func load(from defaults: UserDefaults? = UserDefaults(suiteName: Persistence.appGroup)) -> WatchLocalState {
        guard let data = defaults?.data(forKey: key),
              let value = try? JSONDecoder().decode(WatchLocalState.self, from: data)
        else { return WatchLocalState() }
        return value
    }

    public func save(to defaults: UserDefaults? = UserDefaults(suiteName: Persistence.appGroup)) {
        defaults?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
