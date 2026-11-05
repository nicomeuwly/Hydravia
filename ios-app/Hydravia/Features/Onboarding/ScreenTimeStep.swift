import FamilyControls
import SwiftUI

/// Screen Time access, then the apps to lock: without a selection there is
/// nothing to shield, so the picker is the second half of this step.
/// "Continue" goes straight to the system prompt, where declining happens
/// (App Review guideline 5.1.1(iv)); the app works without the lock.
struct ScreenTimeStep: View {
    let onNext: () -> Void
    @Environment(BlockerService.self) private var blocker
    @State private var isPicking = false
    @State private var picked = FamilyActivitySelection()
    @State private var isRequesting = false

    var body: some View {
        OnboardingScaffold(step: .screenTime, title: .screenTimeTitleIos, subtitle: .screenTimeBodyIos,
                           primary: .commonContinue,
                           primaryEnabled: !isRequesting,
                           onPrimary: allow) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                explainer(1, .screenTimeStep1Ios)
                explainer(2, .screenTimeStep2Ios)
                explainer(3, .screenTimeStep3Ios)
            }
        }
        .familyActivityPicker(isPresented: $isPicking, selection: $picked)
        .onChange(of: isPicking) { _, open in
            guard !open else { return }
            blocker.setSelection(picked)
            onNext()
        }
    }

    private func explainer(_ number: Int, _ text: LocalizedStringResource) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(number, format: .number)
                .font(.brand(.bold, size: 13, relativeTo: .caption))
                .foregroundStyle(Palette.primaryDark)
                .frame(width: 26, height: 26)
                .background(Palette.backgroundElement, in: .circle)
                .accessibilityHidden(true)
            Text(text)
                .font(.brandFootnote)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func allow() {
        isRequesting = true
        Task {
            defer { isRequesting = false }
            if await blocker.requestAuthorization() {
                picked = blocker.selection
                isPicking = true
            } else {
                // Declined, or a simulator: the app works without the lock.
                onNext()
            }
        }
    }
}

#Preview {
    ScreenTimeStep {}.injecting(AppDependencies.preview(onboardingDone: false, todayMl: []))
}
