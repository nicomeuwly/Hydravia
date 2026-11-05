import StoreKit
import SwiftUI

/// Hydravia Pro paywall, in two steps: what you get, then the offer.
///
/// Choices carried over from the Expo app (Mobbin study, July 2026): yearly
/// listed first and preselected, a Blinkist-style trial timeline whose day-5
/// heads-up is a REAL notification, "no commitment" spelled out under the CTA,
/// no fake social proof or urgency. New natively: a returning user who
/// already used their trial is never promised a free week.
struct PaywallView: View {
    enum Source { case onboarding, app }

    let source: Source
    let onFinish: () -> Void

    @Environment(StoreService.self) private var store
    @Environment(\.purchase) private var purchase

    private enum Stage { case intro, offer }
    @State private var stage = Stage.intro
    @State private var selectedID = StoreService.yearlyID
    @State private var isPurchasing = false
    @State private var showsError = false
    @State private var showsPending = false
    @State private var restoreResult: Bool?
    @State private var isRestoring = false
    @State private var isRetrying = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            switch stage {
            case .intro: intro.transition(.opacity)
            case .offer: offer.transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(Motion.slow, value: stage)
        .onAppear {
            // Only promise a trial the App Store confirmed; otherwise (unknown
            // yet, or already used) go straight to the plans.
            if !offersTrial { stage = .offer }
        }
        .onChange(of: store.isEligibleForTrial) { _, eligible in
            if eligible != true { stage = .offer }
        }
        .alert(Text(.paywallSubscribe), isPresented: $showsPending) {
            Button(role: .cancel) { onFinish() } label: { Text(.commonOk) }
        } message: {
            Text(.paywallPending)
        }
        .alert(Text(.paywallErrorTitle), isPresented: $showsError) {
            Button(role: .cancel) {} label: { Text(.commonOk) }
        } message: {
            Text(.paywallErrorBody)
        }
        .alert(Text(restoreResult == true ? .settingsRestoredTitle : .settingsNoPurchaseTitle),
               isPresented: Binding { restoreResult != nil } set: { if !$0 { restoreResult = nil } }) {
            Button(role: .cancel) {
                if restoreResult == true { onFinish() }
            } label: { Text(.commonOk) }
        } message: {
            Text(restoreResult == true ? .settingsRestoredBody : .settingsNoPurchaseBody)
        }
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
          // Scrolls only at large text sizes; the buttons stay on screen.
          ScrollView {
           VStack(alignment: .leading, spacing: Spacing.xxl) {
            brand.padding(.top, Spacing.xxl)

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(.paywallIntroTitle)
                    .font(.brand(.bold, size: 34, relativeTo: .largeTitle))
                    .kerning(-0.8)
                    .foregroundStyle(Palette.textPrimary)
                    // Shrink rather than break "gratuitement" mid-word.
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)
                Text(.paywallIntroSub)
                    .font(.bodyRegular)
                    .foregroundStyle(Palette.textSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.lg) {
                feature(.paywallFeature1, icon: "lock.fill")
                feature(.paywallFeature2, icon: "sun.max.fill")
                feature(.paywallFeature3, icon: "apps.iphone")
            }
           }
           .frame(maxWidth: .infinity, alignment: .leading)
          }
          .scrollBounceBehavior(.basedOnSize)
          .scrollIndicators(.hidden)

            VStack(spacing: Spacing.sm) {
                Button { stage = .offer } label: {
                    Label { Text(.commonContinue) } icon: { Image(systemName: "chevron.right") }
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.primary)
                skipButton
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.lg)
    }

    private func feature(_ text: LocalizedStringResource, icon: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.primaryDark)
                .frame(width: 34, height: 34)
                .background(Palette.backgroundElement, in: .circle)
            Text(text)
                .font(.bodyEmphasis)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    // MARK: Offer

    private var offer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                brand
                Text(offersTrial ? .paywallPlanTitle : .paywallNoTrialTitle)
                    .font(.brand(.bold, size: 30, relativeTo: .largeTitle))
                    .kerning(-0.7)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if offersTrial {
                    TrialTimeline(chargeDate: chargeDate)
                }

                plans

                VStack(spacing: Spacing.sm) {
                    Button(action: buy) {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Label {
                                Text(offersTrial ? .paywallCta : .paywallSubscribe)
                            } icon: { Image(systemName: "chevron.right") }
                                .labelStyle(TrailingIconLabelStyle())
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(isPurchasing || selectedProduct == nil)

                    // What is billed, and when — always visible, not only on
                    // the selected card (App Review requirement).
                    if let billing {
                        Text(billing)
                            .font(.brandFootnote)
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    skipButton
                }

                footer
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.vertical, Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var plans: some View {
        if store.productsFailedToLoad {
            VStack(spacing: Spacing.md) {
                Label { Text(.paywallUnavailable) } icon: { Image(systemName: "wifi.exclamationmark") }
                    .font(.brandFootnote)
                    .foregroundStyle(Palette.textSecondary)
                Button {
                    isRetrying = true
                    Task {
                        await store.loadProducts()
                        isRetrying = false
                    }
                } label: {
                    if isRetrying { ProgressView() } else { Text(.commonRetry) }
                }
                .font(.brand(.semiBold, size: 15, relativeTo: .subheadline))
                .tint(Palette.primaryDark)
                .frame(minHeight: 44)
                .disabled(isRetrying)
            }
            .frame(maxWidth: .infinity)
            .task { await store.loadProducts() }
        } else if let yearly = store.yearly, let monthly = store.monthly {
            VStack(spacing: Spacing.md) {
                PlanCard(
                    title: .paywallPlanYearly,
                    price: yearly.displayPrice,
                    detail: String(localized: .paywallPerMonth(perMonth(yearly))),
                    badge: savings(yearly: yearly, monthly: monthly),
                    isSelected: selectedID == yearly.id
                ) { selectedID = yearly.id }

                PlanCard(
                    title: .paywallPlanMonthly,
                    price: monthly.displayPrice,
                    detail: nil,
                    badge: nil,
                    isSelected: selectedID == monthly.id
                ) { selectedID = monthly.id }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 160)
        }
    }

    private var footer: some View {
        // One line when it fits, stacked otherwise (large text sizes).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.lg) { footerItems(separators: true) }
            VStack(spacing: Spacing.xs) { footerItems(separators: false) }
        }
        .font(.brandCaption)
        .foregroundStyle(Palette.textSecondary)
        .tint(Palette.primaryDark)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func footerItems(separators: Bool) -> some View {
        Link(destination: AppConfig.termsURL) { Text(.paywallTerms) }
            .frame(minHeight: 44)
        if separators { Text(verbatim: "·").accessibilityHidden(true) }
        Link(destination: AppConfig.privacyURL) { Text(.paywallPrivacy) }
            .frame(minHeight: 44)
        if separators { Text(verbatim: "·").accessibilityHidden(true) }
        Button {
            isRestoring = true
            Task {
                restoreResult = await store.restore()
                isRestoring = false
            }
        } label: {
            if isRestoring { ProgressView().controlSize(.small) } else { Text(.paywallRestore) }
        }
        .frame(minHeight: 44)
        .disabled(isRestoring)
    }

    private var skipButton: some View {
        Button(action: onFinish) {
            Text(source == .app ? .paywallSkipApp : .paywallSkipOnboarding)
                .font(.brand(.semiBold, size: 16, relativeTo: .body))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.pressable)
    }

    private var brand: some View {
        HStack(spacing: Spacing.sm) {
            AppLogo(size: 32)
            Text(verbatim: "Hydravia")
                .font(.brand(.bold, size: 18, relativeTo: .headline))
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityHidden(true)
    }

    // MARK: Logic

    private var selectedProduct: Product? {
        selectedID == StoreService.yearlyID ? store.yearly : store.monthly
    }

    /// A trial is promised only when the App Store confirmed it.
    private var offersTrial: Bool { store.isEligibleForTrial == true }

    /// Today + the configured trial period (not a hardcoded week).
    private var chargeDate: Date {
        let calendar = Calendar.autoupdatingCurrent
        guard let period = store.trialPeriod else { return calendar.date(byAdding: .day, value: 7, to: .now) ?? .now }
        let component: Calendar.Component = switch period.unit {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        @unknown default: .day
        }
        return calendar.date(byAdding: component, value: period.value, to: .now) ?? .now
    }

    /// "7 days free, then $17.99 per year. Renews automatically…"
    private var billing: String? {
        guard let product = selectedProduct else { return nil }
        let price = String(localized: product.id == StoreService.yearlyID
                           ? .paywallBilledYearly(product.displayPrice)
                           : .paywallBilledMonthly(product.displayPrice))
        if offersTrial, let period = store.trialPeriod {
            return String(localized: .paywallTrialThen(Self.trialLength(period), price))
        }
        return String(localized: .paywallRenewsAt(price))
    }

    /// "7 jours", "7 days"… StoreKit's own period style reads "un semaine"
    /// in French, so a week is spelled out in days.
    private static func trialLength(_ period: Product.SubscriptionPeriod) -> String {
        var components = DateComponents()
        switch period.unit {
        case .week: components.day = period.value * 7
        case .month: components.month = period.value
        case .year: components.year = period.value
        default: components.day = period.value
        }
        let formatter = DateComponentsFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .month, .year]
        return formatter.string(from: components) ?? ""
    }

    private func perMonth(_ yearly: Product) -> String {
        (yearly.price / 12).formatted(yearly.priceFormatStyle)
    }

    /// "−25 %": what yearly saves over twelve months of monthly.
    private func savings(yearly: Product, monthly: Product) -> String? {
        let fullYear = monthly.price * 12
        guard fullYear > 0 else { return nil }
        let saved = NSDecimalNumber(decimal: 1 - yearly.price / fullYear).doubleValue
        guard saved >= 0.05 else { return nil }
        return "−" + saved.formatted(.percent.precision(.fractionLength(0)))
    }

    private func buy() {
        guard let product = selectedProduct, !isPurchasing else { return }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                let result = try await purchase(product)
                switch await store.complete(result) {
                case .success:
                    // The trial-end heads-up is scheduled by StoreService from
                    // the verified transaction.
                    onFinish()
                case .failed:
                    showsError = true
                case .pending:
                    showsPending = true
                case .cancelled:
                    break
                }
            } catch {
                showsError = true
            }
        }
    }
}

// MARK: - Pieces

private struct PlanCard: View {
    let title: LocalizedStringResource
    let price: String
    let detail: String?
    let badge: String?
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // One row normally; at accessibility sizes the badge and price
                // drop below the title instead of truncating it.
                AnyLayout(stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
                                  : AnyLayout(HStackLayout(alignment: .center))) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? Palette.primaryDark : Palette.textTertiary)
                        .contentTransition(.symbolEffect(.replace))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.cardTitle)
                            .foregroundStyle(Palette.textPrimary)
                        if let detail {
                            Text(detail)
                                .font(.brandFootnote)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    if !stacked { Spacer() }
                    if let badge {
                        Text(badge)
                            .font(.brand(.bold, size: 12, relativeTo: .caption))
                            .foregroundStyle(Palette.amberDeep)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Palette.amber.opacity(0.15), in: .capsule)
                    }
                    Text(price)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                }
            }
            // Both cards span the width, whatever their content.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(.white, in: .rect(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(isSelected ? Palette.primaryDark : Palette.border, lineWidth: isSelected ? 2 : 1)
            }
            .animation(Motion.press, value: isSelected)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Today / day 5 / day 7 — what happens, and when. Risk reduction beats
/// persuasion.
private struct TrialTimeline: View {
    let chargeDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            step(icon: "lock.open.fill", title: .paywallTimelineToday, text: Text(.paywallTimelineTodayText), isLast: false)
            step(icon: "star.fill", title: .paywallTimelineDay7,
                 text: Text(.paywallTimelineDay7Text(chargeDate.formatted(.dateTime.day().month(.wide)))),
                 isLast: true)
        }
    }

    private func step(icon: String, title: LocalizedStringResource, text: Text, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(isLast ? Palette.amber : Palette.primaryDark, in: .circle)
                if !isLast {
                    Rectangle()
                        .fill(Palette.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.brand(.bold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Palette.textPrimary)
                text
                    .font(.brandFootnote)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : Spacing.lg)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Title then icon, for "Continue ›" style buttons.
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}
