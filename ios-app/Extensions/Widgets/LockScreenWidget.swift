import SwiftUI
import WidgetKit

/// Today's water on the Lock Screen. Pro.
struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HydraviaLockScreen", provider: HydrationProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(entry.hasPro ? nil : WidgetLink.paywall)
        }
        .configurationDisplayName(Text(.widgetLockName))
        .description(Text(.widgetLockDescription))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenWidgetView: View {
    let entry: HydrationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.hasPro { content } else { locked }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: min(entry.progress, 1)) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Image(systemName: entry.isGoalReached ? "checkmark" : "drop.fill")
                    .font(.system(size: 18, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
            .accessibilityLabel(Text(.widgetOfToday(entry.consumedMl.formatted(), entry.goalMl.formatted())))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(.widgetOfToday(entry.consumedMl.formatted(), entry.goalMl.formatted()))
                    .font(.brand(.bold, size: 15, relativeTo: .headline))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Gauge(value: min(entry.progress, 1)) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .widgetAccentable()
                if let next = entry.nextReminder, !entry.isGoalReached {
                    Text(.widgetNextAt(next.formatted(.dateTime.hour().minute())))
                        .font(.brand(.regular, size: 12, relativeTo: .caption))
                        .lineLimit(1)
                } else if entry.isGoalReached {
                    Text(.widgetGoalReached)
                        .font(.brand(.regular, size: 12, relativeTo: .caption))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Label {
                Text(.widgetOfToday(entry.consumedMl.formatted(), entry.goalMl.formatted()))
            } icon: {
                Image(systemName: "drop.fill")
            }
        }
    }

    @ViewBuilder
    private var locked: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lock.fill").font(.system(size: 18, weight: .bold))
            }
            .accessibilityLabel(Text(.widgetPro))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label { Text(.widgetPro) } icon: { Image(systemName: "lock.fill") }
                    .font(.brand(.bold, size: 15, relativeTo: .headline))
                Text(.widgetUnlockPro)
                    .font(.brand(.regular, size: 12, relativeTo: .caption))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Label { Text(.widgetPro) } icon: { Image(systemName: "lock.fill") }
        }
    }
}

#Preview(as: .accessoryRectangular) { LockScreenWidget() } timeline: { HydrationEntry.preview }
