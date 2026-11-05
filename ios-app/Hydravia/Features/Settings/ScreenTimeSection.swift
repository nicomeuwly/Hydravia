import FamilyControls
import SwiftUI
import UIKit

/// Settings › Screen Time: the permission, then the apps the lock covers.
struct ScreenTimeSection: View {
    @Environment(BlockerService.self) private var blocker
    @Environment(\.openURL) private var openURL
    @State private var isPicking = false
    @State private var showsDenied = false

    var body: some View {
        Section {
            // Same shape as the notifications switch: it shows the real
            // permission, and flipping it asks iOS (or revokes).
            Toggle(isOn: accessBinding) {
                Text(.settingsAppBlocking)
                if blocker.authorization != .granted {
                    Text(.settingsPermissionNeeded)
                }
            }
            .tint(Palette.accentCyan)

            if blocker.authorization == .granted {
                Button {
                    isPicking = true
                } label: {
                    LabeledContent {
                        if blocker.selectionCount == 0 {
                            Text(.settingsChooseApps).foregroundStyle(Palette.primaryDark)
                        } else {
                            Text(blocker.selectionCount, format: .number)
                        }
                    } label: {
                        Text(.settingsBlockedApps)
                        if blocker.selectionCount == 0 {
                            Text(.settingsNoAppsSelected)
                        } else if blocker.needsAppChoice {
                            Text(.blockerFreeLimitTitle)
                        }
                    }
                }
                .tint(Palette.textPrimary)
            }
        } header: {
            // The other headers' strings are uppercase already; this one is
            // shared with a sentence-case label.
            Text(.settingsScreenTime).textCase(.uppercase)
        } footer: {
            if blocker.authorization == .granted && !blocker.isPro {
                Text(.settingsBlockedAppsFreeFooter)
            }
        }
        .blockedAppsPicker(isPresented: $isPicking)
        .alert(Text(.settingsBlockerDeniedTitle), isPresented: $showsDenied) {
            Button(role: .cancel) {} label: { Text(.commonOk) }
        } message: {
            Text(.settingsBlockerDeniedBody)
        }
    }

    private var accessBinding: Binding<Bool> {
        Binding {
            blocker.authorization == .granted
        } set: { wantsOn in
            if wantsOn {
                access()
            } else {
                Task { await blocker.revokeAuthorization() }
            }
        }
    }

    /// Asks for Screen Time access (Face ID / passcode prompt).
    private func access() {
        switch blocker.authorization {
        case .notDetermined:
            Task {
                if await !blocker.requestAuthorization() { showsDenied = true }
            }
        case .granted:
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        case .denied:
            showsDenied = true
        }
    }
}
