import HydraviaCore
import HydraviaData
import SwiftUI

/// The ordered first-run flow:
/// welcome → weight → schedule → interval → location → Screen Time →
/// notifications → goal reveal → paywall. Permission steps never offer a way
/// to skip their system prompt: declining happens in the prompt itself. Every
/// answer is saved as soon as it's given.
struct OnboardingFlowView: View {
    enum Step: Hashable {
        case weight, schedule, interval, location, screenTime, notifications, goalReveal, paywall

        /// Position in the progress bar (the goal reveal has no bar).
        var progressIndex: Int? {
            switch self {
            case .weight: 1
            case .schedule: 2
            case .interval: 3
            case .location: 4
            case .screenTime: 5
            case .notifications: 6
            case .goalReveal, .paywall: nil
            }
        }

        static let progressCount = 6
    }

    @State private var path: [Step] = []
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStep { path.append(.weight) }
                .navigationDestination(for: Step.self) { step in
                    destination(step)
                        .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func destination(_ step: Step) -> some View {
        switch step {
        case .weight:
            WeightStep { path.append(.schedule) }
        case .schedule:
            ScheduleStep { path.append(.interval) }
        case .interval:
            IntervalStep { path.append(.location) }
        case .location:
            LocationStep { path.append(.screenTime) }
        case .screenTime:
            ScreenTimeStep { path.append(.notifications) }
        case .notifications:
            NotificationsStep { path.append(.goalReveal) }
        case .goalReveal:
            GoalRevealStep { path.append(.paywall) }
        case .paywall:
            // Subscribing or skipping both finish onboarding: manual tracking
            // stays free forever.
            PaywallView(source: .onboarding) { settings.settings.onboardingDone = true }
        }
    }
}

// MARK: - Scaffold

/// The layout every step shares: back + progress on top, content centred,
/// primary (and optional secondary) action at the bottom.
struct OnboardingScaffold<Content: View>: View {
    let step: OnboardingFlowView.Step?
    let title: LocalizedStringResource
    var subtitle: LocalizedStringResource?
    let primary: LocalizedStringResource
    var secondary: LocalizedStringResource?
    var primaryEnabled = true
    let onPrimary: () -> Void
    var onSecondary: (() -> Void)?
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let index = step?.progressIndex {
                header(index: index)
                    .padding(.top, Spacing.sm)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text(title)
                            .font(.brand(.bold, size: 30, relativeTo: .largeTitle))
                            .kerning(-0.7)
                            .foregroundStyle(Palette.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        if let subtitle {
                            Text(subtitle)
                                .font(.bodyRegular)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    content
                }
                .padding(.top, Spacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: Spacing.sm) {
                Button(action: onPrimary) { Text(primary) }
                    .buttonStyle(.primary)
                    .disabled(!primaryEnabled)
                if let secondary, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondary)
                            .font(.brand(.semiBold, size: 16, relativeTo: .body))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.top, Spacing.lg)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.lg)
        .background(Palette.background)
    }

    private func header(index: Int) -> some View {
        HStack(spacing: Spacing.lg) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(Text(.onboardingBack))

            HStack(spacing: 6) {
                ForEach(1...OnboardingFlowView.Step.progressCount, id: \.self) { slot in
                    Capsule()
                        .fill(slot <= index ? Palette.primaryDark : Palette.border)
                        .frame(height: 5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(.onboardingStep(index, OnboardingFlowView.Step.progressCount)))
        }
        .tint(Palette.primaryDark)
    }
}

#Preview {
    OnboardingFlowView().injecting(AppDependencies.preview(onboardingDone: false, todayMl: []))
}
