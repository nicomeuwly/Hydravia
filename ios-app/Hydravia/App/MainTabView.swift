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
        // Cyan, not the dark brand blue: the bar turns dark over the home screen's
        // water, where a dark selected tint disappeared.
        .tint(Palette.accentCyan)
        .sensoryFeedback(.selection, trigger: router.tab)
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

#Preview {
    MainTabView().injecting(AppDependencies.preview())
}
