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
    static let termsURL = URL(string: "https://hydravia.app/terms")!
    static let privacyURL = URL(string: "https://hydravia.app/privacy")!
}
