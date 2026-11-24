import Foundation
import Testing
@testable import HydraviaData

@Suite("ShieldProgressMirror")
struct ShieldProgressMirrorTests {
    @Test func roundTripsUnderBlockersKey() throws {
        let defaults = try #require(UserDefaults(suiteName: "hydravia.test.\(UUID().uuidString)"))
        let value = ShieldProgressMirror(consumedMl: 1_250, goalMl: 2_300, streak: 4,
                                         day: Date(timeIntervalSince1970: 1_000_000))
        value.save(to: defaults)
        #expect(ShieldProgressMirror.load(from: defaults) == value)
        // The shield extensions read this exact key (`Blocker.Progress`).
        #expect(defaults.data(forKey: "blocker.progress.v1") != nil)
    }

    @Test func decodesTheShieldsFieldNames() throws {
        // What `Blocker.Progress` (Codable, same four fields) writes.
        let json = #"{"consumedMl":500,"goalMl":2000,"streak":2,"day":0}"#
        let value = try JSONDecoder().decode(ShieldProgressMirror.self, from: Data(json.utf8))
        #expect(value.consumedMl == 500)
        #expect(value.goalMl == 2_000)
        #expect(value.streak == 2)
    }
}
