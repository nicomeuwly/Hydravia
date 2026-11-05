import HydraviaCore
import SwiftUI

/// The ritual's status on the home screen.
///
/// - Locked (free user): "Ritual paused" — the way into the paywall, at the
///   moment the user can see what they're missing.
/// - A reminder fired: "Drink your dose →", the way into the unlock.
/// - Otherwise: when the next reminder fires (dimmed, not tappable).
struct RitualCard: View {
    let isLocked: Bool
    let notificationsEnabled: Bool
    let reminderFired: Bool
    let window: ActiveWindow
    let onActivate: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        if isLocked {
            Button(action: onActivate) {
                row(icon: "sparkles", iconBackground: Palette.primaryDark,
                    caption: Text(.homeRitualPaused), title: Text(.homeRitualUnlock), chevron: true)
            }
            .buttonStyle(.pressable)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text(.homeA11YActivateRitual))
        } else {
            let canOpen = reminderFired || AppConfig.isDevMode
            Button(action: onUnlock) {
                // Re-evaluated every minute so "next reminder" never goes stale.
                TimelineView(.everyMinute) { context in
                    row(
                        icon: notificationsEnabled ? "bell.fill" : "bell.slash.fill",
                        iconBackground: reminderFired ? Palette.primaryDark : Color(hex: 0xB6C2C9),
                        caption: Text(reminderFired ? .homeReminderFired : .homeNextReminder),
                        title: Text(title(now: context.date)),
                        chevron: reminderFired,
                        pulsing: notificationsEnabled && reminderFired
                    )
                }
                // Muted, not faded: this card often floats on dark water, where
                // a translucent card made the caption unreadable.
                .opacity(reminderFired ? 1 : 0.88)
            }
            .buttonStyle(.pressable)
            .disabled(!canOpen)
            // The caption and title are the content ("Next reminder, 14:00",
            // "Reminder fired, Drink your dose"); read them as one element.
            .accessibilityElement(children: .combine)
        }
    }

    private func title(now: Date) -> String {
        if reminderFired { return String(localized: .homeDrinkYourDose) }
        guard notificationsEnabled else { return String(localized: .homeRemindersOff) }
        let calendar = Calendar.autoupdatingCurrent
        switch window.nextReminder(after: MinuteOfDay(now, calendar: calendar)) {
        case .today(let minute):
            return Self.format(minute, calendar: calendar, now: now)
        case .tomorrow(let minute):
            return String(localized: .homeTomorrowAt(Self.format(minute, calendar: calendar, now: now)))
        case .none:
            return "—"
        }
    }

    private static func format(_ minute: MinuteOfDay, calendar: Calendar, now: Date) -> String {
        let date = calendar.date(bySettingHour: minute.hour, minute: minute.minute, second: 0, of: now) ?? now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func row(
        icon: String,
        iconBackground: Color,
        caption: Text,
        title: Text,
        chevron: Bool,
        pulsing: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(iconBackground, in: .rect(cornerRadius: Radius.sm, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if pulsing { PulsingDot().offset(x: -6, y: 6) }
                }

            VStack(alignment: .leading, spacing: 1) {
                caption
                    .font(.brandCaption)
                    .foregroundStyle(Palette.textSecondary)
                title
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, 18)
        .glassCard(radius: Radius.lg, legibility: 0.82)
    }
}

/// The amber "something's waiting" dot: fades out and back, then rests for
/// 1.4 s before the next pulse. Still under Reduce Motion.
private struct PulsingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let dot = Circle().fill(Palette.amber).frame(width: 8, height: 8)
        if reduceMotion {
            dot
        } else {
            dot.phaseAnimator([1.0, 0.15]) { content, opacity in
                content.opacity(opacity)
            } animation: { opacity in
                // Fading out starts after the rest; fading back in doesn't.
                opacity == 0.15 ? .easeInOut(duration: 0.7).delay(1.4) : .easeInOut(duration: 0.7)
            }
        }
    }
}
