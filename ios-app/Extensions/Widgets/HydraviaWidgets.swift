import SwiftUI
import WidgetKit

/// Hydravia's widgets. The progress widget is free; adding water from a
/// widget and the Lock Screen widgets are Hydravia Pro.
@main
struct HydraviaWidgets: WidgetBundle {
    var body: some Widget {
        ProgressWidget()
        QuickAddWidget()
        LockScreenWidget()
    }
}

/// Opens the app on the paywall: where a locked Pro widget leads.
enum WidgetLink {
    static let paywall = URL(string: "hydravia://paywall")!
}
