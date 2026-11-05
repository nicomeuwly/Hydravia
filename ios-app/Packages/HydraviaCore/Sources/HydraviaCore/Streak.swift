import Foundation

/// A local calendar day, independent of time zone once built.
///
/// Day arithmetic uses the proleptic Gregorian day number, so shifting and
/// comparing days needs no `Calendar` and is exact across month and year
/// boundaries.
public struct LocalDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Gregorian date. Out-of-range values are normalised (Feb 31 → Mar 3), so
    /// equality and ordering always agree.
    public init(year: Int, month: Int, day: Int) {
        self.init(normalizing: Self.civilOrdinal(year: year, month: month, day: day))
    }

    /// The user's calendar day for `date` — never UTC: water drunk at 00:30
    /// in Paris counts toward that morning, not the day before. Always read
    /// in the Gregorian calendar, whatever calendar the user's device uses.
    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.gregorianInSameTimeZone.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Days since 1970-01-01.
    public var ordinal: Int { Self.civilOrdinal(year: year, month: month, day: day) }

    /// Howard Hinnant's `days_from_civil`; months outside 1…12 and days past
    /// the month's end roll over naturally.
    private static func civilOrdinal(year: Int, month: Int, day: Int) -> Int {
        let monthIndex = month - 1
        let carry = monthIndex >= 0 ? monthIndex / 12 : (monthIndex - 11) / 12
        let normalizedYear = year + carry
        let normalizedMonth = monthIndex - carry * 12 + 1
        let y = normalizedMonth <= 2 ? normalizedYear - 1 : normalizedYear
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (normalizedMonth + 9) % 12
        let doy = (153 * mp + 2) / 5
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468 + day - 1
    }

    public init(ordinal: Int) {
        self.init(normalizing: ordinal)
    }

    private init(normalizing ordinal: Int) {
        let z = ordinal + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.year = yoe + era * 400 + (m <= 2 ? 1 : 0)
        self.month = m
        self.day = d
    }

    public func adding(days: Int) -> LocalDay { LocalDay(ordinal: ordinal + days) }

    /// Midnight of this day in `calendar`'s time zone.
    public func startDate(in calendar: Calendar) -> Date? {
        calendar.gregorianInSameTimeZone.date(from: DateComponents(year: year, month: month, day: day))
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.ordinal < rhs.ordinal }
}

/// Total intake of one calendar day.
public struct DayTotal: Equatable, Sendable {
    public let day: LocalDay
    public let totalMl: Int

    public init(day: LocalDay, totalMl: Int) {
        self.day = day
        self.totalMl = totalMl
    }
}

/// Streak maths over daily totals.
///
/// A day with no intake has no total at all — it is absent, not zero. Walking
/// the totals directly makes a completely missed day invisible: 2 500 / — /
/// 2 500 would read as an unbroken two-day streak. Everything here works on
/// calendar days, filling the gaps back in, so a missed day breaks the streak
/// the way a user expects. Today counts as soon as its goal is reached, and
/// never against the user while it's still in progress: a partial day must
/// not read as a broken streak.
///
/// Expects one total per day and a positive goal; with a non-positive goal no
/// day counts as reached (there is nothing to reach).
public enum Streak {
    /// Consecutive goal-meeting days ending today (once reached) or
    /// yesterday (while today is still in progress).
    public static func current(_ totals: [DayTotal], goalMl: Int, today: LocalDay) -> Int {
        let reached = reachedDays(totals, goalMl: goalMl, today: today)
        var streak = 0
        var cursor = reached.contains(today) ? today : today.adding(days: -1)
        while reached.contains(cursor) {
            streak += 1
            cursor = cursor.adding(days: -1)
        }
        return streak
    }

    /// Goal-meeting days in the window, today included once reached.
    public static func daysReached(_ totals: [DayTotal], goalMl: Int, today: LocalDay) -> Int {
        reachedDays(totals, goalMl: goalMl, today: today).count
    }

    /// Longest run of consecutive goal-meeting days, today included once reached.
    public static func best(_ totals: [DayTotal], goalMl: Int, today: LocalDay) -> Int {
        let ordinals = reachedDays(totals, goalMl: goalMl, today: today).map(\.ordinal).sorted()
        var best = 0
        var run = 0
        var previous: Int?
        for ordinal in ordinals {
            run = previous.map { $0 + 1 == ordinal } == true ? run + 1 : 1
            best = max(best, run)
            previous = ordinal
        }
        return best
    }

    private static func reachedDays(_ totals: [DayTotal], goalMl: Int, today: LocalDay) -> Set<LocalDay> {
        guard goalMl > 0 else { return [] }
        // Days after today can't be reached yet (a clock set back, say).
        return Set(totals.lazy.filter { $0.day <= today && $0.totalMl >= goalMl }.map(\.day))
    }
}
