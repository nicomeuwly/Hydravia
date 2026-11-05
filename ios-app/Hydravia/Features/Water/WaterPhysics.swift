import Foundation

/// The water's state over time: level, tilt, splash, three wave layers, a
/// surface that ripples (tilt and pours send waves that bounce off the
/// sides), a few ambient bubbles, and the goal-reached swarm.
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

    /// Seconds per lap of the front / middle / back wave: three speeds, so
    /// the layers drift against each other.
    static let frontPeriod = 9.0
    static let middlePeriod = 6.8
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

    // Ripples: a 1D wave equation across the surface, in units of the base
    // wave height. Reflective ends, so a slosh runs to the side, bounces and
    // comes back, losing a little each time.
    static let rippleColumns = 32
    /// Wave speed, in screen widths per second.
    private static let rippleSpeed = 0.75
    private static let rippleDamping = 1.4
    /// How hard a change of tilt pushes the water toward one side.
    private static let tiltForcing = 0.018
    private static let rippleLimit = 2.6

    // Ambient bubbles: a handful, never a fizz.
    private static let ambientRange = 3...6

    nonisolated struct Snapshot: Sendable {
        var level: Double
        /// Normalised lateral tilt, -1 (left) … 1 (right).
        var roll: Double
        /// 0 … 1 surge applied to the wave amplitude after an addition.
        var disturbance: Double
        var frontPhase: Double
        var middlePhase: Double
        var backPhase: Double
        /// Surface displacement per column, left to right, in base wave heights.
        var ripples: [Double]
        var ambient: [AmbientBubble]
        var bubbles: [Bubble]
        var celebrationAge: Double?
    }

    /// A lone bubble rising through the water. Position is normalised to the
    /// canvas (y: 0 top, 1 bottom); the renderer adds the wobble in points and
    /// fades it out just under the surface.
    nonisolated struct AmbientBubble: Sendable {
        var x: Double
        var y: Double
        var size: Double
        /// Rise speed, canvas heights per second (bigger bubbles rise faster).
        var speed: Double
        var wobbleAmplitude: Double
        var wobbleFrequency: Double
        var seed: Double
        var age: Double

        static func random(startY: Double = 1.03) -> AmbientBubble {
            let size = Double.random(in: 3...11)
            return AmbientBubble(
                x: .random(in: 0.06...0.94),
                y: startY,
                size: size,
                speed: 0.035 + size * 0.006 + .random(in: 0...0.02),
                wobbleAmplitude: .random(in: 2...7),
                wobbleFrequency: .random(in: 1.2...2.6),
                seed: .random(in: 0...(2 * .pi)),
                age: 0
            )
        }
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
    /// Ripples and ambient bubbles; off under Reduce Motion / Low Power.
    var isAmbientEnabled = true

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
    private var rippleHeight = [Double](repeating: 0, count: rippleColumns)
    private var rippleVelocity = [Double](repeating: 0, count: rippleColumns)
    private var ambient: [AmbientBubble] = []
    /// Seconds until the next ambient bubble may appear.
    private var nextBubbleIn = 0.6
    private var ambientTarget = Int.random(in: ambientRange)

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
            if isAmbientEnabled { kick(at: .random(in: 0.2...0.8), strength: 2.2) }
        }
    }

    /// Drops a bump into the surface at `x` (0 … 1): it spreads both ways and
    /// bounces off the sides.
    private func kick(at x: Double, strength: Double) {
        let columns = Self.rippleColumns
        for i in 0..<columns {
            let d = (Double(i) / Double(columns - 1) - x) / 0.08
            rippleVelocity[i] -= strength * 6 * exp(-d * d)
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
            middlePhase: (clock / Self.middlePeriod).truncatingRemainder(dividingBy: 1),
            backPhase: (clock / Self.backPeriod).truncatingRemainder(dividingBy: 1),
            ripples: rippleHeight,
            ambient: ambient,
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
            if isAmbientEnabled {
                stepRipples(step, tiltAcceleration: acceleration)
            }
            remaining -= step
        }
        if isAmbientEnabled {
            advanceAmbient(by: delta)
        } else if !ambient.isEmpty || rippleHeight.contains(where: { $0 != 0 }) {
            ambient = []
            rippleHeight = .init(repeating: 0, count: Self.rippleColumns)
            rippleVelocity = .init(repeating: 0, count: Self.rippleColumns)
        }
    }

    /// One step of the damped wave equation. A change of tilt pushes the
    /// water toward the low side (forcing grows with distance from the
    /// centre), so a quick tilt sends a slosh across that reflects back.
    private func stepRipples(_ step: Double, tiltAcceleration: Double) {
        let columns = Self.rippleColumns
        let dx = 1.0 / Double(columns - 1)
        let c2 = Self.rippleSpeed * Self.rippleSpeed / (dx * dx)
        let force = tiltAcceleration * Self.tiltForcing
        for i in 0..<columns {
            // Mirrored neighbours at the ends: the sides reflect.
            let left = rippleHeight[i == 0 ? 1 : i - 1]
            let right = rippleHeight[i == columns - 1 ? columns - 2 : i + 1]
            let laplacian = left + right - 2 * rippleHeight[i]
            let lateral = Double(i) / Double(columns - 1) - 0.5
            rippleVelocity[i] += (c2 * laplacian - Self.rippleDamping * rippleVelocity[i] + force * lateral * 60) * step
        }
        // Volume stays put: the surface tilts and ripples but never rises
        // as a whole (that's the level's job).
        let mean = rippleVelocity.reduce(0, +) / Double(columns)
        for i in 0..<columns {
            rippleHeight[i] += (rippleVelocity[i] - mean) * step
            rippleHeight[i] = min(max(rippleHeight[i], -Self.rippleLimit), Self.rippleLimit)
        }
    }

    private func advanceAmbient(by delta: Double) {
        let surface = 1 - currentLevel(at: clock)
        for i in ambient.indices {
            ambient[i].age += delta
            ambient[i].y -= ambient[i].speed * delta
        }
        // Gone once well past the surface (the renderer has faded it by then).
        ambient.removeAll { $0.y < surface - 0.04 }

        nextBubbleIn -= delta
        // No room to rise in a nearly empty glass.
        guard nextBubbleIn <= 0, surface < 0.9 else { return }
        if ambient.count < ambientTarget {
            // The first few start part-way up, so the water is never empty
            // for long after it appears.
            let startY = ambient.isEmpty && clock < 3 ? Double.random(in: max(surface + 0.1, 0.5)...1.0) : 1.03
            ambient.append(.random(startY: startY))
        } else {
            ambientTarget = Int.random(in: Self.ambientRange)
        }
        nextBubbleIn = .random(in: 0.7...2.8)
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
