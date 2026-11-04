import HydraviaCore
import HydraviaData
import SwiftUI

/// "The phone is the glass": the day's water fills the whole screen behind
/// the UI, tilts with the device, splashes when you add some and floods the
/// screen with bubbles when the goal is reached.
struct HomeView: View {
    @Environment(HydrationStore.self) private var hydration
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(StoreService.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var physics = WaterPhysics()
    @State private var headerFrameGlobal: CGRect = .zero
    @State private var celebrations = 0

    /// The water only runs while it can be seen: home tab selected, app in the
    /// foreground, no unlock ritual covering it. (`onDisappear` doesn't fire
    /// under a full-screen cover, so this can't rely on it.)
    private var isWaterActive: Bool {
        router.tab == .home && scenePhase == .active && !router.isUnlockPresented
    }


    /// 0 % keeps a sliver of water visible at the bottom; 100 % floods the
    /// screen to the very top.
    private static let minimumLevel = 0.13

    private var progress: Double {
        HydrationGoal.progress(consumedMl: hydration.todayTotalMl, goalMl: settings.dailyGoalMl)
    }

    private var waterLevel: Double {
        Self.minimumLevel + progress * (1 - Self.minimumLevel)
    }

    var body: some View {
        ZStack {
            LiveWater(physics: physics, isActive: isWaterActive) { snapshot, geometry, calm in
                waterlineHeader(snapshot: snapshot, geometry: geometry, calm: calm)
            }
            .ignoresSafeArea()

            foreground
        }
        .background(Palette.background)
        .onAppear {
            // The first appearance rises from empty: a quiet "pour" intro.
            physics.setLevel(waterLevel, splash: false)
        }
        .onChange(of: waterLevel) { old, new in
            physics.setLevel(new, splash: new > old && !reduceMotion && isWaterActive)
        }
        .onChange(of: progress) { old, new in
            // Only for water poured while watching — not a goal edited in
            // Settings, or a celebration replaying when the tab comes back.
            guard old < 1, new >= 1, isWaterActive else { return }
            Haptics.celebrate()
            guard !reduceMotion else { return }
            celebrations += 1
            physics.celebrate()
        }
    }

    // MARK: Foreground

    private var foreground: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                // Layout placeholder only: the visible header is drawn in the
                // water layer so it can turn white below the waterline.
                HomeHeaderText(today: hydration.today, tone: .dark)
                    .hidden()
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { headerFrameGlobal = $0 }
                Spacer()
                StreakPill(days: currentStreak)
            }

            Spacer()

            StatsCard(consumedMl: hydration.todayTotalMl, goalMl: settings.dailyGoalMl, celebrations: celebrations)

            Spacer()

            RitualCard(
                isLocked: store.hasLoadedEntitlements && !store.isPremium && !AppConfig.isDevMode,
                notificationsEnabled: settings.settings.notificationsEnabled,
                reminderFired: router.reminderFired,
                window: settings.settings.window,
                onActivate: { router.sheet = .paywall },
                onUnlock: router.presentUnlock
            )

            Button {
                router.sheet = .addWater
            } label: {
                Label { Text(.homeAddWater) } icon: { Image(systemName: "plus").fontWeight(.bold) }
            }
            .buttonStyle(.primaryLight)
            .sensoryFeedback(.impact(weight: .light), trigger: router.sheet == .addWater) { _, new in new }
            .padding(.top, 14)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    private var currentStreak: Int {
        Streak.current(hydration.recentTotals, goalMl: settings.dailyGoalMl, today: hydration.today)
    }

    // MARK: Waterline header

    /// The header drawn twice — dark, then white clipped to the water — so
    /// each glyph turns white exactly as the water covers it, instead of a
    /// global flip that leaves half-submerged text unreadable.
    ///
    /// Most of the day the water is far below the header: then only the dark
    /// copy is drawn and no mask is computed. Fully submerged, the white copy
    /// is drawn unmasked.
    @ViewBuilder
    private func waterlineHeader(snapshot: WaterPhysics.Snapshot, geometry: GeometryProxy, calm: Bool) -> some View {
        // The header's frame in the water's own coordinates (both measured
        // globally, so this holds whatever the safe areas or window).
        let waterOrigin = geometry.frame(in: .global).origin
        let frame = headerFrameGlobal.offsetBy(dx: -waterOrigin.x, dy: -waterOrigin.y)
        let size = geometry.size
        let surface = WaterRenderer.surfaceBounds(snapshot, in: size, calm: calm)
        let header = { (tone: HomeHeaderText.Tone) in
            HomeHeaderText(today: hydration.today, tone: tone)
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        }

        if headerFrameGlobal != .zero {
            ZStack(alignment: .topLeading) {
                if surface.lowerBound >= frame.maxY {
                    header(.dark)
                } else if surface.upperBound <= frame.minY {
                    header(.light)
                } else {
                    header(.dark)
                    header(.light)
                        .mask(WaterlineMask(snapshot: snapshot, canvasSize: size, origin: frame.origin, calm: calm))
                        .accessibilityHidden(true)
                }
            }
            .offset(x: frame.minX, y: frame.minY)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }
}

// MARK: - Header

struct HomeHeaderText: View {
    enum Tone { case dark, light }

    let today: LocalDay
    let tone: Tone

    var body: some View {
        // Single lines that shrink at large Dynamic Type sizes: both copies
        // are laid out in the same frame, so they must wrap identically.
        VStack(alignment: .leading, spacing: 1) {
            Text(.homeTitle)
                .font(.screenTitle)
                .kerning(-0.5)
                .foregroundStyle(tone == .dark ? Palette.textPrimary : .white)
                .accessibilityAddTraits(.isHeader)
            Text(today.startDate(in: .autoupdatingCurrent) ?? .now,
                 format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.brandFootnote)
                .foregroundStyle(tone == .dark ? Palette.textTertiary : .white.opacity(0.72))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

// MARK: - Streak

private struct StreakPill: View {
    let days: Int

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "drop.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.primaryDark)
            Text(days, format: .number)
                .font(.brand(.bold, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText(value: Double(days)))
            Text(days == 1 ? .commonDay : .commonDays)
                .font(.brand(.regular, size: 13, relativeTo: .caption))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassCard(radius: 999, legibility: 0.6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stats

private struct StatsCard: View {
    let consumedMl: Int
    let goalMl: Int
    /// Bumped when the goal is reached: the card swells proudly, then settles.
    let celebrations: Int

    private var over: Int { consumedMl - goalMl }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(consumedMl, format: .number)
                    .font(.displayNumber)
                    .kerning(-1.5)
                    .foregroundStyle(Palette.primaryDark)
                    .contentTransition(.numericText(value: Double(consumedMl)))
                Text("/ \(goalMl.formatted()) \(String(localized: .commonMl))")
                    .font(.brand(.medium, size: 18, relativeTo: .headline))
                    .foregroundStyle(Palette.textSecondary)
            }
            Text(over > 0 ? String(localized: .homeOver(over.formatted()))
                          : String(localized: .homeRemaining((-over).formatted())))
                .font(.brand(.semiBold, size: 13.5, relativeTo: .subheadline))
                .foregroundStyle(over > 0 ? Palette.primaryDark : Palette.textSecondary)
                .contentTransition(.numericText())
        }
        .animation(Motion.count, value: consumedMl)
        .padding(.horizontal, 28)
        .padding(.vertical, Spacing.xl)
        // Denser than the default glass: once the goal is reached this card is
        // fully submerged, and plain glass let the dark water wash out the
        // secondary text.
        .glassCard(radius: Radius.xl, legibility: 0.88)
        .keyframeAnimator(initialValue: 1.0, trigger: celebrations) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.06, duration: 0.35, spring: .bouncy)
            SpringKeyframe(1.0, duration: 0.5, spring: .smooth)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView().injecting(AppDependencies.preview(todayMl: [500, 750]))
}
