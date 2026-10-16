import Foundation

// Styling data for text, stickers, effects, masks, crop, blend and canvas.
// Every type decodes missing keys with defaults so saved projects stay readable
// when fields are added later.

// MARK: - Text

public enum TextAnimation: String, Codable, CaseIterable, Sendable {
    case none, fade, pop, slideUp, slideDown, slideLeft, slideRight, zoom, typewriter, bounce, blur, spin, drop
    case rise, flip, stretch, swing, glitch, shrink
}

public enum TextLoop: String, Codable, CaseIterable, Sendable {
    case none, pulse, wiggle, float, blink, shake, heartbeat, spin, jelly, sway
}

public enum TextBackground: String, Codable, CaseIterable, Sendable {
    case none, pill, box, rounded
}

public enum TextAlign: String, Codable, CaseIterable, Sendable {
    case left, center, right
}

public struct TextStyle: Codable, Equatable, Sendable {
    /// Font identifier from the app's font list.
    public var font: String
    /// Size relative to the default caption size.
    public var size: Double
    /// 0xRRGGBB.
    public var color: UInt32
    public var background: TextBackground
    public var backgroundColor: UInt32
    public var backgroundOpacity: Double
    /// Outline width relative to the font size (0 = none).
    public var stroke: Double
    public var strokeColor: UInt32
    public var shadow: Bool
    public var glow: Bool
    public var align: TextAlign
    public var uppercase: Bool
    /// Extra letter spacing relative to the font size.
    public var tracking: Double
    /// Vertical position of the text centre, fraction of the canvas height from the centre (+ = down).
    public var anchorY: Double
    public var animIn: TextAnimation
    public var animOut: TextAnimation
    public var loop: TextLoop
    /// Length of the in and out animations in seconds.
    public var animDuration: Double

    public init(
        font: String = "sora-bold",
        size: Double = 1,
        color: UInt32 = 0xFFFFFF,
        background: TextBackground = .pill,
        backgroundColor: UInt32 = 0x000000,
        backgroundOpacity: Double = 0.55,
        stroke: Double = 0,
        strokeColor: UInt32 = 0x000000,
        shadow: Bool = false,
        glow: Bool = false,
        align: TextAlign = .center,
        uppercase: Bool = false,
        tracking: Double = 0,
        anchorY: Double = 0.36,
        animIn: TextAnimation = .none,
        animOut: TextAnimation = .none,
        loop: TextLoop = .none,
        animDuration: Double = 0.5
    ) {
        self.font = font
        self.size = size
        self.color = color
        self.background = background
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.stroke = stroke
        self.strokeColor = strokeColor
        self.shadow = shadow
        self.glow = glow
        self.align = align
        self.uppercase = uppercase
        self.tracking = tracking
        self.anchorY = anchorY
        self.animIn = animIn
        self.animOut = animOut
        self.loop = loop
        self.animDuration = animDuration
    }

    /// The look of captions before any styling (white text on a dark pill, lower third).
    public static let caption = TextStyle()

    /// Default for stickers: centred, no background.
    public static let sticker = TextStyle(size: 3, background: .none, anchorY: 0)

    private enum CodingKeys: String, CodingKey {
        case font, size, color, background, backgroundColor, backgroundOpacity, stroke, strokeColor
        case shadow, glow, align, uppercase, tracking, anchorY, animIn, animOut, loop, animDuration
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TextStyle()
        font = try c.decodeIfPresent(String.self, forKey: .font) ?? d.font
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? d.size
        color = try c.decodeIfPresent(UInt32.self, forKey: .color) ?? d.color
        background = (try? c.decodeIfPresent(TextBackground.self, forKey: .background)) ?? d.background
        backgroundColor = try c.decodeIfPresent(UInt32.self, forKey: .backgroundColor) ?? d.backgroundColor
        backgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? d.backgroundOpacity
        stroke = try c.decodeIfPresent(Double.self, forKey: .stroke) ?? d.stroke
        strokeColor = try c.decodeIfPresent(UInt32.self, forKey: .strokeColor) ?? d.strokeColor
        shadow = try c.decodeIfPresent(Bool.self, forKey: .shadow) ?? d.shadow
        glow = try c.decodeIfPresent(Bool.self, forKey: .glow) ?? d.glow
        align = (try? c.decodeIfPresent(TextAlign.self, forKey: .align)) ?? d.align
        uppercase = try c.decodeIfPresent(Bool.self, forKey: .uppercase) ?? d.uppercase
        tracking = try c.decodeIfPresent(Double.self, forKey: .tracking) ?? d.tracking
        anchorY = try c.decodeIfPresent(Double.self, forKey: .anchorY) ?? d.anchorY
        animIn = (try? c.decodeIfPresent(TextAnimation.self, forKey: .animIn)) ?? d.animIn
        animOut = (try? c.decodeIfPresent(TextAnimation.self, forKey: .animOut)) ?? d.animOut
        loop = (try? c.decodeIfPresent(TextLoop.self, forKey: .loop)) ?? d.loop
        animDuration = try c.decodeIfPresent(Double.self, forKey: .animDuration) ?? d.animDuration
    }
}

// MARK: - Clip animation

/// Entrance, exit and loop motion for a video or photo clip (same vocabulary as text).
public struct ClipAnimation: Codable, Equatable, Sendable {
    public var animIn: TextAnimation
    public var animOut: TextAnimation
    public var loop: TextLoop
    public var duration: Double

    public init(animIn: TextAnimation = .none, animOut: TextAnimation = .none, loop: TextLoop = .none, duration: Double = 0.5) {
        self.animIn = animIn
        self.animOut = animOut
        self.loop = loop
        self.duration = duration
    }

    public var isNone: Bool { animIn == .none && animOut == .none && loop == .none }

    private enum CodingKeys: String, CodingKey { case animIn, animOut, loop, duration }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        animIn = (try? c.decodeIfPresent(TextAnimation.self, forKey: .animIn)) ?? TextAnimation.none
        animOut = (try? c.decodeIfPresent(TextAnimation.self, forKey: .animOut)) ?? TextAnimation.none
        loop = (try? c.decodeIfPresent(TextLoop.self, forKey: .loop)) ?? TextLoop.none
        duration = (try? c.decodeIfPresent(Double.self, forKey: .duration)) ?? 0.5
    }
}

// MARK: - Effects

/// A visual effect on a clip. `kind` is an identifier from the app's effect library.
public struct VideoEffect: Codable, Equatable, Sendable {
    public var kind: String
    /// 0...1.
    public var intensity: Double
    /// Intensity at the end of the clip; the effect ramps from `intensity` to this.
    public var endIntensity: Double?

    public init(kind: String, intensity: Double = 0.6, endIntensity: Double? = nil) {
        self.kind = kind
        self.intensity = intensity
        self.endIntensity = endIntensity
    }

    /// Intensity at a fraction (0...1) of the clip.
    public func intensity(at progress: Double) -> Double {
        guard let end = endIntensity else { return intensity }
        let p = min(max(progress, 0), 1)
        return intensity + (end - intensity) * p
    }
}

// MARK: - Masks

public enum MaskShape: String, Codable, CaseIterable, Sendable {
    case linear, mirror, circle, rectangle, heart, star
}

public struct ClipMask: Codable, Equatable, Sendable {
    public var shape: MaskShape
    /// Centre offset as a fraction of the canvas (0 = centred, +y = down).
    public var x: Double
    public var y: Double
    /// Size as a fraction of the shorter canvas side.
    public var size: Double
    /// Width / height for circle and rectangle.
    public var aspect: Double
    /// Degrees, clockwise.
    public var rotation: Double
    /// 0...1 softness of the edge.
    public var feather: Double
    public var invert: Bool

    public init(
        shape: MaskShape,
        x: Double = 0,
        y: Double = 0,
        size: Double = 0.6,
        aspect: Double = 1,
        rotation: Double = 0,
        feather: Double = 0.1,
        invert: Bool = false
    ) {
        self.shape = shape
        self.x = x
        self.y = y
        self.size = size
        self.aspect = aspect
        self.rotation = rotation
        self.feather = feather
        self.invert = invert
    }
}

extension ClipMask {
    /// Linear blend between two masks (shape and invert come from `a`).
    public static func mix(_ a: ClipMask, _ b: ClipMask, _ t: Double) -> ClipMask {
        let u = min(max(t, 0), 1)
        func l(_ p: Double, _ q: Double) -> Double { p + (q - p) * u }
        var m = a
        m.x = l(a.x, b.x)
        m.y = l(a.y, b.y)
        m.size = l(a.size, b.size)
        m.aspect = l(a.aspect, b.aspect)
        m.rotation = l(a.rotation, b.rotation)
        m.feather = l(a.feather, b.feather)
        return m
    }
}

// MARK: - Stabilisation

/// Per-frame correction offsets (fractions of the frame) sampled at `rate` per second
/// of source time, starting at `start` seconds into the source.
public struct Stabilization: Codable, Equatable, Sendable {
    public var start: Double
    public var rate: Double
    public var dx: [Float]
    public var dy: [Float]
    /// Zoom applied so the moving frame never shows its edges.
    public var zoom: Double

    public init(start: Double, rate: Double, dx: [Float], dy: [Float], zoom: Double) {
        self.start = start
        self.rate = rate
        self.dx = dx
        self.dy = dy
        self.zoom = zoom
    }

    /// Correction at a source time, linearly interpolated.
    public func offset(at sourceTime: Double) -> (Double, Double) {
        guard !dx.isEmpty, dx.count == dy.count, rate > 0 else { return (0, 0) }
        let f = (sourceTime - start) * rate
        if f <= 0 { return (Double(dx[0]), Double(dy[0])) }
        let i = Int(f)
        if i >= dx.count - 1 { return (Double(dx[dx.count - 1]), Double(dy[dy.count - 1])) }
        let u = f - Double(i)
        return (
            Double(dx[i]) + (Double(dx[i + 1]) - Double(dx[i])) * u,
            Double(dy[i]) + (Double(dy[i + 1]) - Double(dy[i])) * u
        )
    }
}

// MARK: - Speed curves

public enum SpeedCurves {
    public static let presets: [(id: String, name: String, points: [Double])] = [
        ("montage", "Montage", [1.0, 2.5, 0.5, 0.5, 2.5, 1.0, 1.0]),
        ("hero", "Hero", [1.0, 1.0, 3.0, 0.25, 3.0, 1.0, 1.0]),
        ("bullet", "Bullet", [3.0, 3.0, 0.2, 0.2, 0.2, 3.0, 3.0]),
        ("jump", "Jump cut", [0.6, 0.6, 4.0, 4.0, 0.6, 0.6, 4.0]),
        ("flashin", "Flash in", [4.0, 3.0, 1.5, 1.0, 1.0, 1.0, 1.0]),
        ("flashout", "Flash out", [1.0, 1.0, 1.0, 1.0, 1.5, 3.0, 4.0]),
        ("rampup", "Ramp up", [0.4, 0.6, 0.9, 1.2, 1.6, 2.2, 3.0]),
        ("rampdown", "Ramp down", [3.0, 2.2, 1.6, 1.2, 0.9, 0.6, 0.4]),
    ]

    /// Curve value at `u` (0...1), linear between evenly spaced points.
    public static func value(_ points: [Double], at u: Double) -> Double {
        guard points.count > 1 else { return max(points.first ?? 1, 0.05) }
        let x = min(max(u, 0), 1) * Double(points.count - 1)
        let i = min(Int(x), points.count - 2)
        let t = x - Double(i)
        return max(0.05, points[i] + (points[i + 1] - points[i]) * t)
    }

    /// Source seconds used by each of `segments` equal timeline slices, summing to `sourceLength`.
    public static func sourceSlices(_ points: [Double], segments: Int, sourceLength: Double) -> [Double] {
        let n = max(1, segments)
        let v = (0..<n).map { value(points, at: (Double($0) + 0.5) / Double(n)) }
        let total = v.reduce(0, +)
        guard total > 0 else { return Array(repeating: sourceLength / Double(n), count: n) }
        return v.map { $0 / total * sourceLength }
    }
}

// MARK: - Crop

/// Visible part of the source, in fractions of the source frame (origin top-left).
public struct CropRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double = 0, y: Double = 0, width: Double = 1, height: Double = 1) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let full = CropRect()
    public var isFull: Bool {
        abs(x) < 1e-4 && abs(y) < 1e-4 && abs(width - 1) < 1e-4 && abs(height - 1) < 1e-4
    }

    /// Largest centred crop with the given width/height ratio inside a source of `sourceRatio`.
    public static func centred(ratio: Double, sourceRatio: Double) -> CropRect {
        guard ratio > 0, sourceRatio > 0 else { return .full }
        if ratio > sourceRatio {
            let h = sourceRatio / ratio
            return CropRect(x: 0, y: (1 - h) / 2, width: 1, height: h)
        } else {
            let w = ratio / sourceRatio
            return CropRect(x: (1 - w) / 2, y: 0, width: w, height: 1)
        }
    }
}

// MARK: - Blend

public enum LayerBlend: String, Codable, CaseIterable, Sendable {
    case normal, multiply, screen, overlay, softLight, hardLight, darken, lighten
    case colorDodge, colorBurn, difference, exclusion, add, hue, color, luminosity
}

// MARK: - Canvas background

public struct CanvasBackground: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case blur, color, gradient
    }

    public var kind: Kind
    public var color: UInt32
    public var color2: UInt32
    /// Blur strength 0...1.
    public var blur: Double

    public init(kind: Kind = .blur, color: UInt32 = 0x000000, color2: UInt32 = 0x5A49E6, blur: Double = 0.5) {
        self.kind = kind
        self.color = color
        self.color2 = color2
        self.blur = blur
    }

    public static let standard = CanvasBackground()
}
