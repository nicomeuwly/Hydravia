import SwiftUI

/// The three tabs, on the system Liquid Glass tab bar. Over the home screen's
/// water the bar refracts the waves passing under it — the floating-island
/// look the Expo app built by hand, now native.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            Tab(value: AppRouter.Tab.home) {
                HomeView()
            } label: {
                Label { Text(.tabsHome) } icon: { Image(systemName: "drop.fill") }
            }

            Tab(value: AppRouter.Tab.history) {
                HistoryView()
            } label: {
                Label { Text(.tabsHistory) } icon: { Image(systemName: "chart.bar.fill") }
            }

            Tab(value: AppRouter.Tab.settings) {
                SettingsView()
            } label: {
                Label { Text(.tabsSettings) } icon: { Image(systemName: "gearshape.fill") }
            }
        }
        // Cyan over the home screen's water, where the bar turns dark and a
        // dark tint disappears; a darker blue on the light screens, where
        // cyan is too faint (contrast).
        .tint(router.tab == .home ? Palette.accentCyan : Palette.secondaryBlue)
        .sensoryFeedback(.selection, trigger: router.tab)
        // On Home the bar always floats over the dark water, but the glass
        // guesses its scheme from what's behind it and sometimes stays light
        // (seen on device): dark icons on dark water. SwiftUI's
        // toolbarColorScheme sticks to every tab and greys the bar on the
        // light screens, so the system bar's style is set directly instead.
        .task { await TabBarStyle.apply(dark: router.tab == .home) }
        .onChange(of: router.tab) { _, tab in
            Task { await TabBarStyle.apply(dark: tab == .home) }
        }
        .sheet(item: $router.sheet, onDismiss: router.sheetDidDismiss) { sheet in
            switch sheet {
            case .addWater: AddWaterSheet()
            case .paywall:
                PaywallView(source: .app) { router.sheet = nil }
                    .presentationDetents([.large])
            }
        }
        .fullScreenCover(isPresented: $router.isUnlockPresented) {
            UnlockView()
        }
        // A reminder tapped on cold launch (or while onboarding) is waiting.
        .task { router.consumeReminderUnlockRequest() }
        .onChange(of: router.unlockRequestedByReminder) { _, requested in
            if requested { router.consumeReminderUnlockRequest() }
        }
    }
}

/// Dark on Home, automatic elsewhere, on the UITabBar behind SwiftUI's TabView.
private enum TabBarStyle {
    static func apply(dark: Bool) async {
        // The bar may not exist yet on the very first frame.
        for _ in 0..<10 {
            if let bar = tabBar() {
                bar.overrideUserInterfaceStyle = dark ? .dark : .unspecified
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private static func tabBar() -> UITabBar? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .lazy
            .compactMap { find(in: $0) }
            .first
    }

    private static func find(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar { return bar }
        for subview in view.subviews {
            if let bar = find(in: subview) { return bar }
        }
        return nil
    }
}

#Preview {
    MainTabView().injecting(AppDependencies.preview())
}
