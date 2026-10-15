import SwiftUI
import UIKit

// Design tokens taken from reference/scyhost/site.css (see CLAUDE.md).

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    convenience init(rgb r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) {
        self.init(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
    }
}

enum SX {
    /// A color that follows the current light/dark appearance.
    static func dyn(_ dark: UIColor, _ light: UIColor) -> Color {
        Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }

    enum C {
        // Surfaces
        static let bg = SX.dyn(UIColor(hex: 0x0D0F14), UIColor(hex: 0xEEF0F3))
        static let editorBg = SX.dyn(UIColor(hex: 0x0A0B10), UIColor(hex: 0xE7E9EE))
        static let surface = SX.dyn(UIColor(hex: 0x14161D), UIColor(hex: 0xFFFFFF, alpha: 0.82))
        static let surface2 = SX.dyn(UIColor(hex: 0x1A1D25), UIColor(hex: 0xFFFFFF, alpha: 0.92))
        static let surface3 = SX.dyn(UIColor(hex: 0x262A35), UIColor(hex: 0xF6F5FF))
        static let glass = SX.dyn(UIColor(white: 1, alpha: 0.06), UIColor(white: 1, alpha: 0.72))
        static let lane = SX.dyn(UIColor(white: 1, alpha: 0.035), UIColor(rgb: 18, 20, 26, 0.045))

        // Text
        static let ink = SX.dyn(UIColor(hex: 0xF5F2FF), UIColor(hex: 0x12141A))
        static let body = SX.dyn(UIColor(hex: 0xB8B4DD), UIColor(hex: 0x4A4670))
        static let muted = SX.dyn(UIColor(hex: 0x8F8BBA), UIColor(hex: 0x6B678F))

        // Lines
        static let line = SX.dyn(UIColor(rgb: 184, 180, 235, 0.13), UIColor(rgb: 18, 20, 26, 0.12))
        static let line2 = SX.dyn(UIColor(rgb: 184, 180, 235, 0.26), UIColor(rgb: 18, 20, 26, 0.22))
        static let edge = SX.dyn(UIColor(white: 1, alpha: 0.14), UIColor(white: 1, alpha: 0.95))
        static let highlight = SX.dyn(UIColor(white: 1, alpha: 0.22), UIColor(white: 1, alpha: 1))

        // Brand and accent (accent = gold on dark, violet on light, like scyhost.com)
        static let brand = SX.dyn(UIColor(hex: 0xC4BBFF), UIColor(hex: 0x5A49E6))
        static let brand2 = SX.dyn(UIColor(hex: 0xA79CF5), UIColor(hex: 0x4333BE))
        static let onBrand = SX.dyn(UIColor(hex: 0x1B1530), UIColor(hex: 0xFFFFFF))
        static let accent = SX.dyn(UIColor(hex: 0xFFD76A), UIColor(hex: 0x5A49E6))
        static let accentHi = SX.dyn(UIColor(hex: 0xFFF0B8), UIColor(hex: 0x6E5EF0))
        static let accentLo = SX.dyn(UIColor(hex: 0xE9B84A), UIColor(hex: 0x4333BE))
        static let onAccent = SX.dyn(UIColor(hex: 0x1B1530), UIColor(hex: 0xFFFFFF))
        static let gold = Color(UIColor(hex: 0xFFD76A))

        static let ok = SX.dyn(UIColor(hex: 0x8EF0C8), UIColor(hex: 0x0C8A60))
        static let err = SX.dyn(UIColor(hex: 0xFF9AA8), UIColor(hex: 0xC42A46))
        static let warn = SX.dyn(UIColor(hex: 0xFFC98A), UIColor(hex: 0xA35A00))

        // Cards
        static let cardBase = SX.dyn(UIColor(rgb: 20, 22, 29, 0.72), UIColor(white: 1, alpha: 0.42))
        static let cardTop = SX.dyn(UIColor(white: 1, alpha: 0.10), UIColor(white: 1, alpha: 0.86))
        static let cardMid = SX.dyn(UIColor(white: 1, alpha: 0.03), UIColor(white: 1, alpha: 0.50))
        static let cardBottom = SX.dyn(UIColor(white: 1, alpha: 0.055), UIColor(white: 1, alpha: 0.70))
        static let shadow = SX.dyn(UIColor(white: 0, alpha: 0.55), UIColor(rgb: 18, 20, 26, 0.14))

        // Background glows
        static let glowA = SX.dyn(UIColor(rgb: 255, 215, 106, 0.20), UIColor(rgb: 90, 73, 230, 0.16))
        static let glowB = SX.dyn(UIColor(rgb: 160, 150, 255, 0.16), UIColor(rgb: 255, 215, 106, 0.26))

        // Timeline clips
        static let clipVideo = SX.dyn(UIColor(hex: 0xC4BBFF), UIColor(hex: 0x5A49E6))
        static let clipVideo2 = SX.dyn(UIColor(hex: 0x9E92F2), UIColor(hex: 0x4333BE))
        static let clipPhoto = SX.dyn(UIColor(hex: 0xA9C8FF), UIColor(hex: 0x3D6BE0))
        static let clipPhoto2 = SX.dyn(UIColor(hex: 0x7FA6F0), UIColor(hex: 0x2C52B8))
        static let clipAudio = SX.dyn(UIColor(hex: 0xFFD76A), UIColor(hex: 0xE9B84A))
        static let clipAudio2 = SX.dyn(UIColor(hex: 0xE9B84A), UIColor(hex: 0xC99526))
        static let clipText = SX.dyn(UIColor(hex: 0xF5F2FF), UIColor(hex: 0x262A35))
        static let clipText2 = SX.dyn(UIColor(hex: 0xD9D4F5), UIColor(hex: 0x12141A))
        static let onClipDark = Color(UIColor(hex: 0x1B1530))
        static let onClip = SX.dyn(UIColor(hex: 0x1B1530), UIColor(hex: 0xFFFFFF))
        static let selection = SX.dyn(UIColor(hex: 0xFFFFFF), UIColor(hex: 0x12141A))
    }

    enum R {
        static let s: CGFloat = 10
        static let m: CGFloat = 14
        static let l: CGFloat = 20
        static let xl: CGFloat = 28
    }

    /// Gold pill on dark, violet pill on light (`.btn-gold` / `.btn-brand` on scyhost.com).
    static let accentGradient = LinearGradient(
        stops: [
            .init(color: C.accentHi, location: 0),
            .init(color: C.accent, location: 0.55),
            .init(color: C.accentLo, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGradient = LinearGradient(
        stops: [
            .init(color: C.cardTop, location: 0),
            .init(color: C.cardMid, location: 0.42),
            .init(color: C.cardBottom, location: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Matches the site's `--ease: cubic-bezier(.22,1,.36,1)`.
    static let ease = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.45)
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
}
