import UIKit
import SCYDECore

/// Fixture content for CI screenshots only (enabled with `-scydeDemo YES`).
/// It is never shown to users and never written to their library.
enum Demo {
    private static let base = Date().addingTimeInterval(-3600)

    static func editorProject() -> Project {
        var p = Project(
            id: UUID(uuidString: "5C7DE000-0000-4000-8000-000000000001")!,
            name: "Sunday ride",
            aspect: .portrait9x16,
            now: base
        )
        let mains: [(String, Double)] = [("Trailhead", 3.2), ("Descent", 2.4), ("Ridge line", 4.0), ("Golden hour", 2.8)]
        for (name, length) in mains {
            p.addClip(Clip(kind: .video, name: name, sourceDuration: length + 4, duration: length), role: .main)
        }
        p.addClip(Clip(kind: .text, name: "Sunday ride", duration: 2.6), role: .text, at: 0.4)
        p.addClip(Clip(kind: .photo, name: "Map", duration: 2.2), role: .overlay, at: 6.1)
        p.addClip(Clip(kind: .audio, name: "Soundtrack", sourceDuration: 90, duration: 12.4), role: .audio, at: 0)
        return p
    }

    static func homeProjects() -> [Project] {
        var a = editorProject()
        a.modifiedAt = Date().addingTimeInterval(-2 * 3600)

        var b = Project(id: UUID(uuidString: "5C7DE000-0000-4000-8000-000000000002")!, name: "Studio session", aspect: .landscape16x9, now: base)
        for (i, length) in [5.0, 3.5, 6.0].enumerated() {
            b.addClip(Clip(kind: .video, name: "Take \(i + 1)", sourceDuration: 20, duration: length), role: .main)
        }
        b.modifiedAt = Date().addingTimeInterval(-26 * 3600)

        var c = Project(id: UUID(uuidString: "5C7DE000-0000-4000-8000-000000000003")!, name: "Product shots", aspect: .square1x1, now: base)
        for i in 0..<6 {
            c.addClip(Clip(kind: .photo, name: "Shot \(i + 1)", duration: 1.5), role: .main)
        }
        c.modifiedAt = Date().addingTimeInterval(-5 * 86400)

        var d = Project(id: UUID(uuidString: "5C7DE000-0000-4000-8000-000000000004")!, name: "Portrait reel", aspect: .portrait4x5, now: base)
        for length in [2.0, 2.0, 3.0, 1.5, 2.5] {
            d.addClip(Clip(kind: .video, name: "Clip", sourceDuration: 10, duration: length), role: .main)
        }
        d.modifiedAt = Date().addingTimeInterval(-12 * 86400)
        return [a, b, c, d]
    }

    /// A drawn stand-in frame so the preview is not empty in screenshots.
    static func previewImage() -> UIImage {
        let size = CGSize(width: 720, height: 1280)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let sky = [
                UIColor(hex: 0x1B1F3B).cgColor,
                UIColor(hex: 0x5A49E6).cgColor,
                UIColor(hex: 0xF2A65A).cgColor,
                UIColor(hex: 0xFFD76A).cgColor,
            ] as CFArray
            if let g = CGGradient(colorsSpace: space, colors: sky, locations: [0, 0.45, 0.78, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height * 0.72), options: [.drawsAfterEndLocation])
            }
            // Sun
            UIColor(hex: 0xFFF0B8).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.56, y: size.height * 0.52, width: 150, height: 150))
            // Far ridge
            UIColor(hex: 0x3A2F6B).setFill()
            let far = UIBezierPath()
            far.move(to: CGPoint(x: 0, y: size.height * 0.66))
            far.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.58))
            far.addLine(to: CGPoint(x: size.width * 0.45, y: size.height * 0.64))
            far.addLine(to: CGPoint(x: size.width * 0.70, y: size.height * 0.55))
            far.addLine(to: CGPoint(x: size.width, y: size.height * 0.63))
            far.addLine(to: CGPoint(x: size.width, y: size.height))
            far.addLine(to: CGPoint(x: 0, y: size.height))
            far.close()
            far.fill()
            // Near ridge
            UIColor(hex: 0x14161D).setFill()
            let near = UIBezierPath()
            near.move(to: CGPoint(x: 0, y: size.height * 0.76))
            near.addCurve(
                to: CGPoint(x: size.width, y: size.height * 0.72),
                controlPoint1: CGPoint(x: size.width * 0.3, y: size.height * 0.66),
                controlPoint2: CGPoint(x: size.width * 0.6, y: size.height * 0.84)
            )
            near.addLine(to: CGPoint(x: size.width, y: size.height))
            near.addLine(to: CGPoint(x: 0, y: size.height))
            near.close()
            near.fill()
        }
    }
}
