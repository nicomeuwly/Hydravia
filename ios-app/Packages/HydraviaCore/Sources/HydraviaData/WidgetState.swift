import Foundation
import HydraviaCore

/// What the widgets need beyond the water itself, copied by the app into the
/// App Group: the widgets can't read the app's settings or ask the App Store.
///
/// The entries come from the shared store; this is the rest (goal, amounts,
/// schedule, plan).
public struct WidgetState: Codable, Equatable, Sendable {
    public var goalMl: Int
    /// The one-tap amount, the same as the home screen's quick add.
    public var quickAddMl: Int
    public var favoritesMl: [Int]
    public var window: ActiveWindow
    public var remindersOn: Bool
    public var isPro: Bool
    /// When the subscription last seen by the app runs out (plus a renewal
    /// margin). Nil with Pro: no known end (a dev build).
    public var proUntil: Date?

    public init(goalMl: Int, quickAddMl: Int, favoritesMl: [Int], window: ActiveWindow,
                remindersOn: Bool, isPro: Bool, proUntil: Date?) {
        self.goalMl = goalMl
        self.quickAddMl = quickAddMl
        self.favoritesMl = favoritesMl
        self.window = window
        self.remindersOn = remindersOn
        self.isPro = isPro
        self.proUntil = proUntil
    }

    /// Pro at `date`: a subscription that lapsed since the app last ran
    /// locks the Pro widgets again without waiting for the app.
    public func hasPro(at date: Date) -> Bool {
        isPro && (proUntil.map { date < $0 } ?? true)
    }

    /// Before the app first shares anything (a widget added before the app
    /// was ever opened since the update): the defaults of a new user.
    public static let placeholder = WidgetState(
        goalMl: UserSettings.defaults.dailyGoalMl,
        quickAddMl: 250,
        favoritesMl: UserSettings.defaults.favoriteAmountsMl,
        window: UserSettings.defaults.window,
        remindersOn: false,
        isPro: false,
        proUntil: nil
    )

    private static let key = "widget.state.v1"

    public static func load(from defaults: UserDefaults? = UserDefaults(suiteName: Persistence.appGroup)) -> WidgetState? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetState.self, from: data)
    }

    public func save(to defaults: UserDefaults? = UserDefaults(suiteName: Persistence.appGroup)) {
        defaults?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
