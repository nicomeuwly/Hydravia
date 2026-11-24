import Foundation

/// How much of a Screen Time pick the lock shields on a given plan.
///
/// The free plan locks one app. A pick larger than that (made during a
/// trial, or in onboarding before the paywall was skipped) still locks
/// something: its first app, in a stable order, so the lock keeps working
/// instead of silently stopping. Only a pick with no single app at all
/// (categories or websites alone) can't be reduced to one app: the user
/// has to choose it.
public enum LockCoverage: Equatable, Sendable {
    /// Everything picked is shielded.
    case all
    /// Only the pick's first app is shielded (free plan, larger pick).
    case firstApp
    /// Nothing can be shielded: empty pick, or no single app on the free plan.
    case none
}

extension BlockSelectionSize {
    /// The free plan's limit: one single app, no category, no website.
    public static let freeAppLimit = 1

    /// Within what the free plan locks in full.
    public var isWithinFreeLimit: Bool {
        categories == 0 && webDomains == 0 && apps <= Self.freeAppLimit
    }

    /// What the lock shields of this pick. `Blocker.shieldedTokens` (in the
    /// app's `Shared/` folder) applies the same rule: the Screen Time
    /// extensions don't link this package.
    public func coverage(isPro: Bool) -> LockCoverage {
        if isEmpty { return .none }
        if isPro || isWithinFreeLimit { return .all }
        return apps > 0 ? .firstApp : .none
    }
}

/// When the lock engages: the user wants reminders, Screen Time access is
/// granted, notifications can actually be shown (the shield's "Drink now"
/// works through one, and so does every reminder), and the plan covers
/// something to shield.
public enum LockGate {
    public static func isEngaged(remindersWanted: Bool, screenTimeGranted: Bool,
                                 notificationsUsable: Bool, coverage: LockCoverage) -> Bool {
        remindersWanted && screenTimeGranted && notificationsUsable && coverage != .none
    }
}

/// "Try the lock now": the shield for about a minute, right away, so anyone
/// (App Review included) can see picker → shield → ritual → unlock without
/// waiting for a reminder.
public enum LockTrial {
    /// How long the test shield stays up when the ritual isn't done.
    public static let duration: TimeInterval = 60

    public enum Availability: Equatable, Sendable {
        case available
        /// Screen Time access isn't granted.
        case needsAccess
        /// No app is picked.
        case needsApps
        /// Free plan with only categories or websites picked: no single app
        /// to lock.
        case needsOneApp
    }

    public static func availability(screenTimeGranted: Bool, selection: BlockSelectionSize,
                                    isPro: Bool) -> Availability {
        guard screenTimeGranted else { return .needsAccess }
        guard !selection.isEmpty else { return .needsApps }
        return selection.coverage(isPro: isPro) == .none ? .needsOneApp : .available
    }

    public static func end(startingAt start: Date) -> Date {
        start.addingTimeInterval(duration)
    }

    /// A test started at most `duration` ago. An end further ahead than
    /// that (a clock set back) doesn't count: the test can't outlive its
    /// minute.
    public static func isActive(until: Date?, at date: Date) -> Bool {
        guard let until else { return false }
        return date < until && until.timeIntervalSince(date) <= duration
    }
}
