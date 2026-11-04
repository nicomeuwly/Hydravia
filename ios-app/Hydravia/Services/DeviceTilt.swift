import CoreMotion
import Foundation

/// Lateral tilt of the device, shared by every screen that shows water.
///
/// One `CMMotionManager` (Apple's recommendation) fans samples out to any
/// number of subscribers; the sensor starts with the first and stops with the
/// last, so the home screen and the unlock ritual can both listen without
/// silencing each other.
@MainActor
final class DeviceTilt {
    static let shared = DeviceTilt()

    private let manager = CMMotionManager()
    private var subscribers: [UUID: AsyncStream<Double>.Continuation] = [:]
    private static let updateInterval = 1.0 / 30

    /// Tilt samples, -1 (on its left side) … 0 (upright) … 1 (on its right
    /// side), until the consuming task is cancelled. Finishes immediately on
    /// devices without motion (the simulator).
    func samples() -> AsyncStream<Double> {
        let (stream, continuation) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
        guard manager.isDeviceMotionAvailable else {
            continuation.finish()
            return stream
        }
        let id = UUID()
        subscribers[id] = continuation
        continuation.onTermination = { _ in
            Task { @MainActor in DeviceTilt.shared.unsubscribe(id) }
        }
        startIfNeeded()
        return stream
    }

    private func startIfNeeded() {
        guard !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = Self.updateInterval
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let gravity = motion?.gravity else { return }
            // Upright, gravity.x is sin(tilt): asin brings it back to an angle,
            // normalised by 90° — the same scale as the Expo app's gamma/(π/2),
            // so small tilts don't feel 1.5× more twitchy. It also stays calm
            // when the phone lies flat, where x ≈ 0.
            let tilt = asin(max(-1, min(1, gravity.x))) / (.pi / 2)
            MainActor.assumeIsolated {
                DeviceTilt.shared.broadcast(tilt)
            }
        }
    }

    private func broadcast(_ tilt: Double) {
        for continuation in subscribers.values {
            continuation.yield(tilt)
        }
    }

    private func unsubscribe(_ id: UUID) {
        subscribers[id] = nil
        if subscribers.isEmpty {
            manager.stopDeviceMotionUpdates()
        }
    }
}
