import HydraviaCore
import HydraviaData
import SwiftData
import SwiftUI

/// Every water entry, grouped by day, newest first. Swiping an entry deletes
/// it at once, with a few seconds to take it back: a mistyped amount is the
/// usual reason to come here, and a confirmation dialog for each would be
/// tedious.
struct EntryLogSheet: View {
    @Environment(HydrationStore.self) private var hydration
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// An entry copied out of SwiftData. Rows never touch the model, which
    /// may already be deleted while its row animates out; this is also what
    /// the undo bar puts back.
    struct Item: Identifiable, Equatable {
        let id: PersistentIdentifier
        let amountMl: Int
        let createdAt: Date
        let source: EntrySource
    }

    private struct DayGroup: Identifiable {
        let day: LocalDay
        let date: Date
        let items: [Item]
        var totalMl: Int { items.reduce(0) { $0 + $1.amountMl } }
        var id: LocalDay { day }
    }

    @State private var items: [Item] = []
    @State private var lastDeleted: Item?
    @State private var undoTask: Task<Void, Never>?
    @State private var failed = false

    private static let undoSeconds = 6

    var body: some View {
        NavigationStack {
            // The list stays mounted even when empty: swapping it out while
            // the last row's delete animation runs makes UIKit throw.
            list(groups(items))
                .overlay {
                    if items.isEmpty {
                        ContentUnavailableView {
                            Label { Text(.entriesEmptyTitle) } icon: { Image(systemName: "drop") }
                        } description: {
                            Text(.entriesEmptyBody)
                        }
                        .foregroundStyle(Palette.textSecondary)
                    }
                }
                .background(Palette.background)
            .navigationTitle(Text(.entriesTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text(.entriesClose))
                }
            }
        }
        .tint(Palette.primaryDark)
        .overlay(alignment: .bottom) {
            if let lastDeleted {
                undoBar(lastDeleted)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : Motion.gentle, value: lastDeleted)
        .alert(Text(.entriesDeleteFailed), isPresented: $failed) {
            Button(role: .cancel) {} label: { Text(.commonOk) }
        }
        .sensoryFeedback(.success, trigger: lastDeleted) { _, new in new != nil }
        .onDisappear { undoTask?.cancel() }
        // Re-read after every write: undos, and entries added elsewhere.
        .task(id: hydration.revision) { reload() }
    }

    // MARK: - List

    private func list(_ groups: [DayGroup]) -> some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.items) { item in
                        EntryRow(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { delete(item) } label: {
                                    Label { Text(.entriesDelete) } icon: { Image(systemName: "trash") }
                                }
                                // The sheet's brand tint would otherwise paint it blue.
                                .tint(Palette.error)
                            }
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(dayTitle(group))
                            .font(.brand(.bold, size: 15, relativeTo: .headline))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text(Self.amount(group.totalMl))
                            .font(.brand(.semiBold, size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Palette.textSecondary)
                            .monospacedDigit()
                    }
                    .textCase(nil)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .scrollContentBackground(.hidden)
        // Room under the last row for the undo bar.
        .contentMargins(.bottom, lastDeleted == nil ? 0 : 80, for: .scrollContent)
    }

    private func reload() {
        items = hydration.allEntries().map {
            Item(id: $0.persistentModelID, amountMl: $0.amountMl, createdAt: $0.createdAt, source: $0.source)
        }
    }

    /// Items are newest first, so days come out newest first too.
    private func groups(_ items: [Item]) -> [DayGroup] {
        let calendar = Calendar.autoupdatingCurrent
        var order: [LocalDay] = []
        var byDay: [LocalDay: [Item]] = [:]
        for item in items {
            let day = LocalDay(item.createdAt, calendar: calendar)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(item)
        }
        return order.compactMap { day in
            guard let date = day.startDate(in: calendar), let items = byDay[day] else { return nil }
            return DayGroup(day: day, date: date, items: items)
        }
    }

    private func dayTitle(_ group: DayGroup) -> String {
        if group.day == hydration.today { return String(localized: .entriesToday) }
        if group.day == hydration.today.adding(days: -1) { return String(localized: .entriesYesterday) }
        let sameYear = Calendar.autoupdatingCurrent.isDate(group.date, equalTo: .now, toGranularity: .year)
        let style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        return (sameYear ? group.date.formatted(style) : group.date.formatted(style.year())).capitalizedFirst
    }

    static func amount(_ ml: Int) -> String {
        "\(ml.formatted()) \(String(localized: .commonMl))"
    }

    // MARK: - Delete and undo

    private func delete(_ item: Item) {
        guard let entry = hydration.allEntries().first(where: { $0.persistentModelID == item.id }) else {
            reload()
            return
        }
        // The row leaves first, from our own copy; the store write follows.
        withAnimation { items.removeAll { $0.id == item.id } }
        do {
            try hydration.delete(entry)
        } catch {
            reload()
            failed = true
            return
        }
        lastDeleted = item
        undoTask?.cancel()
        undoTask = Task {
            try? await Task.sleep(for: .seconds(Self.undoSeconds))
            guard !Task.isCancelled else { return }
            lastDeleted = nil
        }
        AccessibilityNotification.Announcement(String(localized: .entriesDeleted)).post()
    }

    private func undo(_ deleted: Item) {
        undoTask?.cancel()
        lastDeleted = nil
        do {
            try hydration.restore(amountMl: deleted.amountMl, createdAt: deleted.createdAt, source: deleted.source)
        } catch {
            failed = true
        }
    }

    private func undoBar(_ deleted: Item) -> some View {
        HStack(spacing: Spacing.md) {
            Text(.entriesDeleted)
                .font(.brand(.semiBold, size: 15, relativeTo: .subheadline))
                .foregroundStyle(.white)
            Spacer(minLength: Spacing.sm)
            Button { undo(deleted) } label: {
                Text(.entriesUndo)
                    .font(.brand(.bold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Palette.sunlight)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
        }
        .padding(.leading, Spacing.xl)
        .padding(.trailing, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(Palette.primaryDark, in: .capsule)
        .shadow(color: Palette.waterDeep.opacity(0.25), radius: 12, y: 6)
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.sm)
        .accessibilityElement(children: .contain)
    }
}

/// One entry: time, amount, and where it came from.
private struct EntryRow: View {
    let item: EntryLogSheet.Item

    var body: some View {
        let isRitual = item.source == .unlock
        HStack(spacing: Spacing.md) {
            Image(systemName: isRitual ? "lock.open.fill" : "drop.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isRitual ? Palette.amberDeep : Palette.secondaryBlue)
                .frame(width: 32, height: 32)
                .background(Palette.backgroundElement, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(EntryLogSheet.amount(item.amountMl))
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                Text(isRitual ? .entriesSourceUnlock : .entriesSourceManual)
                    .font(.brandFootnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            Text(item.createdAt, format: .dateTime.hour().minute())
                .font(.brand(.semiBold, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Palette.textSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private extension String {
    /// "mercredi 4 novembre" → "Mercredi 4 novembre" for a section title.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

#Preview {
    EntryLogSheet().injecting(AppDependencies.preview(todayMl: [250, 500, 330]))
}
