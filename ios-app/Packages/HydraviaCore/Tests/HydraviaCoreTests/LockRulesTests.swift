import Foundation
import Testing
@testable import HydraviaCore

@Suite("LockRules")
struct LockRulesTests {
    private func size(apps: Int = 0, categories: Int = 0, sites: Int = 0) -> BlockSelectionSize {
        BlockSelectionSize(apps: apps, categories: categories, webDomains: sites)
    }

    // MARK: Coverage

    @Test func oneAppIsLockedInFullOnTheFreePlan() {
        #expect(size(apps: 1).coverage(isPro: false) == .all)
    }

    @Test func severalAppsOnTheFreePlanStillLockTheFirst() {
        // Picked in onboarding, then Pro skipped: the lock keeps working.
        #expect(size(apps: 4).coverage(isPro: false) == .firstApp)
        #expect(size(apps: 2, categories: 3, sites: 1).coverage(isPro: false) == .firstApp)
    }

    @Test func categoriesAloneCantBeReducedToOneApp() {
        #expect(size(categories: 2).coverage(isPro: false) == .none)
        #expect(size(sites: 1).coverage(isPro: false) == .none)
    }

    @Test func proLocksEverything() {
        #expect(size(apps: 30, categories: 5, sites: 2).coverage(isPro: true) == .all)
    }

    @Test func nothingPickedLocksNothing() {
        #expect(size().coverage(isPro: true) == .none)
        #expect(size().coverage(isPro: false) == .none)
    }

    // MARK: Gate

    @Test func theLockNeedsNotificationsThatWork() {
        #expect(LockGate.isEngaged(remindersWanted: true, screenTimeGranted: true,
                                   notificationsUsable: true, coverage: .firstApp))
        // The setting says on but iOS says no: no lock, no dead-end shield.
        #expect(!LockGate.isEngaged(remindersWanted: true, screenTimeGranted: true,
                                    notificationsUsable: false, coverage: .all))
        #expect(!LockGate.isEngaged(remindersWanted: false, screenTimeGranted: true,
                                    notificationsUsable: true, coverage: .all))
        #expect(!LockGate.isEngaged(remindersWanted: true, screenTimeGranted: false,
                                    notificationsUsable: true, coverage: .all))
        #expect(!LockGate.isEngaged(remindersWanted: true, screenTimeGranted: true,
                                    notificationsUsable: true, coverage: .none))
    }

    // MARK: Trial

    @Test func trialNeedsAccessThenApps() {
        #expect(LockTrial.availability(screenTimeGranted: false, selection: size(apps: 1), isPro: false) == .needsAccess)
        #expect(LockTrial.availability(screenTimeGranted: true, selection: size(), isPro: true) == .needsApps)
        #expect(LockTrial.availability(screenTimeGranted: true, selection: size(categories: 3), isPro: false) == .needsOneApp)
        #expect(LockTrial.availability(screenTimeGranted: true, selection: size(apps: 3), isPro: false) == .available)
        #expect(LockTrial.availability(screenTimeGranted: true, selection: size(categories: 3), isPro: true) == .available)
    }

    @Test func trialLastsAMinute() {
        let start = Date(timeIntervalSince1970: 10_000)
        let end = LockTrial.end(startingAt: start)
        #expect(end.timeIntervalSince(start) == 60)
        #expect(LockTrial.isActive(until: end, at: start))
        #expect(LockTrial.isActive(until: end, at: start.addingTimeInterval(59)))
        #expect(!LockTrial.isActive(until: end, at: end))
        #expect(!LockTrial.isActive(until: nil, at: start))
    }

    @Test func aClockSetBackDoesntStretchTheTrial() {
        let start = Date(timeIntervalSince1970: 10_000)
        let end = LockTrial.end(startingAt: start)
        #expect(!LockTrial.isActive(until: end, at: start.addingTimeInterval(-3_600)))
    }
}
