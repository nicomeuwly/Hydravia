import Charts
import HydraviaCore
import SwiftUI

/// One calendar week as bars against the goal, starting on this week. Swipe
/// sideways (or use the arrows) to page back through past weeks, as far as
/// the first one with any water, up to a year.
struct WeekChartCard: View {
    /// Every day's total the store keeps (a year); empty days are absent.
    let totals: [DayTotal]
    let goalMl: Int
    let today: LocalDay

    /// The week on screen, by its first day. `nil` until the pager settles
    /// on the current week.
    @State private var shownWeek: LocalDay?
    /// Bars grow from zero the first time the card appears.
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let maxWeeks = 53

    private var calendar: Calendar { .autoupdatingCurrent }

    /// First day of the week holding `day`, per the user's locale.
    private func weekStart(of day: LocalDay) -> LocalDay {
        guard let date = day.startDate(in: calendar),
              let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        else { return day }
        return LocalDay(interval.start, calendar: calendar)
    }

    /// Oldest first, this week last: the pager opens on the trailing page.
    private var weeks: [LocalDay] {
        let current = weekStart(of: today)
        guard let firstDrink = totals.filter({ $0.totalMl > 0 }).map(\.day).min() else { return [current] }
        let first = weekStart(of: firstDrink)
        let count = min(max((current.ordinal - first.ordinal) / 7 + 1, 1), Self.maxWeeks)
        return (0..<count).reversed().map { current.adding(days: -7 * $0) }
    }

    var body: some View {
        let weeks = weeks
        let current = weeks.last ?? weekStart(of: today)
        let shown = shownWeek.flatMap { weeks.contains($0) ? $0 : nil } ?? current
        let index = weeks.firstIndex(of: shown) ?? weeks.count - 1
        let byDay = Dictionary(totals.map { ($0.day, $0.totalMl) }, uniquingKeysWith: +)
        let days = WeekChart.days(from: shown, byDay: byDay, calendar: calendar)
        let drunk = days.filter { $0.totalMl > 0 }
        let averageLiters = drunk.isEmpty ? 0 : Double(drunk.map(\.totalMl).reduce(0, +)) / Double(drunk.count) / 1000

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: shown, current: current))
                        .font(.brand(.bold, size: 15, relativeTo: .headline))
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.opacity)
                    Text(.historyAverage(averageLiters.formatted(.number.precision(.fractionLength(1)))))
                        .font(.brand(.regular, size: 13.5, relativeTo: .subheadline))
                        .foregroundStyle(Palette.textSecondary)
                        .contentTransition(.numericText())
                }
                .animation(Motion.base, value: shown)
                .accessibilityElement(children: .combine)

                Spacer(minLength: 0)

                if weeks.count > 1 {
                    arrow("chevron.left", label: .historyPreviousWeek, enabled: index > 0) {
                        go(to: weeks[index - 1])
                    }
                    arrow("chevron.right", label: .historyNextWeek, enabled: index < weeks.count - 1) {
                        go(to: weeks[index + 1])
                    }
                }
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(weeks, id: \.self) { start in
                        WeekChart(
                            days: WeekChart.days(from: start, byDay: byDay, calendar: calendar),
                            title: title(for: start, current: current),
                            goalMl: goalMl,
                            today: today,
                            grown: grown
                        )
                        .padding(.horizontal, Spacing.xl)
                        .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $shownWeek, anchor: .center)
            .defaultScrollAnchor(.trailing)
            .scrollIndicators(.hidden)
            .scrollDisabled(weeks.count < 2)
            .frame(height: 140)
            // The pages slide edge to edge of the card, not of its padding.
            .padding(.horizontal, -Spacing.xl)
            .clipped()
        }
        .padding(.vertical, 22)
        .padding(.horizontal, Spacing.xl)
        .card()
        .sensoryFeedback(.selection, trigger: shownWeek)
        .onAppear {
            guard !grown else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.25).delay(0.15)) { grown = true }
        }
    }

    private func go(to week: LocalDay) {
        withAnimation(reduceMotion ? nil : Motion.gentle) { shownWeek = week }
    }

    /// "This week", "Last week", then the dates ("27 Oct – 2 Nov"), with the
    /// year once it isn't this one.
    private func title(for start: LocalDay, current: LocalDay) -> String {
        switch (current.ordinal - start.ordinal) / 7 {
        case 0: return String(localized: .historyThisWeek)
        case 1: return String(localized: .historyLastWeek)
        default:
            guard let from = start.startDate(in: calendar),
                  let to = start.adding(days: 6).startDate(in: calendar)
            else { return "" }
            let sameYear = calendar.component(.year, from: to) == calendar.component(.year, from: .now)
            let style: Date.IntervalFormatStyle = sameYear
                ? .interval.day().month(.abbreviated)
                : .interval.day().month(.abbreviated).year()
            return (from..<to).formatted(style)
        }
    }

    private func arrow(_ symbol: String, label: LocalizedStringResource, enabled: Bool,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? Palette.secondaryBlue : Palette.textTertiary.opacity(0.5))
                .frame(width: 34, height: 34)
                .background(Palette.backgroundElement, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
    }
}

/// The bars of one week.
private struct WeekChart: View {
    struct Day: Identifiable {
        let day: LocalDay
        let date: Date
        let totalMl: Int
        var id: LocalDay { day }
    }

    let days: [Day]
    let title: String
    let goalMl: Int
    let today: LocalDay
    let grown: Bool

    static func days(from start: LocalDay, byDay: [LocalDay: Int], calendar: Calendar) -> [Day] {
        (0..<7).compactMap { offset in
            let day = start.adding(days: offset)
            guard let date = day.startDate(in: calendar) else { return nil }
            return Day(day: day, date: date, totalMl: byDay[day] ?? 0)
        }
    }

    static func amount(_ ml: Int) -> String {
        "\(ml.formatted()) \(String(localized: .commonMl))"
    }

    /// Top of the chart: room above the goal line for over-achieving days.
    private var ceiling: Double { Double(goalMl) * 1.4 }

    /// A day with any intake shows at least a capsule's worth of fill: an
    /// honest mark instead of a stray sliver.
    private func barHeight(_ totalMl: Int) -> Double {
        min(ceiling, max(Double(totalMl), ceiling * 0.1))
    }

    var body: some View {
        Chart {
            ForEach(days) { day in
                // The empty rail every day sits in, even future ones.
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    yStart: .value("ml", 0),
                    yEnd: .value("ml", ceiling),
                    width: .fixed(18)
                )
                .clipShape(.capsule)
                .foregroundStyle(Palette.backgroundElement)
                // VoiceOver reads a dry past day as "0 ml" rather than
                // skipping it; days to come and filled days stay silent.
                .accessibilityHidden(day.totalMl > 0 || day.day > today)
                .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide)))
                .accessibilityValue(Self.amount(0))

                if day.totalMl > 0 {
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        yStart: .value("ml", 0),
                        yEnd: .value("ml", grown ? barHeight(day.totalMl) : 0),
                        width: .fixed(18)
                    )
                    .clipShape(.capsule)
                    .foregroundStyle(day.day == today ? Palette.primaryDark : Palette.secondaryBlue)
                    .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide)))
                    .accessibilityValue(Self.amount(day.totalMl))
                }
            }

            RuleMark(y: .value("Goal", goalMl))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(Palette.amber.opacity(0.8))
                .accessibilityLabel(Text(.settingsDailyGoal))
                .accessibilityValue(Self.amount(goalMl))
                .annotation(position: .top, alignment: .trailing) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.amber)
                }
        }
        .chartYScale(domain: 0...ceiling)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(centered: true, anchor: .top) {
                    if let date = value.as(Date.self) {
                        let isToday = LocalDay(date, calendar: .autoupdatingCurrent) == today
                        Text(date, format: .dateTime.weekday(.narrow))
                            .font(.brand(isToday ? .bold : .semiBold, size: 12, relativeTo: .caption))
                            .foregroundStyle(isToday ? Palette.primaryDark : Palette.textSecondary)
                    }
                }
            }
        }
        // Audio Graphs: VoiceOver can play the week as tones.
        .accessibilityChartDescriptor(WeekChartDescriptor(
            title: title,
            unit: String(localized: .commonMl),
            days: days.filter { $0.day <= today }.map {
                ($0.date.formatted(.dateTime.weekday(.wide)), $0.totalMl)
            },
            goalMl: goalMl
        ))
    }
}

/// The week as data for Audio Graphs. Plain strings only, built by the view,
/// so the descriptor needs nothing from the main actor.
private nonisolated struct WeekChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let unit: String
    let days: [(name: String, ml: Int)]
    let goalMl: Int

    func makeChartDescriptor() -> AXChartDescriptor {
        let unit = unit
        let top = Double(max(goalMl, days.map(\.ml).max() ?? 0, 1))
        let xAxis = AXCategoricalDataAxisDescriptor(title: title, categoryOrder: days.map(\.name))
        let yAxis = AXNumericDataAxisDescriptor(
            title: unit, range: 0...top, gridlinePositions: [Double(goalMl)]
        ) { "\(Int($0).formatted()) \(unit)" }
        let series = AXDataSeriesDescriptor(
            name: title, isContinuous: false,
            dataPoints: days.map { AXDataPoint(x: $0.name, y: Double($0.ml)) }
        )
        return AXChartDescriptor(title: title, summary: nil, xAxis: xAxis, yAxis: yAxis,
                                 additionalAxes: [], series: [series])
    }
}
