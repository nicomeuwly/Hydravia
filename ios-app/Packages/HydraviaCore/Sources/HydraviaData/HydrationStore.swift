import Foundation
import HydraviaCore
import Observation
import OSLog
import SwiftData

/// Today's intake and the history behind it.
///
/// The single place that reads and writes water entries. Views observe
/// `todayTotalMl` / `todayEntries`; anything that changes the data goes
/// through here so those stay in sync without each screen re-querying.
///
/// "Today" is the user's calendar day (`calendar`'s time zone), never UTC.
public enum HydrationStoreError: Error, Equatable {
    case invalidAmount(Int)
}

@MainActor
@Observable
public final class HydrationStore {
    /// How many days `recentTotals` covers (today included).
    public static let recentWindowDays = 7

    /// The user's current calendar day. Stored (not computed from the clock)
    /// so views observing it re-render when `refresh()` crosses midnight.
    public private(set) var today: LocalDay
    public private(set) var todayTotalMl = 0
    public private(set) var todayEntries: [WaterEntry] = []
    /// Totals of the last `recentWindowDays` days; empty days are absent.
    public private(set) var recentTotals: [DayTotal] = []
    /// Bumped on every refresh (writes included), for screens showing
    /// derived data that want one cheap value to observe.
    public private(set) var revision = 0

    // Retained on purpose: a ModelContext does not keep its container alive,
    // and using a context whose container was released traps.
    @ObservationIgnored private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let logger = Logger(subsystem: "com.nicomeuwly.hydravia", category: "Hydration")

    public init(container: ModelContainer, calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = Date.init) {
        self.container = container
        self.calendar = calendar
        self.now = now
        self.today = LocalDay(now(), calendar: calendar)
        refresh()
    }

    /// Re-reads today and the recent days from the store. Call when the app
    /// returns to the foreground or the calendar day / time zone changes.
    public func refresh() {
        today = LocalDay(now(), calendar: calendar)
        todayEntries = entries(on: today)
        todayTotalMl = todayEntries.reduce(0) { $0 + $1.amountMl }
        recentTotals = dailyTotals(lastDays: Self.recentWindowDays)
        revision += 1
    }

    public func add(_ amountMl: Int, source: EntrySource) throws {
        guard amountMl > 0 else { throw HydrationStoreError.invalidAmount(amountMl) }
        context.insert(WaterEntry(amountMl: amountMl, createdAt: now(), source: source))
        try save()
    }

    public func delete(_ entry: WaterEntry) throws {
        context.delete(entry)
        try save()
    }

    public func deleteAll() throws {
        do {
            try context.delete(model: WaterEntry.self)
        } catch {
            // Pending deletes must not ride along with the next save.
            context.rollback()
            throw error
        }
        try save()
    }

    /// Entries of one calendar day, oldest first.
    public func entries(on day: LocalDay) -> [WaterEntry] {
        guard let start = day.startDate(in: calendar),
              let end = day.adding(days: 1).startDate(in: calendar)
        else { return [] }
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.createdAt >= start && $0.createdAt < end },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return fetch(descriptor)
    }

    /// Totals for the last `count` calendar days, today included.
    ///
    /// Days without any intake are absent, not zero — exactly what
    /// `Streak` expects (it fills the gaps in itself).
    public func dailyTotals(lastDays count: Int) -> [DayTotal] {
        let today = LocalDay(now(), calendar: calendar)
        let firstDay = today.adding(days: -(max(1, count) - 1))
        guard let start = firstDay.startDate(in: calendar) else { return [] }
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.createdAt >= start })

        var totals: [LocalDay: Int] = [:]
        for entry in fetch(descriptor) {
            totals[LocalDay(entry.createdAt, calendar: calendar), default: 0] += entry.amountMl
        }
        return totals
            .map { DayTotal(day: $0.key, totalMl: $0.value) }
            .sorted { $0.day < $1.day }
    }

    private func fetch(_ descriptor: FetchDescriptor<WaterEntry>) -> [WaterEntry] {
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            throw error
        }
        refresh()
    }
}
