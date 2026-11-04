import HydraviaCore
import HydraviaData
import SwiftUI

/// The ritual — the product's differentiator. Full screen, dark (the contrast
/// IS the ritual), no way out but drinking:
/// one question ("how do you feel?") → a computed dose → "I drank it", and the
/// water visibly rises behind the confirmation before the phone is released.
struct UnlockView: View {
    @Environment(HydrationStore.self) private var hydration
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.reminders) private var reminders
    @Environment(BlockerService.self) private var blocker
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Stage { case question, dose, poured }

    @State private var stage = Stage.question
    @State private var feeling: Feeling?
    @State private var dose = 0
    @State private var shownDose = 0
    @State private var temperature: Double?
    @State private var physics = WaterPhysics()
    @State private var saveFailures = 0
    @State private var checkBounce = 0
    @State private var viewportHeight: CGFloat = 560
    @AccessibilityFocusState private var stageFocused: Bool

    /// After this many failed writes the phone is released anyway: a ritual
    /// with no way out must never become a trap because of a storage error.
    private static let maxSaveFailures = 2

    private var level: Double {
        max(0.06, HydrationGoal.progress(consumedMl: hydration.todayTotalMl, goalMl: settings.dailyGoalMl))
    }

    var body: some View {
        ZStack {
            Palette.waterDeep.ignoresSafeArea()

            LiveWater(physics: physics, isActive: scenePhase == .active)
                .ignoresSafeArea()

            // Night over the water: the ritual reads as a different place.
            Palette.nightOverlay.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, Spacing.lg)

                // Scrolls only when it must (AX text sizes on small phones):
                // the release build has no way out but the buttons below.
                ScrollView {
                    ZStack {
                        switch stage {
                        case .question: questionStage.transition(.stageChange)
                        case .dose: doseStage.transition(.stageChange)
                        case .poured: pouredStage.transition(.stageChange)
                        }
                    }
                    // Fills the screen normally; taller content scrolls.
                    .frame(minHeight: viewportHeight)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, Spacing.xxl)
            .animation(Motion.slow, value: stage)

            #if DEBUG
            devCloseButton
            #endif
        }
        .preferredColorScheme(.dark)
        .onAppear { physics.setLevel(level, splash: false) }
        .onChange(of: level) { old, new in
            physics.setLevel(new, splash: new > old && !reduceMotion)
        }
        .task { temperature = await WeatherService.shared.currentTemperature() }
        .onChange(of: temperature) {
            // The weather can land after the answer: keep the dose honest.
            guard stage == .dose, let feeling else { return }
            let updated = computeDose(for: feeling)
            if updated != dose {
                dose = updated
                withAnimation(Motion.count) { shownDose = updated }
            }
        }
        .onChange(of: stage) { _, new in
            stageFocused = true
            if new == .poured {
                checkBounce += 1
                AccessibilityNotification.Announcement(String(localized: .unlockPouredSub)).post()
            }
        }
        // Tied to the view: cancelled if the ritual closes another way, so it
        // can never dismiss a ritual presented after this one.
        .task(id: stage) {
            guard stage == .poured else { return }
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled else { return }
            router.isUnlockPresented = false
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            Label {
                Text(.unlockLocked)
            } icon: {
                Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
            }
            .font(.brand(.bold, size: 13, relativeTo: .caption))
            .kerning(1.5)
            .foregroundStyle(.white.opacity(0.55))

            Text(.unlockLockedSub)
                .font(.brandFootnote)
                .foregroundStyle(.white.opacity(0.45))
        }
        .multilineTextAlignment(.center)
    }

    // MARK: Stages

    private var questionStage: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Text(.unlockQuestion)
                .font(.brand(.bold, size: 32, relativeTo: .largeTitle))
                .kerning(-0.6)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($stageFocused)
            Spacer()

            GlassEffectContainer(spacing: Spacing.md) {
                VStack(spacing: Spacing.md) {
                    feelingButton(.fine, label: .unlockRessentiOk)
                    feelingButton(.hot, label: .unlockRessentiChaud)
                    feelingButton(.veryThirsty, label: .unlockRessentiTresSoif)
                }
            }

            if let temperature {
                Label {
                    Text(.unlockTemperature(Int(temperature.rounded())))
                } icon: {
                    Image(systemName: "sun.max.fill")
                }
                .font(.brand(.medium, size: 14, relativeTo: .footnote))
                .foregroundStyle(Palette.sunlight)
                .transition(.opacity)
            }
        }
        .animation(Motion.base, value: temperature != nil)
    }

    private func feelingButton(_ value: Feeling, label: LocalizedStringResource) -> some View {
        Button {
            choose(value)
        } label: {
            Text(label)
                .font(.brand(.semiBold, size: 17, relativeTo: .body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassEffect(
            .clear.tint(.white.opacity(feeling == value ? 0.22 : 0.04)).interactive(),
            in: .rect(cornerRadius: Radius.lg, style: .continuous)
        )
        .sensoryFeedback(.selection, trigger: feeling) { _, new in new == value }
        .accessibilityAddTraits(feeling == value ? .isSelected : [])
    }

    private var doseStage: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Text(.unlockDoseLabel)
                .font(.eyebrow)
                .kerning(1.8)
                .foregroundStyle(.white.opacity(0.5))

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(shownDose, format: .number)
                    .font(.brand(.bold, size: 96, relativeTo: .largeTitle))
                    .kerning(-4)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(shownDose)))
                Text(.commonMl)
                    .font(.brand(.regular, size: 30, relativeTo: .title))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            // The final dose, not the count-up frame VoiceOver happens to catch.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(dose.formatted()) \(String(localized: .commonMl))"))
            .accessibilityFocused($stageFocused)

            if saveFailures > 0 {
                Label { Text(.unlockSaveFailed) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                    .font(.brandFootnote)
                    .foregroundStyle(Palette.amber)
                    .transition(.opacity)
            }

            Text(.unlockDoseSub)
                .font(.brand(.regular, size: 15, relativeTo: .body))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: 260)
            Spacer()

            Button(action: drink) {
                Label {
                    Text(.unlockDrank)
                } icon: {
                    Image(systemName: "lock.open.fill")
                }
            }
            .buttonStyle(.primaryLight)
        }
        .task {
            // The dose counts up from zero — the number lands, it doesn't appear.
            shownDose = 0
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { shownDose = dose }
        }
    }

    private var pouredStage: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .glassEffect(.clear.tint(.white.opacity(0.16)), in: .circle)
                .symbolEffect(.bounce, value: checkBounce)
                .accessibilityHidden(true)

            Text("+\(dose.formatted()) \(String(localized: .commonMl))")
                .font(.brand(.bold, size: 44, relativeTo: .largeTitle))
                .kerning(-1.5)
                .foregroundStyle(.white)

            Text(.unlockPouredSub)
                .font(.brand(.regular, size: 15, relativeTo: .body))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityFocused($stageFocused)
    }

    #if DEBUG
    /// Dev only: the real ritual has no way out but drinking.
    private var devCloseButton: some View {
        Button {
            router.isUnlockPresented = false
        } label: {
            Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
        }
        .buttonStyle(.glass)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, Spacing.lg)
    }
    #endif

    // MARK: Actions

    private func choose(_ value: Feeling) {
        guard stage == .question else { return } // a second tap mid-transition
        feeling = value
        dose = computeDose(for: value)
        stage = .dose
    }

    private func computeDose(for value: Feeling) -> Int {
        let now = Date.now
        let window = settings.settings.window
        return Dose.ml(for: DoseInput(
            goalMl: settings.dailyGoalMl,
            drunkMl: hydration.todayTotalMl,
            now: now,
            windowEnd: Dose.windowEnd(sleep: window.sleep, now: now, calendar: .autoupdatingCurrent),
            intervalMin: window.intervalMin,
            feeling: value,
            temperatureC: temperature
        ))
    }

    /// The climax: the water rises behind the confirmation, then the phone is
    /// released.
    private func drink() {
        guard stage == .dose else { return } // double tap would add twice
        do {
            try hydration.add(dose, source: .unlock)
        } catch {
            // The store logged and rolled back. Let the user retry once; after
            // that, release the phone anyway rather than trap them.
            saveFailures += 1
            guard saveFailures >= Self.maxSaveFailures else { return }
        }
        stage = .poured
        Haptics.celebrate()
        router.reminderFired = false
        Task { await reminders?.clearDeliveredReminders() }
        // The phone is free until the next reminder is due.
        blocker.unlockAfterDrinking(intervalMin: settings.settings.window.intervalMin)
    }
}

private extension AnyTransition {
    static var stageChange: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 24)),
            removal: .opacity
        )
    }
}

#Preview {
    UnlockView().injecting(AppDependencies.preview(todayMl: [800]))
}
