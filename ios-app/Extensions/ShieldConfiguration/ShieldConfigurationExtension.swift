import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen a blocked app shows: Hydravia's colours, the device language.
///
/// The class name must match `NSExtensionPrincipalClass` in Info.plist.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    /// The system always draws its own blur behind the shield and only tints
    /// it with `background`. Left to the system, that blur follows the
    /// device's appearance: light mode washed the blue out and left the
    /// white text unreadable. A dark material keeps the shield a deep slate
    /// blue in both modes, so the white text always reads.
    private static let blur = UIBlurEffect.Style.systemThickMaterialDark
    private static let background = UIColor(red: 0.035, green: 0.231, blue: 0.525, alpha: 1)
    /// White text on it stays above 4.5:1 (WCAG AA).
    private static let button = UIColor(red: 0.10, green: 0.42, blue: 0.70, alpha: 1)
    private static let subtitle = UIColor(red: 0.765, green: 0.890, blue: 0.965, alpha: 1)

    private func configuration(name: String?) -> ShieldConfiguration {
        // The system can still show the shield for a moment after an unlock
        // (or a widget pour reaching the goal), while ManagedSettings
        // catches up.
        if Blocker.isOnBreak(at: .now) || !Blocker.shouldShield() {
            return ShieldConfiguration(
                backgroundBlurStyle: Self.blur,
                backgroundColor: Self.background,
                icon: ShieldDrop.image,
                title: .init(text: Blocker.string("shield.tempUnlockTitle"), color: .white),
                subtitle: .init(text: Blocker.string("shield.tempUnlockSubtitle"), color: Self.subtitle),
                primaryButtonLabel: .init(text: Blocker.string("shield.tempUnlockButton"), color: .white),
                primaryButtonBackgroundColor: Self.button,
                secondaryButtonLabel: nil
            )
        }

        let appName = name ?? Blocker.string("shield.thisApp")
        var subtitle = String(format: Blocker.string("shield.subtitle"), appName)
        // Notifications off: "Drink now" can't post the one that opens the
        // ritual, so the way through is opening Hydravia by hand.
        if !Blocker.notificationsUsable { subtitle += "\n\n" + Blocker.string("shield.subtitle.openApp") }
        if let line = Self.progressLine() { subtitle += "\n\n" + line }
        return ShieldConfiguration(
            backgroundBlurStyle: Self.blur,
            backgroundColor: Self.background,
            icon: ShieldDrop.image,
            title: .init(text: Self.title(), color: .white),
            subtitle: .init(text: subtitle, color: Self.subtitle),
            primaryButtonLabel: .init(text: Blocker.string("shield.primaryButton"), color: .white),
            primaryButtonBackgroundColor: Self.button,
            secondaryButtonLabel: .init(text: Blocker.string("shield.secondaryButton"), color: .white)
        )
    }

    /// Changes every hour, so the shield doesn't read the same all day.
    private static func title(at date: Date = .now) -> String {
        let keys = ["shield.title", "shield.title.pause", "shield.title.sip"]
        let hour = Int(date.timeIntervalSinceReferenceDate / 3600)
        return Blocker.string(keys[hour % keys.count])
    }

    /// Today's progress in one line, when the app has shared it today.
    private static func progressLine() -> String? {
        guard let progress = Blocker.progress(), progress.goalMl > 0 else { return nil }
        let remaining = progress.goalMl - progress.consumedMl
        if remaining <= 0 { return Blocker.string("shield.progress.done") }
        if progress.consumedMl == 0 && progress.streak < 2 { return Blocker.string("shield.progress.first") }
        let amount = Blocker.amount(ml: remaining)
        if progress.streak >= 2 {
            return String(format: Blocker.string("shield.progress.streak"), progress.streak, amount)
        }
        return String(format: Blocker.string("shield.progress.remaining"), amount)
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // "Instagram is waiting…" reads right; "Social is waiting…" doesn't.
        configuration(name: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(name: webDomain.domain)
    }
}
