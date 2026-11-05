import FamilyControls
import SwiftUI

extension View {
    /// The system app picker, held to the plan: the free plan locks one app.
    /// A pick past the limit isn't saved; an alert offers to pick again or
    /// to go Pro.
    func blockedAppsPicker(isPresented: Binding<Bool>) -> some View {
        modifier(BlockedAppsPicker(isPresented: isPresented))
    }
}

private struct BlockedAppsPicker: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(BlockerService.self) private var blocker
    @Environment(AppRouter.self) private var router
    @State private var picked = FamilyActivitySelection()
    @State private var showsLimit = false
    /// Picking again after the alert starts from the pick that was too big,
    /// so trimming it takes a tap or two.
    @State private var isRetrying = false

    func body(content: Content) -> some View {
        content
            .familyActivityPicker(isPresented: $isPresented, selection: $picked)
            .onChange(of: isPresented) { _, open in
                if open {
                    if !isRetrying { picked = blocker.selection }
                    isRetrying = false
                } else if blocker.covers(picked) {
                    blocker.setSelection(picked)
                } else {
                    showsLimit = true
                }
            }
            .alert(Text(.blockerFreeLimitTitle), isPresented: $showsLimit) {
                Button { isRetrying = true; isPresented = true } label: { Text(.blockerChooseOneApp) }
                Button { router.sheet = .paywall } label: { Text(.blockerGoPro) }
                Button(role: .cancel) {} label: { Text(.commonCancel) }
            } message: {
                Text(.blockerFreeLimitBody)
            }
    }
}
