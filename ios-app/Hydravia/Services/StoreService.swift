import Foundation
import Observation
import OSLog
import StoreKit

/// Hydravia Pro, sold directly through StoreKit 2.
///
/// Premium is always derived from the App Store's verified current
/// entitlements — never cached as a local flag that could drift from what
/// Apple says (a refund, an expiry, a family-sharing change).
@MainActor
@Observable
final class StoreService {
    // Must match App Store Connect exactly (see docs/APP_STORE_SETUP.md).
    // A product ID can never be reused once created there.
    static let yearlyID = "com.nicomeuwly.hydravia.pro.yearly"
    static let monthlyID = "com.nicomeuwly.hydravia.pro.monthly"
    static let productIDs: Set<String> = [yearlyID, monthlyID]

    enum Outcome { case success, cancelled, pending, failed }

    private(set) var yearly: Product?
    private(set) var monthly: Product?
    private(set) var isPremium = false
    /// False until the App Store has answered once: screens gating on premium
    /// shouldn't flash "locked" for an actual subscriber at launch.
    private(set) var hasLoadedEntitlements = false
    /// Whether this user can still get the free trial. `nil` until the App
    /// Store has answered — and anything but `true` means: promise nothing.
    /// Apple grants one introductory offer per subscription group, ever.
    private(set) var isEligibleForTrial: Bool?
    /// The trial's real length, from the product configuration.
    private(set) var trialPeriod: Product.SubscriptionPeriod?
    private(set) var productsFailedToLoad = false

    @ObservationIgnored private let reminders: ReminderService
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var refreshing: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.nicomeuwly.hydravia", category: "Store")

    init(reminders: ReminderService) {
        self.reminders = reminders
        // Transactions completed outside the app (renewals, Ask to Buy,
        // purchases on another device, refunds) arrive here; listening must
        // start at launch or they'd be missed until the next start.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    // MARK: Loading

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.productIDs)
            yearly = products.first { $0.id == Self.yearlyID }
            monthly = products.first { $0.id == Self.monthlyID }
            productsFailedToLoad = yearly == nil && monthly == nil
        } catch {
            productsFailedToLoad = true
            logger.error("Products failed to load: \(error.localizedDescription, privacy: .public)")
        }
        await updateTrialEligibility()
    }

    private func updateTrialEligibility() async {
        guard let subscription = (yearly ?? monthly)?.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial
        else {
            isEligibleForTrial = (yearly ?? monthly) == nil ? nil : false
            trialPeriod = nil
            return
        }
        trialPeriod = offer.period
        isEligibleForTrial = await subscription.isEligibleForIntroOffer
    }

    /// Re-reads the entitlements. Calls coalesce: a refresh requested while
    /// one is running waits for it and runs once more, so two answers can
    /// never overwrite each other out of order.
    func refreshEntitlements() async {
        let previous = refreshing
        let task = Task {
            await previous?.value
            await self.readEntitlements()
        }
        refreshing = task
        await task.value
    }

    /// Renewals reach the device only when the app runs; a day's margin keeps
    /// a renewing subscriber's lock from lapsing in between.
    private static let renewalGrace: TimeInterval = 24 * 3600

    private func readEntitlements() async {
        var active = false
        var sawUnverified = false
        var trial: Transaction?
        var expiresAt: Date?

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil else { continue }
                active = true
                if transaction.offer?.type == .introductory { trial = transaction }
                if let date = transaction.expirationDate { expiresAt = max(expiresAt ?? date, date) }
            case .unverified(let transaction, let error):
                guard Self.productIDs.contains(transaction.productID) else { continue }
                sawUnverified = true
                logger.error("Unverified entitlement ignored: \(error.localizedDescription, privacy: .public)")
            }
        }

        // An unverifiable answer (tampered or not-yet-verifiable receipt,
        // odd offline states) must not demote a known subscriber: keep the
        // last verified state rather than wipe their reminders.
        if active || !sawUnverified || !hasLoadedEntitlements {
            isPremium = active || (sawUnverified && isPremium)
        }
        hasLoadedEntitlements = true
        // The Screen Time extensions can't ask the App Store: tell them how
        // long the lock may run, so a lapse while the app is closed doesn't
        // keep shielding a non-subscriber's apps.
        if active { Blocker.proUntil = expiresAt.map { $0.addingTimeInterval(Self.renewalGrace) } }

        await syncTrialEndReminder(trial: trial)
        await updateTrialEligibility()
    }

    /// The heads-up the paywall promises — two days before the first charge
    /// of a running trial, and only while it will actually convert. Cancelled
    /// trial, refund or expiry: the reminder goes.
    private func syncTrialEndReminder(trial: Transaction?) async {
        guard let trial,
              let end = trial.expirationDate,
              let groupID = trial.subscriptionGroupID,
              await willAutoRenew(groupID: groupID)
        else {
            reminders.cancelTrialEndReminder()
            return
        }
        let headsUp = end.addingTimeInterval(-2 * 24 * 3600)
        if headsUp > .now {
            await reminders.scheduleTrialEndReminder(at: headsUp)
        } else {
            reminders.cancelTrialEndReminder()
        }
    }

    private func willAutoRenew(groupID: String) async -> Bool {
        guard let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else { return false }
        return statuses.contains { status in
            if case .verified(let renewal) = status.renewalInfo { return renewal.willAutoRenew }
            return false
        }
    }

    // MARK: Purchasing

    /// Completes a purchase made with SwiftUI's `purchase` action (which
    /// anchors the payment sheet to the right scene).
    func complete(_ result: Product.PurchaseResult) async -> Outcome {
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                logger.error("Unverified purchase rejected")
                return .failed
            }
            await transaction.finish()
            // The user was charged and Apple verified it: they are premium,
            // even if the entitlement list lags a moment behind.
            isPremium = true
            await refreshEntitlements()
            return .success
        case .userCancelled:
            return .cancelled
        case .pending:
            // Ask to Buy / SCA: the outcome arrives later via Transaction.updates.
            return .pending
        @unknown default:
            return .failed
        }
    }

    /// Restores purchases. Only meant for an explicit tap: it may ask the user
    /// to sign in to their Apple Account.
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshEntitlements()
        return isPremium
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await transaction.finish()
        case .unverified(_, let error):
            logger.error("Unverified transaction update: \(error.localizedDescription, privacy: .public)")
        }
        await refreshEntitlements()
    }
}
