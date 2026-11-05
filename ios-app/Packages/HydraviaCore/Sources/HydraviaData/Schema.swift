import Foundation
import OSLog
import SwiftData

/// Where an entry came from: added by hand, drunk through the unlock
/// ritual, or poured from a home screen widget.
public enum EntrySource: String, Codable, Sendable {
    case manual
    case unlock
    case widget
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
    /// Shared by the app and every extension (Screen Time, widgets). The
    /// name predates the widgets; it can't change without losing the data
    /// already in it.
    public static let appGroup = "group.com.nicomeuwly.hydravia.blocker"

    /// Where the store lives: in the App Group, so the widgets read the same
    /// history and their buttons add to it.
    static func sharedConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration("Hydravia", schema: schema, groupContainer: .identifier(appGroup))
    }

    /// Where the store lived before the widgets: the app's own container.
    static func legacyConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration("Hydravia", schema: schema, groupContainer: .none)
    }

    /// The app's model container. `inMemory` is for tests and previews.
    ///
    /// The first launch after the widgets arrived moves the history from the
    /// app's container into the App Group, before anything opens it.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: HydraviaSchemaV1.self)
        guard !inMemory else {
            return try ModelContainer(
                for: schema,
                migrationPlan: HydraviaMigrationPlan.self,
                configurations: ModelConfiguration("Hydravia", schema: schema, isStoredInMemoryOnly: true)
            )
        }
        // Without the App Group (a Mac test run) the shared location falls
        // back to the app's own: nothing to move.
        let shared = sharedConfiguration(schema: schema)
        let legacy = legacyConfiguration(schema: schema)
        if shared.url != legacy.url {
            moveStore(from: legacy.url, to: shared.url)
        }
        return try ModelContainer(for: schema, migrationPlan: HydraviaMigrationPlan.self, configurations: shared)
    }

    /// The container for an extension, or nil while the app hasn't created
    /// (or moved) the store yet: an extension must never create it, or the
    /// app would find a store in place and leave the history behind.
    public static func makeExtensionContainer() -> ModelContainer? {
        let schema = Schema(versionedSchema: HydraviaSchemaV1.self)
        let shared = sharedConfiguration(schema: schema)
        guard FileManager.default.fileExists(atPath: shared.url.path(percentEncoded: false)) else { return nil }
        return try? ModelContainer(for: schema, migrationPlan: HydraviaMigrationPlan.self, configurations: shared)
    }

    /// Moves a SQLite store (and its `-wal` / `-shm` companions, which hold
    /// recent writes) unless the destination already has one. Never
    /// overwrites: a failure leaves the old store where it was, read again
    /// on the next launch.
    static func moveStore(from old: URL, to new: URL, fileManager: FileManager = .default) {
        let oldPath = old.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: oldPath),
              !fileManager.fileExists(atPath: new.path(percentEncoded: false))
        else { return }
        do {
            try fileManager.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Companions first: the main file appearing is what marks the
            // move as done.
            for suffix in ["-wal", "-shm"] {
                let from = URL(filePath: oldPath + suffix)
                guard fileManager.fileExists(atPath: from.path(percentEncoded: false)) else { continue }
                try fileManager.moveItem(at: from, to: URL(filePath: new.path(percentEncoded: false) + suffix))
            }
            try fileManager.moveItem(at: old, to: new)
        } catch {
            Logger(subsystem: "com.nicomeuwly.hydravia", category: "Persistence")
                .error("Store move failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
