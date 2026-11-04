import Foundation
import SwiftData

/// Where an entry came from: added by hand, or drunk through the unlock ritual.
public enum EntrySource: String, Codable, Sendable {
    case manual
    case unlock
}

/// Version 1 of the on-disk schema.
///
/// Models live inside a `VersionedSchema` from day one so the first real
/// change becomes a new `SchemaV2` plus a migration stage — never an edit to a
/// model that already shipped (the SwiftData equivalent of the Expo app's
/// append-only MIGRATIONS array).
public enum HydraviaSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] { [WaterEntry.self] }

    @Model
    public final class WaterEntry {
        #Index<WaterEntry>([\.createdAt])

        public var amountMl: Int
        public var createdAt: Date
        /// Stored raw so adding a source later never breaks decoding.
        public var sourceRaw: String

        public var source: EntrySource {
            get { EntrySource(rawValue: sourceRaw) ?? .manual }
            set { sourceRaw = newValue.rawValue }
        }

        public init(amountMl: Int, createdAt: Date, source: EntrySource) {
            self.amountMl = amountMl
            self.createdAt = createdAt
            self.sourceRaw = source.rawValue
        }
    }
}

public typealias WaterEntry = HydraviaSchemaV1.WaterEntry

public enum HydraviaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [HydraviaSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum Persistence {
    /// The app's model container. `inMemory` is for tests and previews.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: HydraviaSchemaV1.self)
        // Explicitly NOT in the App Group container. With `.automatic`, adding
        // the App Group entitlement (Screen Time, phase 7) would silently move
        // the store and every user's history would appear to vanish. Nothing
        // outside the app reads entries today; if a widget ever needs them,
        // move the file deliberately, with a migration.
        let configuration = ModelConfiguration(
            "Hydravia",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: HydraviaMigrationPlan.self,
            configurations: configuration
        )
    }
}
