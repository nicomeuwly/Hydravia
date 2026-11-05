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

    /// Base wave height for a container: 3 % of its height, capped at 14 pt.
    static func waveHeight(for size: CGSize) -> Double {
        min(size.height * 0.03, 14)
    }

    /// The surface's ripple displacement at `t` (0 … 1 across), in points.
    static func ripple(_ ripples: [Double], at t: Double, scale: Double) -> Double {
        guard ripples.count > 1, scale != 0 else { return 0 }
        let position = min(max(t, 0), 1) * Double(ripples.count - 1)
        let index = min(Int(position), ripples.count - 2)
        let fraction = position - Double(index)
        return (ripples[index] + (ripples[index + 1] - ripples[index]) * fraction) * scale
    }

    /// The water body below a travelling, tilted wave surface.
    ///
    /// The surface is a diagonal baseline — higher on the side the device
    /// tilts toward, like water in a tilted glass — with the waves added on
    /// top: a main sine (`cycles` crests across), a faint faster harmonic so
    /// crests don't look machined, and the ripples sloshing back and forth.
    static func waterPath(
        in size: CGSize,
        level: Double,
        amplitude: Double,
        phase: Double,
        roll: Double,
        phaseShift: Double = 0,
        cycles: Double = 1,
        ripples: [Double] = [],
        rippleScale: Double = 0
    ) -> Path {
        let width = size.width
        let height = size.height
        let center = height * (1 - level)
        let tilt = roll * height * maxTiltFraction
        let yLeft = center + tilt
        let yRight = center - tilt

        var path = Path()
        for i in 0...points {
            let t = Double(i) / Double(points)
            let x = width * t
            let baseline = yLeft + (yRight - yLeft) * t
            let swell = sin((t * cycles + phase + phaseShift) * 2 * .pi)
            let chop = sin((t * cycles * 2.3 + phase * 2 + phaseShift + 0.3) * 2 * .pi) * 0.18
            let y = baseline + (swell + chop) * amplitude - ripple(ripples, at: t, scale: rippleScale)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }

    /// The main (front) surface — also what the header waterline is masked by.
    static func frontPath(_ snapshot: WaterPhysics.Snapshot, in size: CGSize, calm: Bool) -> Path {
        let amplitude = waveHeight(for: size) * (calm ? 0.5 : 1) * (1 + snapshot.disturbance * 2.2)
        return waterPath(in: size, level: snapshot.level, amplitude: amplitude,
                         phase: snapshot.frontPhase, roll: snapshot.roll,
                         ripples: snapshot.ripples, rippleScale: waveHeight(for: size))
    }

    /// The front surface's height at `t` (0 … 1 across), for bubbles to know
    /// where the air begins. Same formula as `waterPath`, one point only.
    static func frontSurfaceY(_ snapshot: WaterPhysics.Snapshot, at t: Double, in size: CGSize, calm: Bool) -> Double {
        let amplitude = waveHeight(for: size) * (calm ? 0.5 : 1) * (1 + snapshot.disturbance * 2.2)
        let center = size.height * (1 - snapshot.level)
        let tilt = snapshot.roll * size.height * maxTiltFraction
        let baseline = (center + tilt) + (-2 * tilt) * t
        let phase = snapshot.frontPhase
        let swell = sin((t + phase) * 2 * .pi)
        let chop = sin((t * 2.3 + phase * 2 + 0.3) * 2 * .pi) * 0.18
        return baseline + (swell + chop) * amplitude - ripple(snapshot.ripples, at: t, scale: waveHeight(for: size))
    }

    /// Vertical extent the front surface can occupy this frame (top … bottom),
    /// so overlays can skip work when the water is nowhere near them.
    static func surfaceBounds(_ snapshot: WaterPhysics.Snapshot, in size: CGSize, calm: Bool) -> ClosedRange<Double> {
        let center = size.height * (1 - snapshot.level)
        let tilt = abs(snapshot.roll) * size.height * maxTiltFraction
        let amplitude = waveHeight(for: size) * (calm ? 0.5 : 1) * (1 + snapshot.disturbance * 2.2) * 1.18
        let ripple = (snapshot.ripples.map(abs).max() ?? 0) * waveHeight(for: size)
        return (center - tilt - amplitude - ripple)...(center + tilt + amplitude + ripple)
    }

    static func draw(
        _ snapshot: WaterPhysics.Snapshot,
        in context: inout GraphicsContext,
        size: CGSize,
        style: WaterStyle,
        calm: Bool
    ) {
        let base = waveHeight(for: size)
        // Back layer: highest, widest swell, faintest — the far side of the
        // glass. It follows tilt and ripples less than the front (parallax).
        let backAmplitude = base * (calm ? 0.5 : 1.5) * (1 + snapshot.disturbance * 1.6)
        let back = waterPath(in: size, level: snapshot.level + 0.016, amplitude: backAmplitude,
                             phase: snapshot.backPhase, roll: snapshot.roll * 0.7, phaseShift: 0.45,
                             cycles: 0.8, ripples: snapshot.ripples, rippleScale: base * 0.35)
        context.fill(back, with: .color(style.surface.opacity(0.3)))

        // Middle layer: between the two in height, speed and opacity.
        let middleAmplitude = base * (calm ? 0.45 : 1.15) * (1 + snapshot.disturbance * 1.9)
        let middle = waterPath(in: size, level: snapshot.level + 0.008, amplitude: middleAmplitude,
                               phase: snapshot.middlePhase, roll: snapshot.roll * 0.85, phaseShift: 0.2,
                               cycles: 1.3, ripples: snapshot.ripples, rippleScale: base * 0.65)
        context.fill(middle, with: .color(style.surface.opacity(0.55)))

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

    /// Lone bubbles rising under the front surface: they wobble on the way
    /// up and fade out over the last stretch, popping silently before the air.
    private static func drawAmbient(_ snapshot: WaterPhysics.Snapshot, in context: inout GraphicsContext, size: CGSize, calm: Bool) {
        let fill = Color.white.opacity(0.22)
        let rim = Color.white.opacity(0.4)
        let highlight = Color.white.opacity(0.55)
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
            let opacity = fadeOut * fadeOut * fadeIn
            guard opacity > 0.01 else { continue }

            let d = bubble.size
            let rect = CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)
            context.opacity = opacity
            context.fill(Path(ellipseIn: rect), with: .color(fill))
            context.stroke(Path(ellipseIn: rect), with: .color(rim), lineWidth: 0.8)
            // A glint, top-left, so it reads as a sphere of air.
            let glint = d * 0.28
            context.fill(Path(ellipseIn: CGRect(x: x - d * 0.28, y: y - d * 0.3, width: glint, height: glint)),
                         with: .color(highlight))
            context.opacity = 1
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
