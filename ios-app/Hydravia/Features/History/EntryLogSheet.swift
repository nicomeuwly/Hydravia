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
    /// The row whose delete button is showing; opening another closes it.
    @State private var openRow: PersistentIdentifier?
    @State private var hasLoaded = false

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

    /// Hand-built rather than a `List`: each day is one card whose rows take
    /// their corners from their place in it (both ends alone, top for the
    /// first, bottom for the last, none in between), and the corners follow
    /// the rows as they reflow after a delete instead of snapping later.
    private func list(_ groups: [DayGroup]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        header(group)
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { offset, item in
                                SwipeToDeleteRow(
                                    id: item.id,
                                    isFirst: offset == 0,
                                    isLast: offset == group.items.count - 1,
                                    openRow: $openRow,
                                    onDelete: { delete(item) }
                                ) {
                                    EntryRow(item: item)
                                }
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            // Room under the last row for the undo bar.
            .padding(.bottom, lastDeleted == nil ? Spacing.xxl : 88)
        }
    }

    private func header(_ group: DayGroup) -> some View {
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
        .padding(.horizontal, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func reload() {
        let fresh = hydration.allEntries().map {
            Item(id: $0.persistentModelID, amountMl: $0.amountMl, createdAt: $0.createdAt, source: $0.source)
        }
        guard fresh != items else { return }
        // Animated after the first load, so an undone entry slides back in.
        withAnimation(hasLoaded && !reduceMotion ? Motion.gentle : nil) { items = fresh }
        hasLoaded = true
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
        openRow = nil
        withAnimation(reduceMotion ? nil : Motion.gentle) { items.removeAll { $0.id == item.id } }
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
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .frame(minHeight: 60)
    }
}

/// A card row that slides left to reveal a delete button (trash icon only,
/// centred on the row). Past half the width — or flicked — it deletes in one
/// go. The row's corners come from its place in the day, and stay put while
/// it slides: the content moves, not the card.
private struct SwipeToDeleteRow<Content: View>: View {
    let id: PersistentIdentifier
    let isFirst: Bool
    let isLast: Bool
    @Binding var openRow: PersistentIdentifier?
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0
    /// Decided on the first movement: a vertical drag is the scroll's.
    @State private var isHorizontal: Bool?
    /// Past the full-swipe threshold: releasing deletes.
    @State private var isArmed = false

    private let buttonWidth: CGFloat = 76
    private let radius = Radius.xl

    private var isOpen: Bool { openRow == id }

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? radius : 0,
            bottomLeadingRadius: isLast ? radius : 0,
            bottomTrailingRadius: isLast ? radius : 0,
            topTrailingRadius: isFirst ? radius : 0,
            style: .continuous
        )

        ZStack(alignment: .trailing) {
            // Behind: the delete action, growing with the swipe.
            Button(action: deleteNow) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(isArmed ? 1.18 : 1)
                    .frame(width: max(buttonWidth, -offset))
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .background(Palette.error)
            .opacity(offset < 0 ? 1 : 0)
            .accessibilityHidden(true)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white)
                .overlay(alignment: .bottom) {
                    if !isLast {
                        Rectangle()
                            .fill(Palette.backgroundElement)
                            .frame(height: 1)
                            .padding(.leading, 60)
                    }
                }
                // Hit area before the offset, so it slides with the content
                // and leaves the delete button tappable.
                .contentShape(.rect)
                .onTapGesture { if isOpen { close() } }
                .offset(x: offset)
        }
        .clipShape(shape)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .simultaneousGesture(drag)
        .onChange(of: openRow) { _, open in
            if open != id, offset != 0, isHorizontal == nil { close() }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isArmed) { _, armed in armed }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(.entriesDelete), onDelete)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if isHorizontal == nil {
                    isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                    if isHorizontal == true, openRow != id { openRow = nil }
                }
                guard isHorizontal == true else { return }
                let base = isOpen ? -buttonWidth : 0
                let raw = base + value.translation.width
                // A little give to the right, none past the left edge.
                offset = raw > 0 ? raw * 0.15 : max(raw, -width)
                let armed = -offset > width * 0.55
                if armed != isArmed {
                    withAnimation(reduceMotion ? nil : Motion.press) { isArmed = armed }
                }
            }
            .onEnded { value in
                defer { isHorizontal = nil }
                guard isHorizontal == true else { return }
                let predicted = (isOpen ? -buttonWidth : 0) + value.predictedEndTranslation.width
                if isArmed || (predicted < -width * 0.9 && -offset > buttonWidth) {
                    deleteNow()
                } else if -offset > buttonWidth * 0.5 || predicted < -buttonWidth * 1.5 {
                    withAnimation(reduceMotion ? nil : Motion.gentle) { offset = -buttonWidth }
                    openRow = id
                } else {
                    close()
                }
            }
    }

    private func close() {
        withAnimation(reduceMotion ? nil : Motion.gentle) {
            offset = 0
            isArmed = false
        }
        if openRow == id { openRow = nil }
    }

    /// Slides the content off, then hands over to the list, which removes
    /// the row and lets its neighbours (and their corners) close the gap.
    private func deleteNow() {
        guard !reduceMotion else { onDelete(); return }
        withAnimation(.easeOut(duration: 0.18)) {
            offset = -width
        } completion: {
            onDelete()
        }
    }
}

private extension String {
    /// "mercredi 4 novembre" → "Mercredi 4 novembre" for a section title.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

#Preview {
    EntryLogSheet().injecting(AppDependencies.preview(todayMl: [250, 500, 330]))
}
