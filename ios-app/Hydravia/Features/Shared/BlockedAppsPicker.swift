import FamilyControls
import HydraviaCore
import SwiftUI

extension View {
    /// The system app picker, held to the plan and to what Screen Time can
    /// shield: the free plan locks one app, and one shield holds at most 50
    /// single apps. A pick past either limit isn't saved; an alert offers to
    /// pick again (or, for the plan, to go Pro).
    func blockedAppsPicker(isPresented: Binding<Bool>) -> some View {
        modifier(BlockedAppsPicker(isPresented: isPresented))
    }

    /// The picker sheet with the footer that explains the limit that applies.
    func hydraviaActivityPicker(isPresented: Binding<Bool>, selection: Binding<FamilyActivitySelection>,
                                isPro: Bool) -> some View {
        familyActivityPicker(
            footerText: isPro
                ? String(localized: .blockerPickerFooter(BlockSelectionSize.shieldLimit))
                : String(localized: .settingsBlockedAppsFreeFooter),
            isPresented: isPresented, selection: selection)
    }
}

private struct BlockedAppsPicker: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(BlockerService.self) private var blocker
    @Environment(AppRouter.self) private var router
    @State private var picked = FamilyActivitySelection()
    @State private var showsLimit = false
    @State private var showsTooMany = false
    /// Picking again after an alert starts from the pick that was too big,
    /// so trimming it takes a tap or two.
    @State private var isRetrying = false

    func body(content: Content) -> some View {
        content
            .hydraviaActivityPicker(isPresented: $isPresented, selection: $picked, isPro: blocker.isPro)
            .onChange(of: isPresented) { _, open in
                if open {
                    if !isRetrying { picked = blocker.selection }
                    isRetrying = false
                } else if !blocker.covers(picked) {
                    showsLimit = true
                } else if !blocker.canEnforce(picked) {
                    showsTooMany = true
                } else {
                    blocker.setSelection(picked)
                }
            }
            .alert(Text(.blockerFreeLimitTitle), isPresented: $showsLimit) {
                Button { pickAgain() } label: { Text(.blockerChooseOneApp) }
                Button { router.sheet = .paywall } label: { Text(.blockerGoPro) }
                Button(role: .cancel) {} label: { Text(.commonCancel) }
            } message: {
                Text(.blockerFreeLimitBody)
            }
            .tooManyAppsAlert(isPresented: $showsTooMany, onEdit: pickAgain)
    }

    private func pickAgain() {
        isRetrying = true
        isPresented = true
    }
}

extension View {
    /// More single apps or websites picked than one shield holds: the pick
    /// isn't saved (cancel keeps the previous one).
    func tooManyAppsAlert(isPresented: Binding<Bool>, onEdit: @escaping () -> Void,
                          onCancel: @escaping () -> Void = {}) -> some View {
        alert(Text(.blockerTooManyTitle), isPresented: isPresented) {
            Button(action: onEdit) { Text(.blockerEditSelection) }
            Button(role: .cancel, action: onCancel) { Text(.commonCancel) }
        } message: {
            Text(.blockerTooManyBody(BlockSelectionSize.shieldLimit, BlockSelectionSize.shieldLimit))
        }
    }
}
