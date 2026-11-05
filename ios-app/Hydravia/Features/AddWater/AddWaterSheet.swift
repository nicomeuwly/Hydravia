import HydraviaData
import SwiftUI

/// Manual intake: three bottles for the usual amounts, or any amount typed in.
/// The sheet hugs its content and grows with the keyboard.
struct AddWaterSheet: View {
    @Environment(HydrationStore.self) private var hydration
    @Environment(AppRouter.self) private var router
    @Environment(BlockerService.self) private var blocker
    @Environment(\.reminders) private var reminders
    @Environment(\.dismiss) private var dismiss

    @State private var custom = ""
    @State private var showsRangeError = false
    @State private var contentHeight: CGFloat = 320
    @State private var added = 0
    @FocusState private var fieldFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Preset: Identifiable {
        let ml: Int
        /// How full the little bottle looks — a glass, a can, a bottle.
        let fill: Double
        var id: Int { ml }
    }

    private static let presets = [
        Preset(ml: 200, fill: 0.40),
        Preset(ml: 330, fill: 0.62),
        Preset(ml: 500, fill: 0.88),
    ]
    static let maxCustomMl = 2000

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text(.addWaterTitle)
                .font(.brand(.bold, size: 22, relativeTo: .title2))
                .foregroundStyle(Palette.textPrimary)

            // Side by side normally; stacked at accessibility text sizes.
            AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Spacing.md)) : AnyLayout(HStackLayout(spacing: Spacing.md))) {
                ForEach(Array(Self.presets.enumerated()), id: \.element.id) { index, preset in
                    PresetBottle(ml: preset.ml, fill: preset.fill, delay: Double(index) * 0.07) {
                        add(preset.ml)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    TextField(text: $custom) {
                        Text(.addWaterPlaceholder)
                    }
                    .keyboardType(.numberPad)
                    .focused($fieldFocused)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .frame(minHeight: 54)
                    .background(.white, in: .rect(cornerRadius: Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(showsRangeError ? Palette.error : Palette.border, lineWidth: 1.5)
                    }
                    .accessibilityLabel(Text(.addWaterA11YCustom))
                    .onChange(of: custom) { _, new in
                        // Digits only, four at most: 2 000 is the ceiling.
                        let digits = String(new.filter { $0.isASCII && $0.isNumber }.prefix(4))
                        if digits != new { custom = digits }
                        showsRangeError = false
                    }
                    .onSubmit(addCustom)

                    Button(action: addCustom) {
                        Text(.addWaterAdd)
                            .font(.brand(.bold, size: 16, relativeTo: .headline))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.xl)
                            .frame(minHeight: 54)
                            .background(Palette.primaryDark, in: .rect(cornerRadius: Radius.md, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .disabled(custom.isEmpty)
                    .opacity(custom.isEmpty ? 0.4 : 1)
                    .animation(Motion.fast, value: custom.isEmpty)
                }

                if showsRangeError {
                    // Silently ignoring "9999" reads as a broken button.
                    Text(.addWaterOutOfRange(Self.maxCustomMl))
                        .font(.brandFootnote)
                        .foregroundStyle(Palette.error)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.xxl + Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Content height only. Never add the bottom safe-area inset here: once
        // the keyboard is up that inset IS the keyboard, so the detent grows,
        // the inset changes, the detent grows again — a layout loop that
        // froze the app as soon as the field was focused.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { new in
            if abs(new - contentHeight) > 0.5 { contentHeight = new }
        }
        .scrollBounceBehavior(.basedOnSize)
        .wrappedInScrollView(typeSize.isAccessibilitySize)
        // At accessibility sizes the content can outgrow the hug detent: the
        // sheet then also opens fully and scrolls.
        .presentationDetents(typeSize.isAccessibilitySize ? [.height(contentHeight), .large] : [.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.background)
        .animation(Motion.gentle, value: showsRangeError)
        .sensoryFeedback(.success, trigger: added)
        .sensoryFeedback(.error, trigger: showsRangeError) { _, new in new }
    }

    private func addCustom() {
        guard let ml = Int(custom), (1...Self.maxCustomMl).contains(ml) else {
            showsRangeError = true
            return
        }
        add(ml)
    }

    private func add(_ ml: Int) {
        do {
            try hydration.add(ml, source: .manual)
            added += 1
            // Drinking answers the reminder. The apps stay locked, though
            // (only the ritual lifts the shield): while it's up the ritual
            // card stays lit.
            router.reminderFired = blocker.isShieldUp
            Task { await reminders?.clearDeliveredReminders() }
            fieldFocused = false
            dismiss()
        } catch {
            // The store logged and rolled back; staying open lets the user retry.
        }
    }
}

/// A preset as a little bottle that fills up when the sheet appears.
private struct PresetBottle: View {
    let ml: Int
    let fill: Double
    let delay: Double
    let action: () -> Void

    @State private var shownFill = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Palette.backgroundElement)
                    .frame(width: 44, height: 64)
                    .overlay(alignment: .bottom) {
                        // A flat surface, rounded only by the bottle's clip:
                        // it reads as liquid, not as a block.
                        Rectangle()
                            .fill(LinearGradient(colors: [Palette.waterSurface, Palette.primaryDark],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: 64 * shownFill)
                    }
                    .clipShape(.rect(cornerRadius: Radius.sm, style: .continuous))

                Text("\(ml.formatted()) \(String(localized: .commonMl))")
                    .font(.brand(.bold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Palette.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, Spacing.md)
            .background(.white, in: .rect(cornerRadius: Radius.xl, style: .continuous))
            .shadow(color: Palette.primaryDark.opacity(0.06), radius: 7, y: 4)
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .onAppear {
            guard !reduceMotion else {
                shownFill = fill
                return
            }
            withAnimation(Motion.bouncy.delay(0.12 + delay)) { shownFill = fill }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddWaterSheet()
    }
    .injecting(AppDependencies.preview())
}

private extension View {
    @ViewBuilder
    func wrappedInScrollView(_ enabled: Bool) -> some View {
        if enabled { ScrollView { self } } else { self }
    }
}
