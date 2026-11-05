import HydraviaCore
import HydraviaData
import SwiftUI
import WidgetKit

@main
struct HydraviaWatchWidgets: WidgetBundle {
    var body: some Widget {
        ProgressComplication()
    }
}

/// Today's water on the watch face. Free, like the iPhone's progress widget.
struct ProgressComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HydraviaWatchProgress", provider: Provider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text(.complicationName))
        .description(Text(.complicationDescription))
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let consumedMl: Int
    let goalMl: Int
    let progress: Double
    let nextReminder: Date?
    let goalReached: Bool

    init(date: Date, local: WatchLocalState) {
        self.date = date
        consumedMl = local.todayMl(at: date)
        goalMl = local.state.goalMl
        progress = local.progress(at: date)
        nextReminder = local.nextReminder(after: date)
        goalReached = local.isGoalReached(at: date)
    }
}

/// Redrawn by the watch app on every change; between changes, the reminder
/// line moves on at each reminder and the count resets at midnight.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, local: WatchLocalState())
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, local: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let local = WatchLocalState.load()
        let calendar = Calendar.autoupdatingCurrent
        let now = Date.now
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let reminders = ReminderPlan.fireDates(window: local.state.window, now: now, goalReachedToday: false,
                                               calendar: calendar, budget: 30)
            .filter { $0 < midnight }
        let moments = [now] + reminders + [midnight]
        completion(Timeline(entries: moments.map { Entry(date: $0, local: local) }, policy: .after(midnight)))
    }
}

struct ComplicationView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    private var fill: Double { min(max(entry.progress, 0), 1) }
    private static let tint = Color(.sRGB, red: 0.373, green: 0.784, blue: 0.851)

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: fill) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text(fill, format: .percent.precision(.fractionLength(0)))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(Self.tint)
        case .accessoryCorner:
            Image(systemName: entry.goalReached ? "checkmark" : "drop.fill")
                .font(.title3.weight(.semibold))
                .widgetAccentable()
                .widgetLabel {
                    Gauge(value: fill) {
                        Text(verbatim: "")
                    } currentValueLabel: {
                        Text(entry.consumedMl.formatted())
                    }
                    .tint(Self.tint)
                }
        case .accessoryInline:
            Label {
                Text(.complicationInline(entry.consumedMl.formatted(), entry.goalMl.formatted()))
            } icon: {
                Image(systemName: "drop.fill")
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Label { Text(verbatim: "Hydravia") } icon: { Image(systemName: "drop.fill") }
                    .font(.headline)
                    .widgetAccentable()
                Text(.complicationInline(entry.consumedMl.formatted(), entry.goalMl.formatted()))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                Gauge(value: fill) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(Self.tint)
                if entry.goalReached {
                    Text(.complicationGoalReached).font(.caption2)
                } else if let next = entry.nextReminder {
                    Text(.complicationNextReminder(next.formatted(date: .omitted, time: .shortened))).font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
