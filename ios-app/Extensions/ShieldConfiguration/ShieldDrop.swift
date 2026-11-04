import UIKit

/// The shield's icon: Hydravia's glossy drop, drawn in code
/// (the shield only takes a still image, and this keeps it crisp at any scale).
enum ShieldDrop {
    static let image: UIImage = draw()

    private static let side: CGFloat = 96

    private static func draw() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()

            // The drop: a circle with a pointed top. Each side curve meets the
            // circle along its tangent (perpendicular to the radius at ±30°),
            // so there's no corner where they join.
            let r: CGFloat = 26
            let bowl = CGPoint(x: side / 2, y: side - r - 6)
            let tip = CGPoint(x: bowl.x, y: bowl.y - r * 2.05)
            let drop = UIBezierPath()
            drop.move(to: tip)
            drop.addCurve(to: CGPoint(x: bowl.x + r * 0.866, y: bowl.y - r * 0.5),
                          controlPoint1: CGPoint(x: bowl.x + r * 0.18, y: bowl.y - r * 1.65),
                          controlPoint2: CGPoint(x: bowl.x + r * 0.566, y: bowl.y - r * 1.02))
            drop.addArc(withCenter: bowl, radius: r, startAngle: -.pi / 6, endAngle: .pi * 7 / 6, clockwise: true)
            drop.addCurve(to: tip,
                          controlPoint1: CGPoint(x: bowl.x - r * 0.566, y: bowl.y - r * 1.02),
                          controlPoint2: CGPoint(x: bowl.x - r * 0.18, y: bowl.y - r * 1.65))
            drop.close()

            cg.saveGState()
            drop.addClip()
            if let body = CGGradient(colorsSpace: space, colors: [
                UIColor(red: 0.62, green: 0.90, blue: 1, alpha: 1).cgColor,
                UIColor(red: 0.24, green: 0.61, blue: 0.78, alpha: 1).cgColor,
                UIColor(red: 0.09, green: 0.36, blue: 0.62, alpha: 1).cgColor,
            ] as CFArray, locations: [0, 0.55, 1]) {
                cg.drawLinearGradient(body, start: tip, end: CGPoint(x: bowl.x, y: bowl.y + r), options: [])
            }
            cg.restoreGState()

            // Shine and a small bubble, top left.
            UIColor(white: 1, alpha: 0.65).setFill()
            let shine = UIBezierPath(ovalIn: CGRect(x: -6, y: -11, width: 12, height: 22))
            shine.apply(CGAffineTransform(rotationAngle: .pi / 7)
                .concatenating(CGAffineTransform(translationX: bowl.x - r * 0.48, y: bowl.y - r * 0.42)))
            shine.fill()
            UIColor(white: 1, alpha: 0.5).setFill()
            UIBezierPath(ovalIn: CGRect(x: bowl.x - r * 0.2 - 3.5, y: bowl.y + r * 0.08, width: 7, height: 7)).fill()
        }
    }
}
