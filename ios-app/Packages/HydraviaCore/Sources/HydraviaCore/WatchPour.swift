import Foundation

/// Water poured on the Apple Watch, on its way to the iPhone (which holds
/// the history). The id makes a pour count once however often it's sent.
public struct WatchPour: Codable, Hashable, Sendable {
    public var id: UUID
    public var amountMl: Int
    public var createdAt: Date

    public init(id: UUID = UUID(), amountMl: Int, createdAt: Date) {
        self.id = id
        self.amountMl = amountMl
        self.createdAt = createdAt
    }

    /// The amounts a pour may carry, like the widget buttons'.
    public static let validAmounts = 1...2000
}

/// What the watch counts and what the iPhone has already counted.
public enum WatchTally {
    /// How long the iPhone remembers a counted pour, and the watch keeps one
    /// it couldn't deliver: a pour from the day before can still arrive.
    public static let memory: TimeInterval = 2 * 24 * 3600

    /// Today's water as the watch shows it: the iPhone's last count (if it's
    /// today's) plus the pours it hasn't counted yet.
    public static func todayMl(
        phoneDay: LocalDay?,
        phoneMl: Int,
        pending: [WatchPour],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let today = LocalDay(now, calendar: calendar)
        let counted = phoneDay == today ? phoneMl : 0
        let waiting = pending
            .filter { LocalDay($0.createdAt, calendar: calendar) == today }
            .reduce(0) { $0 + $1.amountMl }
        return counted + waiting
    }

    /// The pours still to deliver: not counted by the iPhone yet, and recent
    /// enough to still matter.
    public static func stillPending(_ pending: [WatchPour], counted: Set<UUID>, now: Date) -> [WatchPour] {
        pending.filter { !counted.contains($0.id) && now.timeIntervalSince($0.createdAt) < memory }
    }

    /// The iPhone's side: whether `pour` is new (to add to the history), and
    /// the counted pours to remember from now on (old ones forgotten).
    public static func receive(
        _ pour: WatchPour,
        counted: [UUID: Date],
        now: Date
    ) -> (isNew: Bool, counted: [UUID: Date]) {
        var kept = counted.filter { now.timeIntervalSince($0.value) < memory }
        let isNew = kept[pour.id] == nil
            && WatchPour.validAmounts.contains(pour.amountMl)
            && now.timeIntervalSince(pour.createdAt) < memory
            && pour.createdAt <= now.addingTimeInterval(5 * 60)
        if isNew { kept[pour.id] = now }
        return (isNew, kept)
    }
}
