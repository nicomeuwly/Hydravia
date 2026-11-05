import SwiftUI
import WidgetKit

/// Today's water against the goal, on the Home Screen. Free.
struct ProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HydraviaProgress", provider: HydrationProvider()) { entry in
            ProgressWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(.widgetProgressName))
        .description(Text(.widgetProgressDescription))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct ProgressWidgetView: View {
    let entry: HydrationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Waterline(level: entry.progress) { tint, secondary in
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetHeader(entry: entry, tint: tint)
                    Spacer(minLength: 0)
                    AmountLabel(entry: entry, tint: tint, secondary: secondary, size: family == .systemSmall ? 30 : 34)
                }
                if family == .systemMedium {
                    Spacer(minLength: 8)
                    ReminderLabel(entry: entry, tint: tint, secondary: secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { WaterBackground(level: entry.progress) }
    }
}

/// The drop and today's percentage, or a check once the goal is reached.
struct WidgetHeader: View {
    let entry: HydrationEntry
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.isGoalReached ? "checkmark.circle.fill" : "drop.fill")
                .font(.system(size: 13, weight: .bold))
            Text(entry.isGoalReached ? String(localized: .widgetGoalReached)
                                     : min(entry.progress, 1).formatted(.percent.precision(.fractionLength(0))))
                .font(.brand(.bold, size: 13, relativeTo: .caption))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(tint)
    }
}

/// "1'250" over "/ 2'300 ml".
struct AmountLabel: View {
    let entry: HydrationEntry
    let tint: Color
    let secondary: Color
    var size: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.consumedMl.formatted())
                .font(.brand(.bold, size: size, relativeTo: .title))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(entry.consumedMl)))
            Text(.widgetOfGoal(entry.goalMl.formatted()))
                .font(.brand(.semiBold, size: 13, relativeTo: .caption))
                .foregroundStyle(secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// When the next reminder fires.
struct ReminderLabel: View {
    let entry: HydrationEntry
    let tint: Color
    let secondary: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Image(systemName: entry.nextReminder == nil ? "bell.slash.fill" : "bell.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(.widgetNextReminder)
                .font(.brand(.semiBold, size: 12, relativeTo: .caption))
                .foregroundStyle(secondary)
            if let next = entry.nextReminder {
                Text(next, format: .dateTime.hour().minute())
                    .font(.brand(.bold, size: 17, relativeTo: .headline))
                    .foregroundStyle(tint)
            } else {
                Text(.widgetRemindersOff)
                    .font(.brand(.bold, size: 14, relativeTo: .headline))
                    .foregroundStyle(tint)
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
    }
}

#Preview(as: .systemSmall) { ProgressWidget() } timeline: { HydrationEntry.preview }
#Preview(as: .systemMedium) { ProgressWidget() } timeline: { HydrationEntry.preview }
