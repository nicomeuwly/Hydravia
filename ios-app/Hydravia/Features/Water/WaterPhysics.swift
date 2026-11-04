import Foundation

/// The water's state over time: level, tilt, splash, waves and the
/// goal-reached bubbles.
///
/// Deliberately NOT observable: it is advanced once per display frame by the
/// `TimelineView` that draws it, and views read a value `Snapshot`. Routing
/// 120 updates a second through Observation would re-render every view that
/// touches it; this way only the canvas redraws.
///
/// Time is an internal clock that only advances while the water is on screen
/// (frame deltas are capped), so pausing and resuming never makes the waves
/// jump sideways.
@MainActor
final class WaterPhysics {
    // MARK: Tuning — same values as the Expo engine it replaces.

    /// Seconds per lap of the front / back wave.
    static let frontPeriod = 9.0
    static let backPeriod = 11.5
    /// The level eases to a new value over this long (ease-out cubic).
    static let levelDuration = 1.1
    /// A splash surges for `splashRise` then decays for `splashFall`.
    static let splashRise = 0.16
    static let splashFall = 1.5
    /// Underdamped on purpose: the surface overshoots and sloshes when the
    /// device stops moving, like water settling in a glass.
    static let tiltStiffness = 120.0
    static let tiltDamping = 11.0
    static let celebrationDuration = 2.5

    /// Largest frame step integrated at once: after a hitch or a pause, the
    /// water simply resumes instead of fast-forwarding.
    private static let maxFrameStep = 1.0 / 20
    private static let springSubstep = 1.0 / 240

    nonisolated struct Snapshot: Sendable {
        var level: Double
        /// Normalised lateral tilt, -1 (left) … 1 (right).
        var roll: Double
        /// 0 … 1 surge applied to the wave amplitude after an addition.
        var disturbance: Double
        var frontPhase: Double
        var backPhase: Double
        var bubbles: [Bubble]
        var celebrationAge: Double?
    }

    nonisolated struct Bubble: Sendable {
        var x: Double
        var size: Double
        var delay: Double
        var duration: Double
        var drift: Double
        var wiggles: Double
        var endY: Double
        var isTinted: Bool

        static func random() -> Bubble {
            Bubble(
                x: .random(in: 0.04...0.96),
                size: .random(in: 6...20),
                delay: .random(in: 0...0.55),
                duration: .random(in: 1.2...1.75),
                drift: .random(in: 6...24),
                wiggles: .random(in: 1.5...3.5),
                endY: .random(in: 0.06...0.36),
                isTinted: Double.random(in: 0...1) < 0.3
            )
        }
    }

    // MARK: State

    /// Desired tilt, fed by the motion sensor (or 0 when tilt is off).
    var rollTarget = 0.0
    var isTiltEnabled = true

    private var clock = 0.0
    private var lastDate: Date?
    private var cached: Snapshot?

    private var levelFrom = 0.0
    private var levelTo = 0.0
    private var levelStart = -Double.infinity
    private var splashStart: Double?
    /// Disturbance at the moment the current splash began, so a second pour
    /// during the decay surges up from there instead of popping down to 0.
    private var splashFrom = 0.0
    private var roll = 0.0
    private var rollVelocity = 0.0
    private var bubbles: [Bubble] = []
    private var celebrationStart: Double?

    // MARK: Commands

    /// Moves the water to `level` (0 … 1). `splash` adds the surge, for water
    /// that was just poured in.
    func setLevel(_ level: Double, splash: Bool) {
        let target = min(1, max(0, level))
        let current = currentLevel(at: clock)
        guard abs(target - levelTo) > 0.0001 else { return }
        levelFrom = current
        levelTo = target
        levelStart = clock
        if splash, target > current {
            splashFrom = disturbance(at: clock)
            splashStart = clock
        }
    }

    /// Releases a swarm of bubbles rising to the surface — the water-native
    /// take on confetti.
    func celebrate() {
        bubbles = (0..<26).map { _ in .random() }
        celebrationStart = clock
    }

    // MARK: Frame

    /// The state at `date`. Idempotent for a given date, so several readers in
    /// the same frame share one integration step.
    func snapshot(at date: Date) -> Snapshot {
        if let cached, date == lastDate { return cached }
        let delta = lastDate.map { min(Self.maxFrameStep, max(0, date.timeIntervalSince($0))) } ?? 0
        lastDate = date
        advance(by: delta)

        var celebrationAge: Double?
        if let start = celebrationStart {
            let age = clock - start
            if age < Self.celebrationDuration {
                celebrationAge = age
            } else {
                celebrationStart = nil
                bubbles = []
            }
        }

        let snapshot = Snapshot(
            level: currentLevel(at: clock),
            roll: roll,
            disturbance: disturbance(at: clock),
            frontPhase: (clock / Self.frontPeriod).truncatingRemainder(dividingBy: 1),
            backPhase: (clock / Self.backPeriod).truncatingRemainder(dividingBy: 1),
            bubbles: bubbles,
            celebrationAge: celebrationAge
        )
        cached = snapshot
        return snapshot
    }

    private func advance(by delta: Double) {
        clock += delta
        // Semi-implicit Euler in fixed substeps: stable for this spring at any
        // frame rate, and cheap (≤ 12 steps per frame).
        let target = isTiltEnabled ? rollTarget : 0
        var remaining = delta
        while remaining > 0 {
            let step = min(Self.springSubstep, remaining)
            let acceleration = -Self.tiltStiffness * (roll - target) - Self.tiltDamping * rollVelocity
            rollVelocity += acceleration * step
            roll += rollVelocity * step
            remaining -= step
        }
    }

    private func currentLevel(at time: Double) -> Double {
        let progress = min(1, max(0, (time - levelStart) / Self.levelDuration))
        let eased = 1 - pow(1 - progress, 3)
        return levelFrom + (levelTo - levelFrom) * eased
    }

    private func disturbance(at time: Double) -> Double {
        guard let start = splashStart else { return 0 }
        let age = time - start
        if age < Self.splashRise {
            let p = age / Self.splashRise
            return splashFrom + (1 - splashFrom) * (1 - (1 - p) * (1 - p))
        }
        let p = (age - Self.splashRise) / Self.splashFall
        if p >= 1 {
            splashStart = nil
            return 0
        }
        return pow(1 - p, 3)
    }
}
