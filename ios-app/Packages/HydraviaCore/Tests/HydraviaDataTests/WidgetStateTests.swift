import Foundation
import HydraviaCore
import Testing
@testable import HydraviaData

@Suite("Widgets' shared state and store")
struct WidgetStateTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "hydravia.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private let state = WidgetState(goalMl: 2300, quickAddMl: 330, favoritesMl: [200, 330, 500],
                                    window: UserSettings.defaults.window, remindersOn: true,
                                    isPro: true, proUntil: Date(timeIntervalSince1970: 1_000))

    @Test func survivesTheTripThroughTheAppGroup() {
        let defaults = freshDefaults()
        #expect(WidgetState.load(from: defaults) == nil)
        state.save(to: defaults)
        #expect(WidgetState.load(from: defaults) == state)
    }

    @Test func proEndsWithTheSubscriptionEvenIfTheAppDidntRun() {
        #expect(state.hasPro(at: Date(timeIntervalSince1970: 999)))
        #expect(!state.hasPro(at: Date(timeIntervalSince1970: 1_000)))
        var forever = state
        forever.proUntil = nil
        #expect(forever.hasPro(at: .distantFuture))
        forever.isPro = false
        #expect(!forever.hasPro(at: .now))
    }

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "hydravia-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func theStoreMovesWithItsJournal() throws {
        let dir = try tempDir()
        let old = dir.appending(path: "old/Hydravia.store")
        let new = dir.appending(path: "group/Library/Application Support/Hydravia.store")
        try FileManager.default.createDirectory(at: old.deletingLastPathComponent(), withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            try Data(suffix.utf8).write(to: URL(filePath: old.path(percentEncoded: false) + suffix))
        }
        Persistence.moveStore(from: old, to: new)
        for suffix in ["", "-wal", "-shm"] {
            #expect(!FileManager.default.fileExists(atPath: old.path(percentEncoded: false) + suffix))
            let moved = try Data(contentsOf: URL(filePath: new.path(percentEncoded: false) + suffix))
            #expect(moved == Data(suffix.utf8))
        }
    }

    @Test func anExistingSharedStoreIsNeverOverwritten() throws {
        let dir = try tempDir()
        let old = dir.appending(path: "old.store")
        let new = dir.appending(path: "new.store")
        try Data("old".utf8).write(to: old)
        try Data("new".utf8).write(to: new)
        Persistence.moveStore(from: old, to: new)
        #expect(try Data(contentsOf: new) == Data("new".utf8))
        #expect(FileManager.default.fileExists(atPath: old.path(percentEncoded: false)))
    }
}
