
import HydraviaCore
import HydraviaData
import SwiftUI

/// "Your consistency": the current streak, goals hit, this calendar week as a
/// bar chart against the goal, and the best streak.
struct HistoryView: View {
    @Environment(HydrationStore.self) private var hydration
    @Environment(SettingsStore.self) private var settings
    @State private var showsEntries = false

    var body: some View {
        let streakTotals = hydration.streakTotals
        let goal = settings.dailyGoalMl
        let today = hydration.today

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(.historyTitle)
                    .font(.screenTitle)
                    .kerning(-0.5)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, Spacing.xs)

                HStack(spacing: Spacing.md) {
                    StatCard(icon: "flame.fill", tint: Palette.amber, label: .historyCurrentStreak,
                             value: Streak.current(streakTotals, goalMl: goal, today: today), suffix: nil)
                    // Every goal ever reached: it only ever grows, so it
                    // still rewards someone whose streak just broke.
                    StatCard(icon: "checkmark.seal.fill", tint: Palette.secondaryBlue, label: .historyDaysReached,
                             value: Streak.daysReached(hydration.allTotals, goalMl: goal, today: today),
                             suffix: nil)
                }

                WeekChartCard(totals: streakTotals, goalMl: goal, today: today)

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

                Button { showsEntries = true } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.secondaryBlue)
                            .accessibilityHidden(true)
                        Text(.historyAllEntries)
                            .font(.bodyEmphasis)
                            .foregroundStyle(Palette.primaryDark)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.textTertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, Spacing.xl)
                    .card()
                    .contentShape(.rect(cornerRadius: Radius.xl, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.background)
        .sheet(isPresented: $showsEntries) {
            EntryLogSheet()
                .presentationDetents([.large])
        }
    }
}

// MARK: - Cards

extension View {
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
                        .foregroundStyle(Palette.textSecondary)
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

#Preview {
    HistoryView().injecting(AppDependencies.preview(todayMl: [800, 500]))
}
