import SwiftUI
import UIKit

/// Two-tone palette for illustrated icon tiles.
struct ArtPalette: Hashable {
    let top: UInt32
    let bottom: UInt32

    static let gold = ArtPalette(top: 0xFFE7A0, bottom: 0xE9A23A)
    static let violet = ArtPalette(top: 0xA79CFF, bottom: 0x4333BE)
    static let coral = ArtPalette(top: 0xFFB199, bottom: 0xFF4D6D)
    static let mint = ArtPalette(top: 0x9CF5D2, bottom: 0x10A37F)
    static let sky = ArtPalette(top: 0x9ED8FF, bottom: 0x2E6BE6)
    static let pink = ArtPalette(top: 0xFFB8E1, bottom: 0xD6338A)
    static let orange = ArtPalette(top: 0xFFD08A, bottom: 0xF2661C)
    static let teal = ArtPalette(top: 0x8FF0F0, bottom: 0x13889A)
    static let indigo = ArtPalette(top: 0x8C9BFF, bottom: 0x2B2F9E)
    static let lime = ArtPalette(top: 0xE4FF8F, bottom: 0x5DAA12)
    static let ruby = ArtPalette(top: 0xFF8FA3, bottom: 0xA3123A)
    static let graphite = ArtPalette(top: 0x8B90A0, bottom: 0x2C303B)

    static let all: [ArtPalette] = [gold, violet, coral, mint, sky, pink, orange, teal, indigo, lime, ruby, graphite]

    /// Stable palette for a name (same name, same colours, every launch).
    static func forName(_ name: String) -> ArtPalette {
        let sum = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return all[sum % all.count]
    }

    /// Palette by tool / symbol meaning, so related tools share colours.
    static func forTool(_ id: String) -> ArtPalette {
        switch id {
        case "import", "plus": return gold
        case "overlay", "pip": return sky
        case "stock", "library": return teal
        case "audio", "music", "voice", "voicefx", "sfx": return pink
        case "text", "subtitles", "captions", "style": return indigo
        case "stickers": return orange
        case "effects", "animate", "enhance": return violet
        case "filters", "adjust": return coral
        case "canvas", "crop", "transform": return mint
        case "beats", "speed": return lime
        case "autocut", "split", "freeze", "reverse": return ruby
        case "cover", "photo", "collage", "templates": return sky
        case "cutout", "mask", "chroma", "blend", "stabilise": return teal
        default: return forName(id)
        }
    }
}

/// An illustrated tile in the style of an app icon: glossy two-tone gradient, light from
/// the top left, a duotone glyph with depth, and a coloured soft shadow.
struct ArtIcon: View {
    let symbol: String
    let palette: ArtPalette
    var size: CGFloat = 58
    var dimmed: Bool = false

    var body: some View {
        let top = Color(UIColor(hex: palette.top))
        let bottom = Color(UIColor(hex: palette.bottom))
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        ZStack {
            ZStack {
            shape.fill(LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
            // Soft light blob from the top left.
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.5))
                .frame(width: size * 0.95, height: size * 0.95)
                .offset(x: -size * 0.28, y: -size * 0.3)
                .blendMode(.screen)
            // Darker floor for depth.
            shape.fill(LinearGradient(colors: [Color.clear, Color.black.opacity(0.18)], startPoint: .center, endPoint: .bottom))
            }
            .clipShape(shape)
            // Glyph: a shadow copy below, then the duotone glyph.
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(bottom.opacity(0.9))
                .offset(y: size * 0.045)
                .blur(radius: size * 0.02)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, Color.white.opacity(0.65))
            // Glossy rim.
            shape.strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.65), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                lineWidth: max(1, size * 0.02)
            )
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .shadow(color: bottom.opacity(dimmed ? 0 : 0.45), radius: size * 0.16, x: 0, y: size * 0.1)
        .saturation(dimmed ? 0 : 1)
        .opacity(dimmed ? 0.45 : 1)
    }
}
