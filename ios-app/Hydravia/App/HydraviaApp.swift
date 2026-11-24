import OSLog
import SwiftUI

@main
struct HydraviaApp: App {
    /// Built once. If the store cannot open there is nothing sensible to run,
    /// so the app shows why instead of crashing or silently losing data.
    @State private var startup: Result<AppDependencies, any Error>

    init() {
        FontRegistry.registerBrandFonts()
        FontRegistry.applyNavigationBarFonts()
        _startup = State(initialValue: Result { try AppDependencies.live() })
    }

    var body: some Scene {
        WindowGroup {
            switch startup {
            case .success(let dependencies):
                RootView()
                    .injecting(dependencies)
            case .failure(let error):
                StartupErrorView(error: error)
            }
        }
    }
}

private struct StartupErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label { Text(.startupErrorTitle) } icon: { Image(systemName: "exclamationmark.triangle") }
        } description: {
            VStack(spacing: Spacing.md) {
                Text(.startupErrorBody)
                // The system's wording, small: useful for a support request.
                Text(verbatim: error.localizedDescription)
                    .font(.brandCaption)
                    .foregroundStyle(Palette.textTertiary)
                    .textSelection(.enabled)
            }
        }
        .onAppear {
            Logger(subsystem: "com.nicomeuwly.hydravia", category: "Startup")
                .fault("Store failed to open: \(error.localizedDescription, privacy: .public)")
        }
    }
}
