import Foundation

/// A time of day, as minutes since local midnight (0 ..< 1440).
public struct MinuteOfDay: Hashable, Comparable, Codable, Sendable {
    public static let perDay = 24 * 60

    public let value: Int

    public init(_ value: Int) {
        self.value = ((value % Self.perDay) + Self.perDay) % Self.perDay
    }

    public init(hour: Int, minute: Int) {
        self.init(hour * 60 + minute)
    }

    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.gregorianInSameTimeZone.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    public var hour: Int { value / 60 }
    public var minute: Int { value % 60 }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }

    // Coded as a bare integer, re-normalised on decode: persisted data can
    // never smuggle in an out-of-range minute.
    public init(from decoder: any Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(Int.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension Calendar {
    /// Gregorian calendar in this calendar's time zone. Day arithmetic in this
    /// package is Gregorian; reading components through a Buddhist, Japanese
    /// or Hebrew `Calendar.current` would silently corrupt it.
    var gregorianInSameTimeZone: Calendar {
        guard identifier != .gregorian else { return self }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        return gregorian
    }
}

/// When the next reminder fires, as shown on the home screen.
public enum NextReminder: Equatable, Sendable {
    case today(MinuteOfDay)
    case tomorrow(MinuteOfDay)
    /// The window is too short for even one reminder.
    case none
}

/// The active window (wake → sleep) and the reminder cadence inside it.
///
/// The window lives inside a single calendar day: reminders fire at
/// wake + n × interval, strictly before sleep, and the pickers keep
/// sleep > wake. It therefore cannot cross midnight — a deliberate limit, not
/// an oversight: the dose maths, the notification schedule and the native
/// DeviceActivity window all assume one day.
public struct ActiveWindow: Equatable, Codable, Sendable {
    public var wake: MinuteOfDay
    public var sleep: MinuteOfDay
    public var intervalMin: Int

    public init(wake: MinuteOfDay, sleep: MinuteOfDay, intervalMin: Int) {
        self.wake = wake
        self.sleep = sleep
        self.intervalMin = intervalMin
    }

    /// Smallest gap kept between wake and sleep, and the pickers' step.
    public static let minimumGapMin = 15
    public static let latestSleep = MinuteOfDay(MinuteOfDay.perDay - minimumGapMin)

    /// The same window forced back into what the app can express: sleep at
    /// most 23:45, wake at least one step before sleep, a positive interval.
    /// Persisted or imported data goes through this, so no screen ever has to
    /// cope with an impossible window.
    public var sanitized: ActiveWindow {
        let sleepValue = min(max(sleep.value, Self.minimumGapMin), Self.latestSleep.value)
        let wakeValue = min(wake.value, sleepValue - Self.minimumGapMin)
        return ActiveWindow(
            wake: MinuteOfDay(wakeValue),
            sleep: MinuteOfDay(sleepValue),
            intervalMin: intervalMin > 0 ? intervalMin : 60
        )
    }

    /// Every reminder of the day, in order. This is the single source of truth
    /// for both the notification schedule and the "next reminder" label —
    /// showing anything else on screen would be a lie.
    public var reminderSlots: [MinuteOfDay] {
        guard intervalMin > 0 else { return [] }
        return stride(from: wake.value + intervalMin, to: sleep.value, by: intervalMin)
            .map(MinuteOfDay.init)
    }

    /// First reminder strictly after `now`, rolling over to tomorrow's first
    /// slot once today's are spent.
    public func nextReminder(after now: MinuteOfDay) -> NextReminder {
        let slots = reminderSlots
        guard let first = slots.first else { return .none }
        if let next = slots.first(where: { $0 > now }) { return .today(next) }
        return .tomorrow(first)
    }

    /// Minutes from midnight past which a bedtime is late enough that the user
    /// is plausibly reaching for a window the app can't express. Screens
    /// surface the midnight cut-off from here so a night owl doesn't read
    /// silence as a bug.
    ///
    /// Strictly above the 22:00 default: a note everyone sees on arrival is
    /// wallpaper, and this one has to still register when it matters.
    public static let lateBedtimeThreshold = MinuteOfDay(hour: 22, minute: 15)

    public static func isLateBedtime(_ sleep: MinuteOfDay) -> Bool {
        sleep >= lateBedtimeThreshold
    }
}
