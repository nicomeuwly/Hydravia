import Foundation

/// Build-time switches.
enum AppConfig {
    /// Dev escape hatches (open the unlock ritual without a reminder, skip the
    /// paywall gate). Compiled out of Release, so it can never ship enabled.
    #if DEBUG
    static let isDevMode = true
    #else
    static let isDevMode = false
    #endif

    /// Dev builds count as Pro, unless the dev section asks to try the free
    /// plan.
    static let simulatesFreePlanKey = "dev.simulatesFreePlan"

    /// Legal pages on the landing site (also given to App Store Connect).
    /// French pages at the root, English ones (for every other language)
    /// under /en, following the language the app is shown in.
    static var termsURL: URL { legalURL("terms") }
    static var privacyURL: URL { legalURL("privacy") }

    private static var showsFrench: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("fr") == true
    }

    private static func legalURL(_ page: String) -> URL {
        URL(string: "https://www.hydravia.app/\(showsFrench ? "" : "en/")\(page)")!
    }
}
