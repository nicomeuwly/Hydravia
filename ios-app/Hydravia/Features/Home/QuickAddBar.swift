import HydraviaData
import SwiftUI

/// The bottom of the home screen: one tap pours the usual amount straight
/// into the screen's water, "+" opens the sheet for anything else.
///
/// After any manual add (here or from the sheet) the button turns into a
/// short confirmation with an undo, in place: a tap that came too fast costs
/// nothing.
struct QuickAddBar: View {
    @Environment(HydrationStore.self) private var hydration
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(BlockerService.self) private var blocker
    @Environment(\.reminders) private var reminders
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(QuickAdd.storageKey) private var lastAmountMl = 0

    @State private var pours = 0

    private static let confirmationSeconds = 3

    private var amount: Int {
        QuickAdd.amount(last: lastAmountMl, favorites: settings.settings.favoriteAmountsMl)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                if let justAdded = router.lastManualAdd {
                    confirmation(justAdded)
                        .transition(.blurReplace)
                } else {
                    quickAddButton
                        .transition(.blurReplace)
                }
            }
            .animation(reduceMotion ? nil : Motion.gentle, value: router.lastManualAdd)

            Button {
                router.sheet = .addWater
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.primaryDark)
                    .frame(width: ControlHeight.primary, height: ControlHeight.primary)
                    .background(.white, in: .circle)
                    .shadow(color: Palette.waterDeep.opacity(0.28), radius: 15, y: 10)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(.homeOtherAmount))
            .sensoryFeedback(.impact(weight: .light), trigger: router.sheet == .addWater) { _, new in new }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pours)
        // Restarted by every new add; cancelled with the view, which is why
        // leaving the tab also clears the confirmation (it would be stale).
        .task(id: router.lastManualAdd?.id) {
            guard router.lastManualAdd != nil else { return }
            try? await Task.sleep(for: .seconds(Self.confirmationSeconds))
            guard !Task.isCancelled else { return }
            router.lastManualAdd = nil
        }
        .onDisappear { router.lastManualAdd = nil }
    }

    private var quickAddButton: some View {
        Button(action: pour) {
            Label {
                Text(.homeQuickAdd(amount.formatted()))
                    .contentTransition(.numericText(value: Double(amount)))
            } icon: {
                Image(systemName: "drop.fill")
                    .symbolEffect(.bounce.up, value: pours)
            }
        }
        .buttonStyle(.primaryLight)
    }

    private func confirmation(_ added: AppRouter.ManualAdd) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.secondaryBlue)
                .accessibilityHidden(true)
            Text(.homeAdded(added.ml.formatted()))
                .font(.brand(.bold, size: 17, relativeTo: .headline))
                .foregroundStyle(Palette.primaryDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: Spacing.sm)
            Button { undo(added) } label: {
                Text(.entriesUndo)
                    .font(.brand(.bold, size: 16, relativeTo: .body))
                    .foregroundStyle(Palette.secondaryBlue)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
        }
        .padding(.leading, Spacing.xl)
        .padding(.trailing, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: ControlHeight.primary)
        .background(.white, in: .rect(cornerRadius: Radius.md, style: .continuous))
        .shadow(color: Palette.waterDeep.opacity(0.28), radius: 15, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func pour() {
        let ml = amount
        // The store logs and rolls back on failure.
        guard (try? WaterLog.addManual(ml, hydration: hydration, router: router,
                                       blocker: blocker, reminders: reminders)) != nil
        else { return }
        pours += 1
        AccessibilityNotification.Announcement(String(localized: .homeAdded(ml.formatted()))).post()
    }

    private func undo(_ added: AppRouter.ManualAdd) {
        router.lastManualAdd = nil
        try? hydration.delete(added.entry)
    }
}
