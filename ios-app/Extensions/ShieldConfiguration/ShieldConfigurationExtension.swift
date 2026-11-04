import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen a blocked app shows: Hydravia's colours, the device language.
///
/// The class name must match `NSExtensionPrincipalClass` in Info.plist.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    /// Only tints the system's own blur: it ends up a deep slate blue.
    private static let background = UIColor(red: 0.035, green: 0.231, blue: 0.525, alpha: 1)
    private static let button = UIColor(red: 0.20, green: 0.56, blue: 0.86, alpha: 1)
    private static let subtitle = UIColor(red: 0.765, green: 0.890, blue: 0.965, alpha: 1)

    private func configuration(name: String?) -> ShieldConfiguration {
        // The system can still show the shield for a moment after an unlock,
        // while ManagedSettings catches up.
        if Blocker.isUnlocked(at: .now) {
            return ShieldConfiguration(
                backgroundBlurStyle: nil,
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
        if let line = Self.progressLine() { subtitle += "\n\n" + line }
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
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
        let amount = remaining.formatted()
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
