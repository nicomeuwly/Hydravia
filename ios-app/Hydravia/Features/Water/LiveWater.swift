import SwiftUI

/// Full-screen animated water, plus an optional overlay that receives the same
/// frame (to draw things that must track the surface, like a waterline mask).
///
/// One `TimelineView` drives everything: the physics is advanced once per
/// display frame and only this subtree redraws. `isActive == false` freezes
/// the frame — no CPU, no sensor. Under Reduce Motion or Low Power Mode the
/// water runs at 30 fps with calmer waves and no tilt.
struct LiveWater<Overlay: View>: View {
    let physics: WaterPhysics
    var style: WaterStyle = .day
    var isActive: Bool
    /// Receives the frame's snapshot, the water's geometry (its coordinate
    /// space is the canvas's) and whether the water is in calm mode.
    @ViewBuilder var overlay: (_ snapshot: WaterPhysics.Snapshot, _ geometry: GeometryProxy, _ calm: Bool) -> Overlay

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var calm: Bool { reduceMotion }
    private var minimumInterval: Double? { reduceMotion || lowPower ? 1.0 / 30 : nil }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: minimumInterval, paused: !isActive)) { timeline in
                let snapshot = physics.snapshot(at: timeline.date)
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in
                        WaterRenderer.draw(snapshot, in: &context, size: size, style: style, calm: calm)
                    }
                    .accessibilityHidden(true)

                    overlay(snapshot, proxy, calm)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .task(id: isActive && !calm) {
            physics.isTiltEnabled = !calm
            guard isActive, !calm else { return }
            for await tilt in DeviceTilt.shared.samples() {
                physics.rollTarget = tilt
            }
        }
    }
}

extension LiveWater where Overlay == EmptyView {
    init(physics: WaterPhysics, style: WaterStyle = .day, isActive: Bool) {
        self.init(physics: physics, style: style, isActive: isActive) { _, _, _ in EmptyView() }
    }
}
