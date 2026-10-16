import Foundation

// Styling data for text, stickers, effects, masks, crop, blend and canvas.
// Every type decodes missing keys with defaults so saved projects stay readable
// when fields are added later.

// MARK: - Text

public enum TextAnimation: String, Codable, CaseIterable, Sendable {
    case none, fade, pop, slideUp, slideDown, slideLeft, slideRight, zoom, typewriter, bounce, blur, spin, drop
}

public enum TextLoop: String, Codable, CaseIterable, Sendable {
    case none, pulse, wiggle, float, blink, shake, heartbeat
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

// MARK: - Effects

/// A visual effect on a clip. `kind` is an identifier from the app's effect library.
public struct VideoEffect: Codable, Equatable, Sendable {
    public var kind: String
    /// 0...1.
    public var intensity: Double

    public init(kind: String, intensity: Double = 0.6) {
        self.kind = kind
        self.intensity = intensity
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

public enum BlendMode: String, Codable, CaseIterable, Sendable {
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
