import CoreImage
import UIKit
import SCYDECore

/// Fonts available to text clips. Bundled fonts (SIL OFL) plus fonts that ship with iOS.
struct TextFont: Identifiable, Hashable {
    let id: String
    let name: String
    /// PostScript name; nil means a system font built from `weight` / `rounded`.
    let postScript: String?
    var weight: UIFont.Weight = .bold
    var rounded = false

    func uiFont(_ size: CGFloat) -> UIFont {
        if let ps = postScript, let f = UIFont(name: ps, size: size) { return f }
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if rounded, let d = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: d, size: size)
        }
        return base
    }

    static let all: [TextFont] = [
        TextFont(id: "sora-bold", name: "Sora", postScript: "Sora-Bold"),
        TextFont(id: "sora", name: "Sora Light", postScript: "Sora-Regular"),
        TextFont(id: "geist", name: "Geist", postScript: "Geist-SemiBold"),
        TextFont(id: "mono", name: "Mono", postScript: "GeistMono-Medium"),
        TextFont(id: "doto", name: "Dot", postScript: "Doto-Bold"),
        TextFont(id: "heavy", name: "Heavy", postScript: nil, weight: .black),
        TextFont(id: "rounded", name: "Rounded", postScript: nil, weight: .heavy, rounded: true),
        TextFont(id: "condensed", name: "Condensed", postScript: "HelveticaNeue-CondensedBlack"),
        TextFont(id: "futura", name: "Futura", postScript: "Futura-CondensedExtraBold"),
        TextFont(id: "avenir", name: "Avenir", postScript: "AvenirNext-Heavy"),
        TextFont(id: "gill", name: "Gill", postScript: "GillSans-UltraBold"),
        TextFont(id: "optima", name: "Optima", postScript: "Optima-ExtraBlack"),
        TextFont(id: "serif", name: "Georgia", postScript: "Georgia-Bold"),
        TextFont(id: "didot", name: "Didot", postScript: "Didot-Bold"),
        TextFont(id: "bodoni", name: "Bodoni", postScript: "BodoniSvtyTwoITCTT-Bold"),
        TextFont(id: "baskerville", name: "Classic", postScript: "Baskerville-BoldItalic"),
        TextFont(id: "copperplate", name: "Engraved", postScript: "Copperplate-Bold"),
        TextFont(id: "typewriter", name: "Typewriter", postScript: "AmericanTypewriter-Bold"),
        TextFont(id: "marker", name: "Marker", postScript: "MarkerFelt-Wide"),
        TextFont(id: "chalk", name: "Chalk", postScript: "Chalkduster"),
        TextFont(id: "note", name: "Note", postScript: "Noteworthy-Bold"),
        TextFont(id: "script", name: "Script", postScript: "SnellRoundhand-Black"),
        TextFont(id: "party", name: "Party", postScript: "PartyLetPlain"),
        TextFont(id: "zapfino", name: "Flourish", postScript: "Zapfino"),
    ]

    static func find(_ id: String) -> TextFont {
        all.first { $0.id == id } ?? all[0]
    }
}

/// Where an animated text or sticker is at a moment.
struct TextAnimState {
    var opacity = 1.0
    var scale = 1.0
    var dx = 0.0
    var dy = 0.0
    var rotation = 0.0
    var blur = 0.0
    /// Fraction of characters shown (typewriter).
    var chars = 1.0

    static func at(_ style: TextStyle, local: Double, duration: Double) -> TextAnimState {
        var s = TextAnimState()
        let d = max(0.05, min(style.animDuration, duration / 2))
        if style.animIn != .none, local < d {
            s.apply(style.animIn, max(0, local / d), entering: true)
        }
        if style.animOut != .none, local > duration - d {
            s.apply(style.animOut, max(0, (duration - local) / d), entering: false)
        }
        let tau = 2 * Double.pi
        switch style.loop {
        case .none: break
        case .pulse: s.scale *= 1 + 0.06 * sin(local * tau * 1.2)
        case .wiggle: s.rotation += 5 * sin(local * tau * 1.6)
        case .float: s.dy += 0.014 * sin(local * tau * 0.6)
        case .blink: s.opacity *= sin(local * tau * 1.4) > -0.35 ? 1 : 0.12
        case .shake:
            s.dx += 0.006 * sin(local * 53)
            s.dy += 0.006 * cos(local * 41)
        case .heartbeat:
            let ph = local.truncatingRemainder(dividingBy: 1)
            s.scale *= 1 + 0.12 * exp(-pow((ph - 0.1) / 0.06, 2)) + 0.08 * exp(-pow((ph - 0.32) / 0.06, 2))
        }
        return s
    }

    private static func easeOut(_ p: Double) -> Double { 1 - pow(1 - min(max(p, 0), 1), 3) }

    private static func backOut(_ p: Double) -> Double {
        let x = min(max(p, 0), 1)
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    private static func bounceOut(_ p: Double) -> Double {
        var x = min(max(p, 0), 1)
        let n1 = 7.5625, d1 = 2.75
        if x < 1 / d1 { return n1 * x * x }
        if x < 2 / d1 { x -= 1.5 / d1; return n1 * x * x + 0.75 }
        if x < 2.5 / d1 { x -= 2.25 / d1; return n1 * x * x + 0.9375 }
        x -= 2.625 / d1
        return n1 * x * x + 0.984375
    }

    /// `p` is 0 when hidden and 1 when fully shown.
    private mutating func apply(_ kind: TextAnimation, _ p: Double, entering: Bool) {
        let e = Self.easeOut(p)
        let sign = entering ? 1.0 : -1.0
        switch kind {
        case .none: break
        case .fade: opacity *= e
        case .pop:
            scale *= 0.2 + 0.8 * Self.backOut(p)
            opacity *= min(1, p * 2.5)
        case .slideUp:
            dy += sign * (1 - e) * 0.14
            opacity *= e
        case .slideDown:
            dy -= sign * (1 - e) * 0.14
            opacity *= e
        case .slideLeft:
            dx += sign * (1 - e) * 0.4
            opacity *= e
        case .slideRight:
            dx -= sign * (1 - e) * 0.4
            opacity *= e
        case .zoom:
            scale *= 1 + (1 - e) * 1.4
            opacity *= e
        case .typewriter:
            chars = min(chars, p)
        case .bounce:
            dy -= (1 - Self.bounceOut(p)) * 0.3
            opacity *= min(1, p * 4)
        case .blur:
            blur = max(blur, (1 - e) * 24)
            opacity *= e
        case .spin:
            rotation += sign * (1 - e) * 200
            scale *= 0.4 + 0.6 * e
            opacity *= e
        case .drop:
            dy -= (1 - Self.backOut(p)) * 0.6
            opacity *= min(1, p * 3)
        }
    }
}

/// Draws text and sticker artwork for the compositor (thread-safe, cached).
final class TextRenderer: @unchecked Sendable {
    static let shared = TextRenderer()
    private let lock = NSLock()
    private var cache: [String: CIImage] = [:]

    private func cached(_ key: String, _ make: () -> CIImage?) -> CIImage? {
        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        guard let made = make() else { return nil }
        lock.lock()
        if cache.count > 240 { cache.removeAll() }
        cache[key] = made
        lock.unlock()
        return made
    }

    static func baseSize(_ canvas: CGRect, _ style: TextStyle) -> CGFloat {
        max(canvas.width * 0.055, 14) * CGFloat(max(0.2, style.size))
    }

    /// Text art. `visible` limits how many characters are drawn (typewriter), keeping the layout fixed.
    func text(_ raw: String, style: TextStyle, canvas: CGRect, visible: Int? = nil) -> CIImage? {
        let text = style.uppercase ? raw.uppercased() : raw
        let key = "t|\(Int(canvas.width))|\(style.font)|\(style.size)|\(style.color)|\(style.background.rawValue)|\(style.backgroundColor)|\(style.backgroundOpacity)|\(style.stroke)|\(style.strokeColor)|\(style.shadow)|\(style.glow)|\(style.align.rawValue)|\(style.tracking)|\(visible ?? -1)|\(text)"
        return cached(key) { Self.drawText(text, style: style, canvas: canvas, visible: visible) }
    }

    func sticker(_ id: String, style: TextStyle, canvas: CGRect) -> CIImage? {
        let key = "s|\(Int(canvas.width))|\(style.size)|\(style.color)|\(style.shadow)|\(style.glow)|\(id)"
        return cached(key) { Self.drawSticker(id, style: style, canvas: canvas) }
    }

    private static func drawText(_ text: String, style: TextStyle, canvas: CGRect, visible: Int?) -> CIImage? {
        guard !text.isEmpty else { return nil }
        let base = baseSize(canvas, style)
        let font = TextFont.find(style.font).uiFont(base)
        let para = NSMutableParagraphStyle()
        switch style.align {
        case .left: para.alignment = .left
        case .center: para.alignment = .center
        case .right: para.alignment = .right
        }
        para.lineBreakMode = .byWordWrapping
        let color = UIColor(hex: style.color)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: para,
        ]
        if abs(style.tracking) > 0.001 { attrs[.kern] = CGFloat(style.tracking) * base }
        let maxWidth = canvas.width * 0.86
        let measure = NSAttributedString(string: text, attributes: attrs)
        let bounds = measure.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        let hasBG = style.background != .none
        let padH = hasBG ? base * 0.6 : base * 0.15
        let padV = hasBG ? base * 0.35 : base * 0.1
        let strokeW = CGFloat(max(0, style.stroke)) * base
        let extra = strokeW + (style.glow ? base * 0.6 : 0) + (style.shadow ? base * 0.25 : 0)
        let size = CGSize(
            width: ceil(bounds.width + padH * 2 + extra * 2),
            height: ceil(bounds.height + padV * 2 + extra * 2)
        )
        guard size.width > 1, size.height > 1, size.width < 8000, size.height < 8000 else { return nil }

        func attributed(_ a: [NSAttributedString.Key: Any], hide: [NSAttributedString.Key]) -> NSAttributedString {
            let s = NSMutableAttributedString(string: text, attributes: a)
            if let v = visible {
                let ns = text as NSString
                let shown = min(max(v, 0), ns.length)
                if shown < ns.length {
                    let range = NSRange(location: shown, length: ns.length - shown)
                    for k in hide { s.addAttribute(k, value: UIColor.clear, range: range) }
                }
            }
            return s
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let boxRect = CGRect(x: extra, y: extra, width: size.width - extra * 2, height: size.height - extra * 2)
            if hasBG {
                let radius: CGFloat
                switch style.background {
                case .pill: radius = min(base * 0.45, boxRect.height / 2)
                case .rounded: radius = base * 0.22
                default: radius = 0
                }
                UIColor(hex: style.backgroundColor, alpha: CGFloat(max(0, min(1, style.backgroundOpacity)))).setFill()
                UIBezierPath(roundedRect: boxRect, cornerRadius: radius).fill()
            }
            let textRect = CGRect(x: extra + padH, y: extra + padV, width: bounds.width, height: bounds.height)
            let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
            if style.glow {
                cg.saveGState()
                cg.setShadow(offset: .zero, blur: base * 0.7, color: color.withAlphaComponent(0.95).cgColor)
                attributed(attrs, hide: [.foregroundColor]).draw(with: textRect, options: options, context: nil)
                cg.restoreGState()
            }
            if style.shadow {
                cg.setShadow(offset: CGSize(width: 0, height: base * 0.07), blur: base * 0.2, color: UIColor(white: 0, alpha: 0.65).cgColor)
            }
            if strokeW > 0.5 {
                // Round outline: the text drawn in the outline colour around a circle, then the fill on top.
                var strokeAttrs = attrs
                strokeAttrs[.foregroundColor] = UIColor(hex: style.strokeColor)
                let outline = attributed(strokeAttrs, hide: [.foregroundColor])
                let steps = 16
                for i in 0..<steps {
                    let a = CGFloat(i) / CGFloat(steps) * 2 * .pi
                    let r = textRect.offsetBy(dx: cos(a) * strokeW, dy: sin(a) * strokeW)
                    outline.draw(with: r, options: options, context: nil)
                }
                cg.setShadow(offset: .zero, blur: 0, color: nil)
            }
            attributed(attrs, hide: [.foregroundColor]).draw(with: textRect, options: options, context: nil)
        }
        guard let cgImage = rendered.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }

    /// Stickers are emoji (any text) or SF Symbols written as `sf:name`.
    private static func drawSticker(_ id: String, style: TextStyle, canvas: CGRect) -> CIImage? {
        let base = baseSize(canvas, style)
        let pad = base * (style.glow ? 0.6 : 0.2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        var art: UIImage?
        if id.hasPrefix("sf:") {
            let name = String(id.dropFirst(3))
            let config = UIImage.SymbolConfiguration(pointSize: base, weight: .bold)
            art = UIImage(systemName: name, withConfiguration: config)?
                .withTintColor(UIColor(hex: style.color), renderingMode: .alwaysOriginal)
        } else {
            let font = UIFont.systemFont(ofSize: base)
            let s = NSAttributedString(string: id, attributes: [.font: font])
            let b = s.boundingRect(with: CGSize(width: 4000, height: 4000), options: [.usesLineFragmentOrigin], context: nil).integral
            guard b.width > 0, b.height > 0 else { return nil }
            art = UIGraphicsImageRenderer(size: b.size, format: format).image { _ in
                s.draw(at: .zero)
            }
        }
        guard let image = art else { return nil }
        let size = CGSize(width: ceil(image.size.width + pad * 2), height: ceil(image.size.height + pad * 2))
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            if style.glow {
                cg.setShadow(offset: .zero, blur: base * 0.5, color: UIColor(hex: style.color).withAlphaComponent(0.9).cgColor)
            } else if style.shadow {
                cg.setShadow(offset: CGSize(width: 0, height: base * 0.05), blur: base * 0.15, color: UIColor(white: 0, alpha: 0.55).cgColor)
            }
            image.draw(in: CGRect(x: pad, y: pad, width: image.size.width, height: image.size.height))
        }
        guard let cgImage = rendered.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }
}

/// Ready-made text looks shown in the text sheet.
struct TextPreset: Identifiable {
    let id: String
    let name: String
    let style: TextStyle

    static let all: [TextPreset] = [
        TextPreset(id: "caption", name: "Caption", style: .caption),
        TextPreset(id: "clean", name: "Clean", style: TextStyle(font: "geist", background: .none, shadow: true)),
        TextPreset(id: "bold-outline", name: "Outline", style: TextStyle(font: "heavy", size: 1.2, color: 0xFFFFFF, background: .none, stroke: 0.12, strokeColor: 0x000000, uppercase: true)),
        TextPreset(id: "yellow", name: "Punch", style: TextStyle(font: "heavy", size: 1.25, color: 0xFFD76A, background: .none, stroke: 0.1, strokeColor: 0x1B1530, uppercase: true, animIn: .pop)),
        TextPreset(id: "box", name: "Box", style: TextStyle(font: "geist", color: 0x12141A, background: .box, backgroundColor: 0xFFFFFF, backgroundOpacity: 1)),
        TextPreset(id: "highlight", name: "Highlight", style: TextStyle(font: "sora-bold", color: 0x1B1530, background: .rounded, backgroundColor: 0xFFD76A, backgroundOpacity: 1)),
        TextPreset(id: "violet", name: "Violet", style: TextStyle(font: "sora-bold", color: 0xFFFFFF, background: .rounded, backgroundColor: 0x5A49E6, backgroundOpacity: 1)),
        TextPreset(id: "neon", name: "Neon", style: TextStyle(font: "rounded", size: 1.2, color: 0xC4BBFF, background: .none, glow: true, loop: .pulse)),
        TextPreset(id: "neon-pink", name: "Neon pink", style: TextStyle(font: "marker", size: 1.3, color: 0xFF7AC8, background: .none, glow: true, loop: .blink)),
        TextPreset(id: "title", name: "Title", style: TextStyle(font: "sora-bold", size: 1.9, background: .none, shadow: true, anchorY: 0, animIn: .zoom, animOut: .fade)),
        TextPreset(id: "cinema", name: "Cinema", style: TextStyle(font: "didot", size: 1.5, background: .none, shadow: true, tracking: 0.25, anchorY: 0, animIn: .blur, animOut: .blur, animDuration: 0.9)),
        TextPreset(id: "typewriter", name: "Typewriter", style: TextStyle(font: "typewriter", background: .box, backgroundColor: 0xF5F2FF, backgroundOpacity: 0.92, animIn: .typewriter, animDuration: 1.2)),
        TextPreset(id: "dot", name: "Dot matrix", style: TextStyle(font: "doto", size: 1.4, color: 0xFFD76A, background: .none, glow: true)),
        TextPreset(id: "mono", name: "Terminal", style: TextStyle(font: "mono", color: 0x8EF0C8, background: .box, backgroundColor: 0x0D0F14, backgroundOpacity: 0.85, animIn: .typewriter, animDuration: 1)),
        TextPreset(id: "script", name: "Script", style: TextStyle(font: "script", size: 1.6, background: .none, shadow: true, anchorY: 0)),
        TextPreset(id: "chalk", name: "Chalk", style: TextStyle(font: "chalk", size: 1.2, background: .none)),
        TextPreset(id: "retro", name: "Retro", style: TextStyle(font: "futura", size: 1.5, color: 0xFF9AA8, background: .none, stroke: 0.08, strokeColor: 0x1B1530, uppercase: true, animIn: .bounce)),
        TextPreset(id: "news", name: "Lower third", style: TextStyle(font: "condensed", size: 1.1, color: 0xFFFFFF, background: .box, backgroundColor: 0xC42A46, backgroundOpacity: 1, align: .left, uppercase: true, anchorY: 0.3, animIn: .slideRight, animOut: .slideLeft)),
        TextPreset(id: "minimal", name: "Minimal", style: TextStyle(font: "geist", size: 0.8, background: .none, tracking: 0.3, anchorY: 0.42)),
        TextPreset(id: "party", name: "Party", style: TextStyle(font: "party", size: 1.7, color: 0xFFE7A0, background: .none, glow: true, anchorY: 0, loop: .wiggle)),
    ]
}

/// Built-in stickers: emoji and SF Symbols, both drawn by the system at render time.
enum StickerLibrary {
    struct Group: Identifiable {
        let id: String
        let name: String
        let items: [String]
    }

    static let groups: [Group] = [
        Group(id: "love", name: "Love", items: ["❤️", "💖", "💘", "😍", "🥰", "😘", "💋", "🌹", "sf:heart.fill", "sf:heart.circle.fill", "💕", "💞"]),
        Group(id: "fun", name: "Fun", items: ["😂", "🤣", "😎", "🤩", "🥳", "😜", "🤪", "😱", "🙈", "👀", "🤯", "💀"]),
        Group(id: "hands", name: "Hands", items: ["👍", "👏", "🙌", "✌️", "🤘", "👌", "🫶", "💪", "👉", "👈", "👆", "🙏"]),
        Group(id: "party", name: "Party", items: ["🎉", "🎊", "🎂", "🎁", "🎈", "🍾", "🥂", "🪩", "✨", "🎆", "🎇", "🏆"]),
        Group(id: "nature", name: "Nature", items: ["☀️", "🌙", "⭐️", "🌈", "🔥", "💧", "❄️", "⚡️", "🌸", "🌴", "🌊", "🍀"]),
        Group(id: "travel", name: "Travel", items: ["✈️", "🚗", "🏎️", "🏍️", "🚀", "🗺️", "📍", "🏝️", "🏔️", "🗽", "🎒", "📸"]),
        Group(id: "food", name: "Food", items: ["🍕", "🍔", "🍟", "🍣", "🍜", "🍩", "🍦", "☕️", "🍓", "🥑", "🍷", "🍹"]),
        Group(id: "icons", name: "Icons", items: ["sf:star.fill", "sf:bolt.fill", "sf:flame.fill", "sf:sparkles", "sf:crown.fill", "sf:music.note", "sf:hand.thumbsup.fill", "sf:checkmark.seal.fill", "sf:play.circle.fill", "sf:bell.fill", "sf:location.fill", "sf:camera.fill"]),
        Group(id: "arrows", name: "Arrows", items: ["sf:arrow.right", "sf:arrow.left", "sf:arrow.up", "sf:arrow.down", "sf:arrow.turn.right.down", "sf:arrow.uturn.left", "sf:arrowshape.right.fill", "sf:chevron.right.2", "sf:arrow.clockwise", "sf:circle.fill", "sf:square.fill", "sf:triangle.fill"]),
        Group(id: "social", name: "Social", items: ["sf:hand.tap.fill", "sf:bubble.left.fill", "sf:person.crop.circle.badge.plus", "sf:bookmark.fill", "sf:paperplane.fill", "sf:ellipsis.bubble.fill", "sf:at", "sf:number", "sf:link", "sf:eye.fill", "sf:megaphone.fill", "sf:gift.fill"]),
    ]
}
