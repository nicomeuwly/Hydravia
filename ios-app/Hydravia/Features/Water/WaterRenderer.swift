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

    /// The water body below a travelling, tilted sine surface.
    ///
    /// The surface is a diagonal baseline — higher on the side the device
    /// tilts toward, like water in a tilted glass — with the sine wave added
    /// on top.
    static func waterPath(
        in size: CGSize,
        level: Double,
        amplitude: Double,
        phase: Double,
        roll: Double,
        phaseShift: Double = 0
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
            let y = baseline + sin((t + phase + phaseShift) * 2 * .pi) * amplitude
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
                         phase: snapshot.frontPhase, roll: snapshot.roll)
    }

    /// Vertical extent the front surface can occupy this frame (top … bottom),
    /// so overlays can skip work when the water is nowhere near them.
    static func surfaceBounds(_ snapshot: WaterPhysics.Snapshot, in size: CGSize, calm: Bool) -> ClosedRange<Double> {
        let center = size.height * (1 - snapshot.level)
        let tilt = abs(snapshot.roll) * size.height * maxTiltFraction
        let amplitude = waveHeight(for: size) * (calm ? 0.5 : 1) * (1 + snapshot.disturbance * 2.2)
        return (center - tilt - amplitude)...(center + tilt + amplitude)
    }

    static func draw(
        _ snapshot: WaterPhysics.Snapshot,
        in context: inout GraphicsContext,
        size: CGSize,
        style: WaterStyle,
        calm: Bool
    ) {
        // Back layer: slightly higher, wider swell, translucent — the depth cue.
        let backAmplitude = waveHeight(for: size) * (calm ? 0.5 : 1.5) * (1 + snapshot.disturbance * 1.6)
        let back = waterPath(in: size, level: snapshot.level + 0.014, amplitude: backAmplitude,
                             phase: snapshot.backPhase, roll: snapshot.roll, phaseShift: 0.45)
        context.fill(back, with: .color(style.surface.opacity(0.38)))

        // Front layer: the main surface, darkening with depth across the
        // whole screen (so shallow water reads deep, a full screen reads lit).
        let front = frontPath(snapshot, in: size, calm: calm)
        context.fill(front, with: .linearGradient(
            Gradient(colors: [style.surface, style.deep]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)
        ))

        if let age = snapshot.celebrationAge {
            drawBubbles(snapshot.bubbles, age: age, in: &context, size: size)
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
