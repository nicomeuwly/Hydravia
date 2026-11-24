import SwiftUI

extension View {
    /// The answer to an explicit "Restore": restored, nothing on this Apple
    /// Account, or the App Store couldn't be reached (offline, sign-in
    /// cancelled). Worded for every plan, lifetime included.
    func restoreAlert(_ outcome: Binding<StoreService.RestoreOutcome?>,
                      onRestored: @escaping () -> Void = {}) -> some View {
        let shown = outcome.wrappedValue
        return alert(Text(Self.restoreTitle(shown)),
                     isPresented: Binding { outcome.wrappedValue != nil } set: { if !$0 { outcome.wrappedValue = nil } }) {
            Button(role: .cancel) {
                if shown == .restored { onRestored() }
            } label: { Text(.commonOk) }
        } message: {
            Text(Self.restoreBody(shown))
        }
    }

    private static func restoreTitle(_ outcome: StoreService.RestoreOutcome?) -> LocalizedStringResource {
        switch outcome {
        case .restored: .settingsRestoredTitle
        case .failed: .settingsRestoreFailedTitle
        case .nothingFound, nil: .settingsNoPurchaseTitle
        }
    }

    private static func restoreBody(_ outcome: StoreService.RestoreOutcome?) -> LocalizedStringResource {
        switch outcome {
        case .restored: .settingsRestoredBody
        case .failed: .settingsRestoreFailedBody
        case .nothingFound, nil: .settingsNoPurchaseBody
        }
    }
}
