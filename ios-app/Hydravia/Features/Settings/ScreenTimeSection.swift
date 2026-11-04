import FamilyControls
import SwiftUI
import UIKit

/// Settings › Screen Time: the permission, then the apps the lock covers.
struct ScreenTimeSection: View {
    @Environment(BlockerService.self) private var blocker
    @Environment(\.openURL) private var openURL
    @State private var isPicking = false
    @State private var picked = FamilyActivitySelection()
    @State private var showsDenied = false

    var body: some View {
        Section {
            Button(action: access) {
                LabeledContent {
                    Image(systemName: blocker.authorization == .granted ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundStyle(blocker.authorization == .granted ? Palette.success : Palette.textTertiary)
                        .accessibilityLabel(Text(blocker.authorization == .granted
                                                 ? .settingsPermissionGranted : .settingsPermissionNeeded))
                } label: {
                    Text(.settingsAppBlocking)
                    if blocker.authorization != .granted {
                        Text(.settingsPermissionNeeded)
                    }
                }
            }
            .tint(Palette.textPrimary)

            if blocker.authorization == .granted {
                Button {
                    picked = blocker.selection
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
                        }
                    }
                }
                .tint(Palette.textPrimary)
            }
        } header: {
            // The other headers' strings are uppercase already; this one is
            // shared with a sentence-case label.
            Text(.settingsScreenTime).textCase(.uppercase)
        }
        .familyActivityPicker(isPresented: $isPicking, selection: $picked)
        .onChange(of: isPicking) { _, open in
            if !open { blocker.setSelection(picked) }
        }
        .alert(Text(.settingsBlockerDeniedTitle), isPresented: $showsDenied) {
            Button(role: .cancel) {} label: { Text(.commonOk) }
        } message: {
            Text(.settingsBlockerDeniedBody)
        }
    }

    /// Asks once; after that the switch lives in iOS Settings.
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
