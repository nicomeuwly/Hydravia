import HydraviaCore
import HydraviaData
import StoreKit
import SwiftUI

/// Settings as a native grouped list. Each editable value opens a sheet that
/// edits a draft: Cancel throws it away, Save commits it in one go.
///
struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(HydrationStore.self) private var hydration
    @Environment(AppRouter.self) private var router
    @Environment(\.reminders) private var reminders
    @Environment(StoreService.self) private var store
    @Environment(BlockerService.self) private var blocker
    @State private var managesSubscription = false
    @State private var restoreResult: Bool?
    @State private var isRestoring = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationPermission: ReminderService.Permission = .notDetermined
    /// What the switch shows while the permission round-trip is in flight, so
    /// it doesn't snap back off and flick on again.
    @State private var pendingNotificationsToggle: Bool?

    private enum Editor: String, Identifiable {
        case weight, schedule, interval, favorites
        var id: String { rawValue }
    }

    @State private var editor: Editor?
    @Environment(LocationPermission.self) private var location
    private enum Weather: Equatable { case loading, known(Double), unavailable }
    @State private var weather = Weather.loading
    @State private var confirmDelete = false
    @State private var deleteFailed = false
    @State private var deleted = false

    #if DEBUG
    /// Past days with varied intake, for testing the week pager and for
    /// screenshots. Today is left alone.
    private func seedSampleHistory() {
        let calendar = Calendar.autoupdatingCurrent
        let goal = settings.dailyGoalMl
        for daysAgo in 1...35 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now) else { continue }
            let target = Int(Double(goal) * Double.random(in: 0.45...1.25))
            var poured = 0
            var hour = 8
            while poured < target, hour < 22 {
                let ml = [200, 250, 330, 500].randomElement() ?? 250
                if let time = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...59), second: 0, of: day) {
                    try? hydration.restore(amountMl: ml, createdAt: time, source: .manual)
                }
                poured += ml
                hour += Int.random(in: 1...2)
            }
        }
    }
    #endif

    var body: some View {
        let current = settings.settings

        NavigationStack {
            Form {
                Section {
                    row(.settingsDailyGoal, value: "\(settings.dailyGoalMl.formatted()) \(String(localized: .commonMl))") {
                        editor = .weight
                    }
                    row(.settingsActiveHours, value: "\(current.window.wake.formatted) – \(current.window.sleep.formatted)") {
                        editor = .schedule
                    }
                    row(.settingsReminderInterval,
                        value: ReminderInterval(rawValue: current.window.intervalMin)?.shortLabel ?? "—") {
                        editor = .interval
                    }
                    row(.settingsFavoriteAmounts,
                        value: "\(current.favoriteAmountsMl.map { $0.formatted() }.joined(separator: " · ")) \(String(localized: .commonMl))") {
                        editor = .favorites
                    }
                } header: {
                    Text(.settingsSectionHydration)
                }

                Section {
                    Toggle(isOn: notificationsBinding) {
                        Text(.settingsNotifications)
                        if !notificationsBinding.wrappedValue {
                            Text(.settingsNotificationsDenied)
                        }
                    }
                    .tint(Palette.accentCyan)
                } header: {
                    Text(.settingsSectionReminders)
                }

                ScreenTimeSection()

                Section {
                    // Shows the real permission; flipping it asks once, then
                    // opens iOS Settings, where the switch actually lives.
                    Toggle(isOn: Binding {
                        location.status == .granted
                    } set: { _ in
                        location.requestOrOpenSettings()
                    }) {
                        Text(.settingsLocationAccess)
                        if location.status != .granted {
                            Text(.settingsLocationDenied)
                        }
                    }
                    .tint(Palette.accentCyan)

                    if location.status == .granted {
                        LabeledContent {
                            switch weather {
                            case .loading:
                                ProgressView()
                            case .known(let celsius):
                                // °C or °F per the user's region.
                                Text(Measurement(value: celsius, unit: UnitTemperature.celsius),
                                     format: .measurement(width: .abbreviated, usage: .weather,
                                                          numberFormatStyle: .number.precision(.fractionLength(0))))
                            case .unavailable:
                                Text(verbatim: "—")
                            }
                        } label: {
                            Text(.settingsCurrentWeather)
                        }
                    }
                } header: {
                    Text(.settingsSectionWeather)
                }

                Section {
                    LabeledContent {
                        Text(store.hasLifetime ? .settingsPlanLifetime
                             : store.hasPro ? .settingsPlanPremium : .settingsPlanFree)
                    } label: {
                        Text(.settingsPlan)
                    }
                    if store.hasLifetime {
                        // Bought once: no subscription to manage.
                    } else if store.hasPro {
                        Button { managesSubscription = true } label: {
                            Text(.settingsManageSubscription).foregroundStyle(Palette.textPrimary)
                        }
                    } else {
                        Button { router.sheet = .paywall } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(.settingsGoPremium).foregroundStyle(Palette.primaryDark)
                                Text(.settingsGoPremiumSub)
                                    .font(.brandFootnote)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                        Button {
                            isRestoring = true
                            Task {
                                restoreResult = await store.restore()
                                isRestoring = false
                            }
                        } label: {
                            LabeledContent {
                                if isRestoring { ProgressView() }
                            } label: {
                                Text(.paywallRestore).foregroundStyle(Palette.textPrimary)
                            }
                        }
                        .disabled(isRestoring)
                    }
                } header: {
                    Text(.settingsSectionSubscription)
                }

                Section {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        LabeledContent {
                            Text(.settingsErase).foregroundStyle(Palette.error)
                        } label: {
                            Text(.settingsDeleteHistory).foregroundStyle(Palette.textPrimary)
                        }
                    }
                    // On the row itself, so the popover points at it.
                    .confirmationDialog(Text(.settingsDeleteConfirmTitle), isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button(role: .destructive) {
                            do {
                                try hydration.deleteAll()
                                deleted = true
                            } catch {
                                deleteFailed = true
                            }
                        } label: {
                            Text(.settingsDelete)
                        }
                    } message: {
                        Text(.settingsDeleteConfirmBody)
                    }
                } header: {
                    Text(.settingsSectionData)
                }

                Section {
                    Link(destination: AppConfig.privacyURL) { linkRow(.settingsPrivacyPolicy) }
                    Link(destination: AppConfig.termsURL) { linkRow(.settingsTermsOfUse) }
                    LabeledContent {
                        Text(verbatim: Self.appVersion)
                    } label: {
                        Text(.settingsVersion)
                    }
                } header: {
                    Text(.settingsSectionAbout)
                } footer: {
                    // App Review guideline 1.4.1: the goal is guidance, not medicine.
                    Text(.healthDisclaimer)
                        .font(.brandFootnote)
                        .foregroundStyle(Palette.textSecondary)
                }

                #if DEBUG
                Section("Dev") {
                    Toggle("Simulate the free plan", isOn: Bindable(store).simulatesFreePlan)
                    Button("Simulate a reminder") { router.reminderFired = true }
                    Button("Real reminder in 10 s") { Task { await reminders?.scheduleTestReminder() } }
                    Button("Relock apps now") { blocker.relockNow() }
                    Button("Restart onboarding") { settings.settings.onboardingDone = false }
                    Button("Add 5 weeks of sample history") { seedSampleHistory() }
                }
                #endif
            }
            .font(.bodyRegular)
            .navigationTitle(Text(.settingsTitle))
            .task(id: scenePhase) {
                // Refreshed on return from iOS Settings.
                notificationPermission = await reminders?.permission() ?? .notDetermined
            }
            .task(id: location.status) {
                guard location.status == .granted else { return }
                weather = await WeatherService.shared.currentTemperature().map(Weather.known) ?? .unavailable
            }
            .sheet(item: $editor) { editor in
                switch editor {
                case .weight:
                    DraftSheet(title: .settingsWeightModalTitle, value: current.weightKg, detent: .medium) { draft in
                        VStack(spacing: Spacing.sm) {
                            WeightPicker(weightKg: draft)
                            Text("\(HydrationGoal.dailyMl(weightKg: draft.wrappedValue).formatted()) \(String(localized: .commonMl))")
                                .font(.cardTitle)
                                .foregroundStyle(Palette.primaryDark)
                                .contentTransition(.numericText())
                                .animation(Motion.count, value: draft.wrappedValue)
                            Text(.weightHint)
                                .font(.brandFootnote)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    } onSave: { settings.settings.weightKg = $0 }
                case .schedule:
                    DraftSheet(title: .settingsScheduleModalTitle, value: current.window, detent: .fraction(0.64)) { draft in
                        ActiveWindowEditor(window: draft)
                    } onSave: { settings.settings.window = $0 }
                case .interval:
                    DraftSheet(title: .settingsIntervalModalTitle, value: current.window.intervalMin, detent: .medium) { draft in
                        IntervalPicker(minutes: draft)
                    } onSave: { settings.settings.window.intervalMin = $0 }
                case .favorites:
                    DraftSheet(title: .settingsFavoriteAmounts, value: current.favoriteAmountsMl, detent: .fraction(0.62)) { draft in
                        FavoriteAmountsEditor(amounts: draft)
                    } onSave: { settings.settings.favoriteAmountsMl = $0 }
                }
            }
            .alert(Text(.settingsDeletedTitle), isPresented: $deleted) {
                Button(role: .cancel) {} label: { Text(.commonOk) }
            } message: {
                Text(.settingsDeletedBody)
            }
            .alert(Text(.settingsDeleteHistory), isPresented: $deleteFailed) {
                Button(role: .cancel) {} label: { Text(.commonOk) }
            }
            .sensoryFeedback(.success, trigger: deleted) { _, new in new }
            // Apple's own sheet: change plan, cancel, see renewal date.
            .manageSubscriptionsSheet(isPresented: $managesSubscription)
            .alert(Text(restoreResult == true ? .settingsRestoredTitle : .settingsNoPurchaseTitle),
                   isPresented: Binding { restoreResult != nil } set: { if !$0 { restoreResult = nil } }) {
                Button(role: .cancel) {} label: { Text(.commonOk) }
            } message: {
                Text(restoreResult == true ? .settingsRestoredBody : .settingsNoPurchaseBody)
            }
        }
    }

    /// On only if the user wants reminders AND iOS allows them. Turning it on
    /// asks the first time; once refused, iOS won't ask again, so it opens
    /// the app's page in Settings instead.
    private var notificationsBinding: Binding<Bool> {
        Binding {
            pendingNotificationsToggle ?? (settings.settings.notificationsEnabled && notificationPermission == .granted)
        } set: { wantsOn in
            guard wantsOn else {
                settings.settings.notificationsEnabled = false
                return
            }
            pendingNotificationsToggle = true
            Task {
                defer { pendingNotificationsToggle = nil }
                switch await reminders?.permission() ?? .denied {
                case .granted:
                    settings.settings.notificationsEnabled = true
                case .notDetermined:
                    let granted = await reminders?.requestPermission() ?? false
                    notificationPermission = granted ? .granted : .denied
                    settings.settings.notificationsEnabled = granted
                case .denied:
                    LocationPermission.openSettings()
                }
            }
        }
    }

    private func row(_ label: LocalizedStringResource, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LabeledContent {
                HStack(spacing: Spacing.sm) {
                    Text(value)
                        .foregroundStyle(Palette.textSecondary)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textTertiary)
                }
            } label: {
                Text(label).foregroundStyle(Palette.textPrimary)
            }
        }
    }

    /// A page that opens in Safari.
    private func linkRow(_ label: LocalizedStringResource) -> some View {
        LabeledContent {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
                .accessibilityHidden(true)
        } label: {
            Text(label).foregroundStyle(Palette.textPrimary)
        }
    }

    /// "1.0 (1)": marketing version and build, for support requests.
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// A sheet editing a copy of a value: Cancel discards, Save commits.
private struct DraftSheet<Value: Equatable, Content: View>: View {
    let title: LocalizedStringResource
    @State private var draft: Value
    @State private var confirmDiscard = false
    let detent: PresentationDetent
    @ViewBuilder let content: (Binding<Value>) -> Content
    let onSave: (Value) -> Void
    private let original: Value

    @Environment(\.dismiss) private var dismiss

    init(
        title: LocalizedStringResource,
        value: Value,
        detent: PresentationDetent,
        @ViewBuilder content: @escaping (Binding<Value>) -> Content,
        onSave: @escaping (Value) -> Void
    ) {
        self.title = title
        self._draft = State(initialValue: value)
        self.original = value
        self.detent = detent
        self.content = content
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content($draft)
                    .padding(.horizontal, Spacing.screen)
                    .padding(.vertical, Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Palette.background)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Icon buttons (the iOS 26 toolbar idiom) leave the title room.
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        if draft == original { dismiss() } else { confirmDiscard = true }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text(.commonCancel))
                    .confirmationDialog(Text(.commonCancel), isPresented: $confirmDiscard) {
                        Button(role: .destructive) { dismiss() } label: { Text(.commonCancel) }
                        Button(role: .confirm) {
                            onSave(draft)
                            dismiss()
                        } label: { Text(.commonSave) }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        onSave(draft)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(Text(.commonSave))
                    .disabled(draft == original)
                }
            }
        }
        .presentationDetents([detent])
        .interactiveDismissDisabled(draft != original)
    }
}

#Preview {
    SettingsView().injecting(AppDependencies.preview())
}
