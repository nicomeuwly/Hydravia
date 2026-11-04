import HydraviaData
import SwiftData
import SwiftUI

/// The long-lived objects of the app, built once at launch and injected into
/// the view tree through the environment.
@MainActor
final class AppDependencies {
    let container: ModelContainer
    let hydration: HydrationStore
    let settings: SettingsStore
    let router: AppRouter
    let location: LocationPermission
    let reminders: ReminderService
    let store: StoreService
    let blocker: BlockerService

    init(container: ModelContainer, settings: SettingsStore) {
        self.container = container
        self.hydration = HydrationStore(container: container)
        self.settings = settings
        self.router = AppRouter()
        self.location = LocationPermission()
        // Becomes the notification delegate now, at launch: a reminder tapped
        // while the app was closed is delivered before any view exists.
        self.reminders = ReminderService(router: router)
        // Starts listening for App Store transactions immediately.
        self.store = StoreService(reminders: reminders)
        self.blocker = BlockerService()
    }

    /// The real, on-disk dependencies.
    static func live() throws -> AppDependencies {
        AppDependencies(container: try Persistence.makeContainer(), settings: SettingsStore())
    }

    #if DEBUG
    /// In-memory dependencies for previews, optionally seeded. Each call gets
    /// its own defaults suite so concurrent previews never clobber each other.
    static func preview(onboardingDone: Bool = true, todayMl: [Int] = [250, 500]) -> AppDependencies {
        // swiftlint:disable:next force_unwrapping
        let defaults = UserDefaults(suiteName: "hydravia.preview.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        settings.settings.onboardingDone = onboardingDone

        // A preview that cannot build an in-memory store is a broken toolchain,
        // not a state worth rendering.
        // swiftlint:disable:next force_try
        let dependencies = AppDependencies(container: try! Persistence.makeContainer(inMemory: true), settings: settings)
        for amount in todayMl {
            try? dependencies.hydration.add(amount, source: .manual)
        }
        return dependencies
    }
    #endif
}

extension View {
    /// Injects the app's stores and router. Deliberately not named
    /// `environment(_:)`, which would sit next to SwiftUI's own overload.
    /// The model container is not exposed: every read and write goes through
    /// `HydrationStore`.
    func injecting(_ dependencies: AppDependencies) -> some View {
        self
            .environment(dependencies.hydration)
            .environment(dependencies.settings)
            .environment(dependencies.router)
            .environment(dependencies.location)
            .environment(dependencies.store)
            .environment(dependencies.blocker)
            .environment(\.reminders, dependencies.reminders)
    }
}
