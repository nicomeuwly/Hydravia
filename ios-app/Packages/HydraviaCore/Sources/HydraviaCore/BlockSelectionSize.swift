import Foundation

/// What a Screen Time pick holds, counted. The tokens themselves are opaque
/// FamilyControls values that never leave the app target; the rules only
/// need how many of each there are.
///
/// Screen Time shields at most 50 application tokens, 50 web domain tokens
/// and 50 category tokens at once (`ShieldSettings.applications`,
/// `.webDomains`, `.applicationCategories`). Past that the shield is only
/// partly applied, so some picked apps stay free. The picker makes this easy
/// to hit: "All apps & categories" is about a dozen category tokens, but
/// unchecking one app inside a category replaces that category's token with
/// one token per remaining app, and the pick jumps to around a hundred apps.
public struct BlockSelectionSize: Equatable, Sendable {
    public var apps: Int
    public var categories: Int
    public var webDomains: Int

    /// The most tokens of each kind one shield can hold.
    public static let shieldLimit = 50

    public init(apps: Int, categories: Int, webDomains: Int) {
        self.apps = apps
        self.categories = categories
        self.webDomains = webDomains
    }

    /// The kind of token the pick holds too many of.
    public enum Overflow: Equatable, Sendable {
        case apps
        case webDomains
        case categories
    }

    public var isEmpty: Bool { apps == 0 && categories == 0 && webDomains == 0 }

    /// The first kind past `shieldLimit`, apps first (the usual one), or nil
    /// when Screen Time can shield the whole pick exactly.
    public var overflow: Overflow? {
        if apps > Self.shieldLimit { return .apps }
        if webDomains > Self.shieldLimit { return .webDomains }
        if categories > Self.shieldLimit { return .categories }
        return nil
    }

    /// Every app, category and website picked would really be shielded.
    public var isEnforceable: Bool { overflow == nil }
}
