import HydraviaData
import SwiftUI

/// Manual intake, as a glass to fill: drag up or down on it (or anywhere
/// across its row), nudge it with − / +, pick a favourite, or tap the number
/// to type one. Then one button pours it. The sheet hugs its content and
/// grows with the keyboard.
struct AddWaterSheet: View {
    @Environment(HydrationStore.self) private var hydration
    @Environment(AppRouter.self) private var router
    @Environment(BlockerService.self) private var blocker
    @Environment(SettingsStore.self) private var settings
    @Environment(\.reminders) private var reminders
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Remembered for the home screen's one-tap add.
    @AppStorage(QuickAdd.storageKey) private var lastAmountMl = 0

    @State private var amount: Int?
    @State private var typed = ""
    @State private var isTyping = false
    @State private var showsRangeError = false
    @State private var contentHeight: CGFloat = 420
    @State private var added = 0
    @FocusState private var fieldFocused: Bool

    static let maxCustomMl = 2000
    /// The glass is full at a litre; typed amounts can go beyond.
    static let glassMl = 1000
    private static let dragStep = 50
    private static let nudgeStep = 10

    private var favorites: [Int] { settings.settings.favoriteAmountsMl }

    /// What the button pours: the typed amount while typing, else the glass.
    private var current: Int {
        if isTyping { return Int(typed) ?? 0 }
        return amount ?? QuickAdd.amount(last: lastAmountMl, favorites: favorites)
    }

    private var isValid: Bool { (1...Self.maxCustomMl).contains(current) }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text(.addWaterTitle)
                .font(.brand(.bold, size: 22, relativeTo: .title2))
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            amountLabel

            HStack(spacing: Spacing.md) {
                nudgeButton("minus", delta: -Self.nudgeStep, label: .commonDecrease)
                glassArea
                nudgeButton("plus", delta: Self.nudgeStep, label: .commonIncrease)
            }

            favoriteChips

            VStack(spacing: Spacing.sm) {
                if showsRangeError {
                    // Silently ignoring "9999" reads as a broken button.
                    Text(.addWaterOutOfRange(Self.maxCustomMl))
                        .font(.brandFootnote)
                        .foregroundStyle(Palette.error)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                Button(action: pour) {
                    Label {
                        Text(.addWaterAddAmount(current.formatted()))
                            .contentTransition(.numericText(value: Double(current)))
                    } icon: {
                        Image(systemName: "drop.fill")
                    }
                }
                .buttonStyle(.primary)
                .disabled(current <= 0)
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.xxl + Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity)
        // Content height only. Never add the bottom safe-area inset here: once
        // the keyboard is up that inset IS the keyboard, so the detent grows,
        // the inset changes, the detent grows again: a layout loop that
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
        .animation(Motion.gentle, value: isTyping)
        .sensoryFeedback(.selection, trigger: isTyping ? 0 : current)
        .sensoryFeedback(.success, trigger: added)
        .sensoryFeedback(.error, trigger: showsRangeError) { _, new in new }
        .onChange(of: fieldFocused) { _, focused in
            if !focused { finishTyping() }
        }
    }

    // MARK: Amount

    /// The amount, big. Tapping it swaps in a number field.
    @ViewBuilder
    private var amountLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if isTyping {
                TextField(text: $typed) { Text(verbatim: "0") }
                    .keyboardType(.numberPad)
                    .focused($fieldFocused)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .accessibilityLabel(Text(.addWaterA11YCustom))
                    .onChange(of: typed) { _, new in
                        // Digits only, four at most: 2 000 is the ceiling.
                        let digits = String(new.filter { $0.isASCII && $0.isNumber }.prefix(4))
                        if digits != new { typed = digits }
                        showsRangeError = false
                    }
            } else {
                Button(action: startTyping) {
                    Text(current, format: .number)
                        .contentTransition(.numericText(value: Double(current)))
                        .underline(pattern: .dot, color: Palette.textTertiary.opacity(0.5))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(.addWaterTypeAmount))
                .accessibilityValue("\(current.formatted()) \(String(localized: .commonMl))")
            }
            Text(.commonMl)
                .font(.brand(.medium, size: 22, relativeTo: .title3))
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
        }
        .font(.brand(.bold, size: 46, relativeTo: .largeTitle))
        .foregroundStyle(Palette.primaryDark)
        .lineLimit(1)
        .animation(Motion.fast, value: current)
    }

    private func startTyping() {
        typed = ""
        isTyping = true
        fieldFocused = true
    }

    /// Back from the field: a valid number becomes the glass's amount.
    private func finishTyping() {
        guard isTyping else { return }
        if let ml = Int(typed), (1...Self.maxCustomMl).contains(ml) {
            withAnimation(reduceMotion ? nil : Motion.gentle) { amount = ml }
        }
        isTyping = false
    }

    // MARK: Glass

    private var glassArea: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            FillableGlass(fill: min(Double(current) / Double(Self.glassMl), 1))
                .frame(width: 128, height: height)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if isTyping { fieldFocused = false; isTyping = false }
                            showsRangeError = false
                            let fraction = min(max(1 - value.location.y / height, 0), 1)
                            let steps = (fraction * Double(Self.glassMl) / Double(Self.dragStep)).rounded()
                            let ml = max(Self.dragStep, Int(steps) * Self.dragStep)
                            if ml != amount {
                                withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                                    amount = ml
                                }
                            }
                        }
                )
        }
        .frame(height: 190)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.addWaterA11YGlass))
        .accessibilityValue("\(current.formatted()) \(String(localized: .commonMl))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(Self.dragStep)
            case .decrement: nudge(-Self.dragStep)
            @unknown default: break
            }
        }
    }

    private func nudgeButton(_ symbol: String, delta: Int, label: LocalizedStringResource) -> some View {
        Button { nudge(delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.primaryDark)
                .frame(width: 48, height: 48)
                .background(.white, in: .circle)
                .shadow(color: Palette.primaryDark.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(Text(label))
    }

    private func nudge(_ delta: Int) {
        if isTyping { fieldFocused = false; finishTyping() }
        showsRangeError = false
        let next = min(max(current + delta, Self.nudgeStep), Self.maxCustomMl)
        withAnimation(reduceMotion ? nil : Motion.gentle) { amount = next }
    }

    // MARK: Favourites

    private var favoriteChips: some View {
        HStack(spacing: Spacing.sm) {
            // By position: two favourites may hold the same amount.
            ForEach(Array(favorites.enumerated()), id: \.offset) { _, ml in
                let selected = !isTyping && current == ml
                Button {
                    if isTyping { fieldFocused = false; isTyping = false }
                    showsRangeError = false
                    withAnimation(reduceMotion ? nil : Motion.bouncy) { amount = ml }
                } label: {
                    HStack(spacing: 6) {
                        BottleGlyph(fill: BottleGlyph.fill(forMl: ml), width: 12, height: 18)
                        Text("\(ml.formatted()) \(String(localized: .commonMl))")
                            .font(.brand(.bold, size: 15, relativeTo: .subheadline))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selected ? .white : Palette.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(selected ? Palette.secondaryBlue : .white, in: .capsule)
                    .shadow(color: Palette.primaryDark.opacity(selected ? 0 : 0.06), radius: 6, y: 3)
                }
                .buttonStyle(PressableStyle(scale: 0.95))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .animation(Motion.fast, value: selected)
            }
        }
    }

    // MARK: Pour

    private func pour() {
        if isTyping { fieldFocused = false }
        let ml = current
        guard (1...Self.maxCustomMl).contains(ml) else {
            showsRangeError = true
            // VoiceOver users don't see the red text appear.
            AccessibilityNotification.Announcement(String(localized: .addWaterOutOfRange(Self.maxCustomMl))).post()
            return
        }
        do {
            try WaterLog.addManual(ml, hydration: hydration, router: router, blocker: blocker, reminders: reminders)
            // A one-off big bottle typed in doesn't become the one-tap amount.
            if ml <= Self.glassMl { lastAmountMl = ml }
            added += 1
            dismiss()
        } catch {
            // The store logged and rolled back; staying open lets the user retry.
        }
    }
}

/// The home screen's one-tap amount: the last one poured by hand, else the
/// middle favourite.
enum QuickAdd {
    static let storageKey = "quickAddMl"

    static func amount(last: Int, favorites: [Int]) -> Int {
        if (1...AddWaterSheet.glassMl).contains(last) { return last }
        return favorites.isEmpty ? 250 : favorites[favorites.count / 2]
    }
}

// MARK: - Glass

/// A tumbler, wider at the rim, with water that rises and settles like the
/// real thing and a surface that sways gently (still under Reduce Motion).
private struct FillableGlass: View {
    var fill: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                GlassShape().fill(Palette.backgroundElement)

                GlassWater(level: fill, phase: phase)
                    .fill(LinearGradient(colors: [Palette.accentCyan, Palette.waterSurface, Palette.primaryDark],
                                         startPoint: .top, endPoint: .bottom))
                    .clipShape(GlassShape())

                // Quarter marks, faint, so the scale reads at a glance.
                GeometryReader { proxy in
                    ForEach(1..<4) { mark in
                        Capsule()
                            .fill(.white.opacity(0.55))
                            .frame(width: 14, height: 2)
                            .position(x: proxy.size.width * 0.8,
                                      y: proxy.size.height * (1 - Double(mark) / 4))
                    }
                }

                // A highlight down the left side, like light on glass.
                GlassShape()
                    .inset(by: 0)
                    .stroke(.white, lineWidth: 2.5)
                Capsule()
                    .fill(.white.opacity(0.45))
                    .frame(width: 6)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 18)
            }
            .shadow(color: Palette.primaryDark.opacity(0.10), radius: 10, y: 6)
        }
        .accessibilityHidden(true)
    }
}

/// Wider at the top than at the base, with a softly rounded bottom.
private nonisolated struct GlassShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let taper = r.width * 0.12
        let corner: CGFloat = 18
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - taper, y: r.maxY - corner))
        path.addQuadCurve(to: CGPoint(x: r.maxX - taper - corner, y: r.maxY),
                          control: CGPoint(x: r.maxX - taper, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + taper + corner, y: r.maxY))
        path.addQuadCurve(to: CGPoint(x: r.minX + taper, y: r.maxY - corner),
                          control: CGPoint(x: r.minX + taper, y: r.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> GlassShape {
        GlassShape(insetAmount: insetAmount + amount)
    }
}

/// The water in the glass: animatable level, swaying surface.
private nonisolated struct GlassWater: Shape {
    var level: Double
    var phase: Double

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // A sliver stays at the bottom, the rim stays clear at the top.
        let usable = rect.height * 0.92
        let surface = rect.maxY - max(usable * level, 6)
        let amplitude = level > 0.02 ? 3.0 : 0
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let steps = 24
        for step in 0...steps {
            let x = rect.minX + rect.width * Double(step) / Double(steps)
            let y = surface + amplitude * sin(Double(step) / Double(steps) * .pi * 2 + phase * 2.2)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The little bottle of the favourite amounts, filled in proportion to the
/// amount: a glass sits low, a large bottle near the top.
struct BottleGlyph: View {
    var fill: Double
    var width: CGFloat = 44
    var height: CGFloat = 64

    /// 200 ml about a third full, 500 ml nearly full, never empty nor
    /// overflowing at the ends of the 50–1000 ml range.
    static func fill(forMl ml: Int) -> Double {
        min(max(Double(ml) / 570, 0.12), 0.95)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.sm * height / 64, style: .continuous)
            .fill(Palette.backgroundElement)
            .frame(width: width, height: height)
            .overlay(alignment: .bottom) {
                // A flat surface, rounded only by the bottle's clip: it reads
                // as liquid, not as a block.
                Rectangle()
                    .fill(LinearGradient(colors: [Palette.waterSurface, Palette.primaryDark],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: height * fill)
            }
            .clipShape(.rect(cornerRadius: Radius.sm * height / 64, style: .continuous))
            .accessibilityHidden(true)
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
