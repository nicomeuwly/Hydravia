import AppIntents
import HydraviaData
import SwiftUI
import WidgetKit

/// Today's water plus buttons that pour without opening the app. Pro:
/// without it the buttons give way to the way into Pro.
struct QuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HydraviaQuickAdd", provider: HydrationProvider()) { entry in
            QuickAddWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(.widgetQuickAddName))
        .description(Text(.widgetQuickAddDescription))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct QuickAddWidgetView: View {
    let entry: HydrationEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var mode

    private var ink: PlateInk { PlateInk(mode: mode) }

    private var amounts: [Int] {
        family == .systemSmall ? [entry.state.quickAddMl] : Array(entry.state.favoritesMl.prefix(3))
    }

    var body: some View {
        Group {
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 8) {
                    summary
                    actions
                }
            } else {
                HStack(spacing: 12) {
                    summary
                    actions.frame(width: 128)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { WaterBackground(level: entry.progress) }
        .widgetURL(entry.hasPro ? nil : WidgetLink.paywall)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(entry: entry, tint: ink.primary)
            Spacer(minLength: 0)
            AmountLabel(entry: entry, tint: ink.primary, secondary: ink.secondary,
                        size: family == .systemSmall ? 24 : 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // The water rises under the summary: a frosted plate keeps it
        // readable at any level.
        .padding(family == .systemSmall ? 0 : 10)
        .background {
            if family == .systemMedium {
                Plate(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if entry.hasPro {
            VStack(spacing: 6) {
                ForEach(amounts, id: \.self) { ml in
                    Button(intent: AddWaterIntent(amountMl: ml)) {
                        Label {
                            Text(.widgetAdd(ml.formatted()))
                        } icon: {
                            Image(systemName: "drop.fill")
                        }
                        .font(.brand(.bold, size: 15, relativeTo: .body))
                        .foregroundStyle(ink.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background { Plate(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            ProBadge()
        }
    }
}

/// Where a Pro widget's content would be without Pro. The whole widget opens
/// the paywall.
struct ProBadge: View {
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        VStack(spacing: 2) {
            Label { Text(.widgetPro) } icon: { Image(systemName: "lock.fill") }
                .font(.brand(.bold, size: 14, relativeTo: .body))
            Text(.widgetUnlockPro)
                .font(.brand(.regular, size: 11, relativeTo: .caption))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(PlateInk(mode: mode).primary)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Plate(shape: RoundedRectangle(cornerRadius: 16, style: .continuous)) }
    }
}

#Preview(as: .systemSmall) { QuickAddWidget() } timeline: { HydrationEntry.preview }
#Preview(as: .systemMedium) { QuickAddWidget() } timeline: { HydrationEntry.preview }
