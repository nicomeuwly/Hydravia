import AppIntents
import HydraviaData
import SwiftData
import WidgetKit

/// A widget button's pour: logs the water straight into the shared store,
/// without opening the app. Hydravia Pro.
struct AddWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "widget.intent.title"
    static let isDiscoverable = false

    @Parameter(title: "widget.intent.amount")
    var amountMl: Int

    init() {}

    init(amountMl: Int) {
        self.amountMl = amountMl
    }

    func perform() async throws -> some IntentResult {
        let state = WidgetState.load() ?? .placeholder
        guard state.hasPro(at: .now), (1...2000).contains(amountMl),
              let container = Persistence.makeExtensionContainer()
        else { return .result() }
        let context = ModelContext(container)
        context.insert(WaterEntry(amountMl: amountMl, createdAt: .now, source: .widget))
        try context.save()
        // Every widget shows today's total, not just the one tapped. Only the
        // tapped one is sure to reload now; the rest is a request iOS may
        // postpone (the timelines' refresh interval catches up).
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
