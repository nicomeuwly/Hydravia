import Foundation

/// How the user feels when a reminder fires — the single question of the
/// unlock ritual.
public enum Feeling: String, CaseIterable, Codable, Sendable {
    case fine
    case hot
    case veryThirsty
}

/// Inputs of the unlock dose. `now` and `windowEnd` are parameters, never read
/// from the clock, so the calculation stays deterministic and testable.
public struct DoseInput: Sendable, Equatable {
    public var goalMl: Int
    public var drunkMl: Int
    public var now: Date
    public var windowEnd: Date
    public var intervalMin: Int
    public var feeling: Feeling
    /// Outside temperature in °C, or `nil` when unknown (no permission,
    /// offline). Unknown never blocks the ritual — it just skips the bonus.
    public var temperatureC: Double?

    public init(
        goalMl: Int,
        drunkMl: Int,
        now: Date,
        windowEnd: Date,
        intervalMin: Int,
        feeling: Feeling,
        temperatureC: Double?
    ) {
        self.goalMl = goalMl
        self.drunkMl = drunkMl
        self.now = now
        self.windowEnd = windowEnd
        self.intervalMin = intervalMin
        self.feeling = feeling
        self.temperatureC = temperatureC
    }
}

/// The dose shown at unlock time: what is left to drink, spread over the
/// reminders left in the active window, nudged by how the user feels and by
/// the heat.
public enum Dose {
    public static func multiplier(for feeling: Feeling) -> Double {
        switch feeling {
        case .fine: 0.9
        case .hot: 1.15
        case .veryThirsty: 1.3
        }
    }

    public static let hotThresholdC = 28.0
    public static let hotMultiplier = 1.15
    public static let minimumMl = 100.0
    public static let maximumMl = 600.0
    public static let roundingMl = 10.0

    /// The base dose is capped BELOW the final max so the feeling multiplier
    /// can always differentiate the answers: without this headroom, any big
    /// base saturates at `maximumMl` and "Fine" yields the same dose as
    /// "Very thirsty".
    public static let baseMaximumMl = maximumMl / multiplier(for: .veryThirsty)

    public static func ml(for input: DoseInput) -> Int {
        let remaining = Double(max(0, input.goalMl - input.drunkMl))
        // Whole milliseconds, like the TypeScript engine: sub-millisecond clock
        // noise must not drop a reminder at an exact interval boundary.
        let msLeft = max(0, (input.windowEnd.timeIntervalSince(input.now) * 1000).rounded())
        // A non-positive interval means "no cadence": treat the rest of the
        // window as a single reminder rather than dividing by zero.
        let remindersLeft = input.intervalMin > 0
            ? max(1, (msLeft / (Double(input.intervalMin) * 60_000)).rounded(.down))
            : 1

        let heat = (input.temperatureC ?? -.infinity) > hotThresholdC ? hotMultiplier : 1.0
        let base = min(baseMaximumMl, max(minimumMl, remaining / remindersLeft * heat))
        let raw = base * multiplier(for: input.feeling)
        let clamped = min(maximumMl, max(minimumMl, raw))
        return Int((clamped / roundingMl).rounded() * roundingMl)
    }

    /// End of today's active window: today at bedtime (wall-clock time, so a
    /// daylight-saving switch never moves it), or tomorrow at bedtime when that
    /// moment has already passed.
    public static func windowEnd(sleep: MinuteOfDay, now: Date, calendar: Calendar) -> Date {
        let today = calendar.date(
            bySettingHour: sleep.hour, minute: sleep.minute, second: 0,
            of: now, matchingPolicy: .nextTime
        ) ?? now
        if today >= now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
