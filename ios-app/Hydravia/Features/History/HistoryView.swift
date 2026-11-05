import Charts
import HydraviaCore
import HydraviaData
import SwiftUI

/// "Your consistency": the current streak, goals hit, this calendar week as a
/// bar chart against the goal, and the best streak.
struct HistoryView: View {
    @Environment(HydrationStore.self) private var hydration
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        let totals = hydration.recentTotals
        let streakTotals = hydration.streakTotals
        let goal = settings.dailyGoalMl
        let today = hydration.today

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(.historyTitle)
                        .font(.screenTitle)
                        .kerning(-0.5)
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(.historySubtitle)
                        .font(.brandFootnote)
                        .foregroundStyle(Palette.textTertiary)
                }
                .padding(.bottom, Spacing.xs)

                HStack(spacing: Spacing.md) {
                    StatCard(icon: "flame.fill", tint: Palette.amber, label: .historyCurrentStreak,
                             value: Streak.current(streakTotals, goalMl: goal, today: today), suffix: nil)
                    StatCard(icon: "calendar.badge.checkmark", tint: Palette.secondaryBlue, label: .historyDaysReached,
                             value: Streak.daysReached(totals, goalMl: goal, today: today),
                             suffix: "/\(HydrationStore.recentWindowDays)")
                }

                WeekChartCard(totals: totals, goalMl: goal, today: today)

                let best = Streak.best(streakTotals, goalMl: goal, today: today)
                HStack {
                    Label {
                        Text(.historyBestStreak)
                            .font(.bodyRegular)
                            .foregroundStyle(Palette.textPrimary)
                    } icon: {
                        Image(systemName: "trophy.fill").foregroundStyle(Palette.amber)
                    }
                    Spacer()
                    Text("\(best.formatted()) \(String(localized: best == 1 ? .commonDay : .commonDays))")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.primaryDark)
                        .contentTransition(.numericText(value: Double(best)))
                }
                .padding(.vertical, 18)
                .padding(.horizontal, Spacing.xl)
                .card()
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.background)
    }
}

// MARK: - Cards

private extension View {
    func card() -> some View {
        background(.white, in: .rect(cornerRadius: Radius.xl, style: .continuous))
            .shadow(color: Palette.primaryDark.opacity(0.06), radius: 8, y: 4)
    }
}

private struct StatCard: View {
    let icon: String
    let tint: Color
    let label: LocalizedStringResource
    let value: Int
    let suffix: String?

    /// Counts up from zero on first appearance.
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label {
                Text(label)
                    .font(.brand(.regular, size: 13, relativeTo: .caption))
                    .foregroundStyle(Palette.textSecondary)
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(shown, format: .number)
                    .font(.brand(.bold, size: 34, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.primaryDark)
                    .contentTransition(.numericText(value: Double(shown)))
                if let suffix {
                    Text(suffix)
                        .font(.brand(.medium, size: 18, relativeTo: .headline))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(suffix.map { "\(value)\($0)" } ?? "\(value)")
        .onAppear { withAnimation(reduceMotion ? nil : Motion.count.delay(0.1)) { shown = value } }
        .onChange(of: value) { _, new in withAnimation(reduceMotion ? nil : Motion.count) { shown = new } }
    }
}

// MARK: - Week chart

private struct WeekChartCard: View {
    let totals: [DayTotal]
    let goalMl: Int
    let today: LocalDay

    /// Bars grow from zero the first time the card appears.
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Day: Identifiable {
        let day: LocalDay
        let date: Date
        let totalMl: Int
        var id: LocalDay { day }
    }

    /// The calendar week containing today (first weekday per the user's
    /// locale); days after today simply stay empty.
    private var week: [Day] {
        let calendar = Calendar.autoupdatingCurrent
        let byDay = Dictionary(totals.map { ($0.day, $0.totalMl) }, uniquingKeysWith: +)
        guard let todayDate = today.startDate(in: calendar),
              let interval = calendar.dateInterval(of: .weekOfYear, for: todayDate)
        else { return [] }
        let first = LocalDay(interval.start, calendar: calendar)
        return (0..<7).compactMap { offset in
            let day = first.adding(days: offset)
            guard let date = day.startDate(in: calendar) else { return nil }
            return Day(day: day, date: date, totalMl: byDay[day] ?? 0)
        }
    }

    /// Top of the chart: room above the goal line for over-achieving days.
    private var ceiling: Double { Double(goalMl) * 1.4 }

    /// A day with any intake shows at least a capsule's worth of fill — an
    /// honest mark instead of a stray sliver.
    private func barHeight(_ totalMl: Int) -> Double {
        min(ceiling, max(Double(totalMl), ceiling * 0.1))
    }

    var body: some View {
        let week = week
        let drunk = week.filter { $0.totalMl > 0 }
        let averageLiters = drunk.isEmpty ? 0 : Double(drunk.map(\.totalMl).reduce(0, +)) / Double(drunk.count) / 1000

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(.historyThisWeek)
                    .font(.brand(.bold, size: 15, relativeTo: .headline))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(.historyAverage(averageLiters.formatted(.number.precision(.fractionLength(1)))))
                    .font(.brand(.regular, size: 13.5, relativeTo: .subheadline))
                    .foregroundStyle(Palette.textSecondary)
            }

            Chart {
                ForEach(week) { day in
                    // The empty rail every day sits in, even future ones.
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        yStart: .value("ml", 0),
                        yEnd: .value("ml", ceiling),
                        width: .fixed(18)
                    )
                    .clipShape(.capsule)
                    .foregroundStyle(Palette.backgroundElement)
                    .accessibilityHidden(true)

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
                        .accessibilityValue("\(day.totalMl.formatted()) \(String(localized: .commonMl))")
                    }
                }

                RuleMark(y: .value("Goal", goalMl))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Palette.amber.opacity(0.8))
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
                                .foregroundStyle(isToday ? Palette.primaryDark : Palette.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, Spacing.xl)
        .card()
        .onAppear {
            guard !grown else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.25).delay(0.15)) { grown = true }
        }
    }
}

#Preview {
    HistoryView().injecting(AppDependencies.preview(todayMl: [800, 500]))
}
