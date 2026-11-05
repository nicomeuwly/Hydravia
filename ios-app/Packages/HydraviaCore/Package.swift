// swift-tools-version: 6.2
import PackageDescription

// HydraviaCore is the pure, deterministic engine behind the numbers the whole
// product hinges on (daily goal, unlock dose, reminder slots, streaks).
// It must stay free of SwiftUI, SwiftData, UIKit and any I/O: every function
// takes "now" as a parameter so it can be unit-tested with `swift test` in a
// second, without a simulator. New business rules belong here, not in a view.
//
// HydraviaData is the persistence layer (SwiftData entries, UserDefaults
// settings). It lives here rather than in the app target so it is tested the
// same way — against an in-memory store, on the Mac, in a second.
let package = Package(
    name: "HydraviaCore",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "HydraviaCore", targets: ["HydraviaCore"]),
        .library(name: "HydraviaData", targets: ["HydraviaData"]),
    ],
    targets: [
        .target(name: "HydraviaCore"),
        .target(name: "HydraviaData", dependencies: ["HydraviaCore"]),
        .testTarget(name: "HydraviaCoreTests", dependencies: ["HydraviaCore"]),
        .testTarget(name: "HydraviaDataTests", dependencies: ["HydraviaData"]),
    ],
    swiftLanguageModes: [.v6]
)
