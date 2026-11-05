import SwiftUI

/// Colours of a body of water. `day` is the home screen; `night` is the
/// unlock ritual's darker water.
nonisolated struct WaterStyle: Sendable {
    var surface: Color
    var deep: Color

    static let day = WaterStyle(surface: Palette.waterSurface, deep: Palette.waterDeep)
}

/// Pure drawing of a `WaterPhysics.Snapshot` — no state, so the same frame
/// can be drawn by the canvas and reused as a mask (the header waterline).
nonisolated enum WaterRenderer {
    /// At full tilt (phone on its side) the surface shifts by this fraction of
    /// the height on each side — subtle enough to always read as water.
    static let maxTiltFraction = 0.22
    /// Sample count along the surface: indistinguishable from more at these
    /// amplitudes, and every point is recomputed each frame.
    static let points = 48

    /// Base wave height for a container: 0.7 % of its height, capped at
    /// 5.5 pt. The waves stack to about twice this at their tallest, which
    /// is rare: their crests seldom line up.
    static func waveHeight(for size: CGSize) -> Double {
        min(size.height * 0.007, 5.5)
    }

    /// The surface's ripple displacement at `t` (0 … 1 across), in points.
    /// Catmull-Rom between columns: a straight line from one to the next
    /// would put a corner at every column.
    static func ripple(_ ripples: [Double], at t: Double, scale: Double) -> Double {
        let count = ripples.count
        guard count > 1, scale != 0 else { return 0 }
        let position = min(max(t, 0), 1) * Double(count - 1)
        let i = min(Int(position), count - 2)
        let f = position - Double(i)
        let p0 = ripples[max(i - 1, 0)], p1 = ripples[i]
        let p2 = ripples[i + 1], p3 = ripples[min(i + 2, count - 1)]
        let value = p1 + 0.5 * f * (p2 - p0 + f * (2 * p0 - 5 * p1 + 4 * p2 - p3 + f * (3 * (p1 - p2) + p3 - p0)))
        return value * scale
    }

    /// One travelling wave of the surface: `crests` across the width,
    /// `speed` in crests per second (negative runs leftward), `weight`
    /// relative to the base height.
    private struct Component {
        let crests: Double
        let speed: Double
        let weight: Double
    }

    /// A long swell, a shorter wave running the other way and a small fast
    /// one. Waves crossing each other keep the surface from ever repeating
    /// or looking like a single sine sliding by.
    private static let components = [
        Component(crests: 1.3, speed: 0.05, weight: 1),
        Component(crests: 2.7, speed: -0.09, weight: 0.45),
        Component(crests: 4.6, speed: 0.15, weight: 0.2),
    ]

    /// Crest sharpness (second-order Stokes term): rounded-pointy crests,
    /// wide flat troughs, as real water has, instead of a symmetric sine.
    private static let steepness = 0.22
    private static let peak = components.map(\.weight).reduce(0, +) * (1 + steepness)

    /// The three surfaces, front to back. The back ones are the same water
    /// a few points further away: slightly higher (seen in perspective) and
    /// out of step, so together they read as the depth of one surface,
    /// never as separate hills.
    struct Layer: Sendable {
        /// Points above the front surface.
        let lift: Double
        let tilt: Double
        let ripple: Double
        let seed: Double
        let speed: Double

        static let front = Layer(lift: 0, tilt: 1, ripple: 1, seed: 0, speed: 1)
        static let middle = Layer(lift: 5, tilt: 0.97, ripple: 0.85, seed: 0.37, speed: 0.92)
        static let back = Layer(lift: 10, tilt: 0.94, ripple: 0.7, seed: 0.71, speed: 0.84)
    }

    private static func amplitude(_ snapshot: WaterPhysics.Snapshot, in size: CGSize, calm: Bool) -> Double {
        waveHeight(for: size) * (calm ? 0.5 : 1) * (1 + snapshot.disturbance * 0.4)
    }

    /// The surface's height (y, in points) at `t` (0 … 1 across).
    static func surfaceY(_ snapshot: WaterPhysics.Snapshot, layer: Layer = .front, at t: Double,
                         in size: CGSize, calm: Bool) -> Double {
        let center = size.height * (1 - snapshot.level) - layer.lift
        let tilt = snapshot.roll * size.height * maxTiltFraction * layer.tilt
        let baseline = center + tilt * (1 - 2 * t)
        let amplitude = amplitude(snapshot, in: size, calm: calm)
        var height = 0.0
        for (index, wave) in components.enumerated() {
            let theta = 2 * Double.pi * (t * wave.crests - wave.speed * layer.speed * snapshot.time
                                         + layer.seed * Double(index + 1))
            height += wave.weight * (cos(theta) + steepness * cos(2 * theta))
        }
        let swell = ripple(snapshot.ripples, at: t, scale: waveHeight(for: size) * layer.ripple)
        return baseline - height * amplitude - swell
    }

    /// The water body below one surface.
    static func waterPath(_ snapshot: WaterPhysics.Snapshot, layer: Layer, in size: CGSize, calm: Bool) -> Path {
        var path = Path()
        for i in 0...points {
            let t = Double(i) / Double(points)
            let point = CGPoint(x: size.width * t, y: surfaceY(snapshot, layer: layer, at: t, in: size, calm: calm))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    /// The main (front) surface — also what the header waterline is masked by.
    static func frontPath(_ snapshot: WaterPhysics.Snapshot, in size: CGSize, calm: Bool) -> Path {
        waterPath(snapshot, layer: .front, in: size, calm: calm)
    }

    /// The front surface's height at `t`, for bubbles to know where the air
    /// begins.
    static func frontSurfaceY(_ snapshot: WaterPhysics.Snapshot, at t: Double, in size: CGSize, calm: Bool) -> Double {
        surfaceY(snapshot, at: t, in: size, calm: calm)
    }

    /// Vertical extent the front surface can occupy this frame (top … bottom),
    /// so overlays can skip work when the water is nowhere near them.
    static func surfaceBounds(_ snapshot: WaterPhysics.Snapshot, in size: CGSize, calm: Bool) -> ClosedRange<Double> {
        let center = size.height * (1 - snapshot.level)
        let tilt = abs(snapshot.roll) * size.height * maxTiltFraction
        let waves = amplitude(snapshot, in: size, calm: calm) * peak
        let ripple = (snapshot.ripples.map(abs).max() ?? 0) * waveHeight(for: size)
        return (center - tilt - waves - ripple)...(center + tilt + waves + ripple)
    }

    static func draw(
        _ snapshot: WaterPhysics.Snapshot,
        in context: inout GraphicsContext,
        size: CGSize,
        style: WaterStyle,
        calm: Bool
    ) {
        // The far surfaces first, fainter: a lighter band along the top of
        // the water that thickens and thins as the waves pass.
        context.fill(waterPath(snapshot, layer: .back, in: size, calm: calm),
                     with: .color(style.surface.opacity(0.28)))
        context.fill(waterPath(snapshot, layer: .middle, in: size, calm: calm),
                     with: .color(style.surface.opacity(0.5)))

        // Front layer: the main surface, darkening with depth across the
        // whole screen (so shallow water reads deep, a full screen reads lit).
        let front = frontPath(snapshot, in: size, calm: calm)
        context.fill(front, with: .linearGradient(
            Gradient(colors: [style.surface, style.deep]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)
        ))

        if !calm, !snapshot.ambient.isEmpty {
            drawAmbient(snapshot, in: &context, size: size, calm: calm)
        }

        if let age = snapshot.celebrationAge {
            drawBubbles(snapshot.bubbles, age: age, in: &context, size: size)
        }
    }

    /// Lone bubbles rising under the front surface: flat discs that wobble on
    /// the way up and fade out over the last stretch, popping silently before
    /// the air. Each has its own opacity, so some read further back.
    private static func drawAmbient(_ snapshot: WaterPhysics.Snapshot, in context: inout GraphicsContext, size: CGSize, calm: Bool) {
        let fadeDistance = 46.0

        for bubble in snapshot.ambient {
            let wobble = sin(bubble.age * bubble.wobbleFrequency * 2 * .pi / 2 + bubble.seed) * bubble.wobbleAmplitude
            let x = bubble.x * size.width + wobble
            let y = bubble.y * size.height
            let surface = frontSurfaceY(snapshot, at: x / size.width, in: size, calm: calm)
            let depth = y - surface
            guard depth > 0 else { continue }
            let fadeOut = min(1, depth / fadeDistance)
            let fadeIn = min(1, bubble.age / 0.6)
            let opacity = bubble.opacity * fadeOut * fadeOut * fadeIn
            guard opacity > 0.005 else { continue }

            let d = bubble.size
            let rect = CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
        }
    }

    private static func drawBubbles(_ bubbles: [WaterPhysics.Bubble], age: Double, in context: inout GraphicsContext, size: CGSize) {
        let tinted = Color(red: 122 / 255, green: 208 / 255, blue: 240 / 255).opacity(0.55)
        let plain = Color.white.opacity(0.42)
        let rim = Color.white.opacity(0.35)

        for bubble in bubbles {
            let raw = (age - bubble.delay) / bubble.duration
            guard raw > 0 else { continue }
            let p = 1 - pow(1 - min(1, raw), 2)
            let startY = size.height + 30
            let endY = size.height * bubble.endY
            let y = startY + (endY - startY) * p
            let x = bubble.x * size.width + sin(p * .pi * bubble.wiggles) * bubble.drift
            let scale = p < 0.15 ? 0.4 + (p / 0.15) * 0.6 : 1 + (p - 0.15) / 0.85 * 0.08
            let opacity = p < 0.1 ? p / 0.1 : (p > 0.8 ? (1 - p) / 0.2 : 1)
            let diameter = bubble.size * scale
            let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)

            context.opacity = opacity
            context.fill(Path(ellipseIn: rect), with: .color(bubble.isTinted ? tinted : plain))
            context.stroke(Path(ellipseIn: rect), with: .color(rim), lineWidth: 1)
            context.opacity = 1
        }
    }
}

/// The front water body as a `Shape`, for masking a small view to "below the
/// waterline". The water is computed for the full `canvasSize` and shifted so
/// the masked view (placed at `origin` in canvas coordinates) only pays for
/// its own bounds.
nonisolated struct WaterlineMask: Shape {
    var snapshot: WaterPhysics.Snapshot
    var canvasSize: CGSize
    var origin: CGPoint
    var calm: Bool

    func path(in rect: CGRect) -> Path {
        WaterRenderer.frontPath(snapshot, in: canvasSize, calm: calm)
            .offsetBy(dx: -origin.x, dy: -origin.y)
    }
}
