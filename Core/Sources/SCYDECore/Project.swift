import Foundation

/// Canvas shapes the editor can produce. `ratio` is width / height.
public enum CanvasAspect: String, Codable, CaseIterable, Sendable {
    case portrait9x16 = "9:16"
    case landscape16x9 = "16:9"
    case square1x1 = "1:1"
    case portrait4x5 = "4:5"
    case cinema21x9 = "21:9"
    case portrait3x4 = "3:4"
    case landscape4x3 = "4:3"
    case portrait2x3 = "2:3"

    public var ratio: Double {
        switch self {
        case .portrait9x16: return 9.0 / 16.0
        case .landscape16x9: return 16.0 / 9.0
        case .square1x1: return 1.0
        case .portrait4x5: return 4.0 / 5.0
        case .cinema21x9: return 21.0 / 9.0
        case .portrait3x4: return 3.0 / 4.0
        case .landscape4x3: return 4.0 / 3.0
        case .portrait2x3: return 2.0 / 3.0
        }
    }

    public var label: String { rawValue }
}

/// Basic colour adjustments. Neutral values leave the image unchanged.
public struct Adjustments: Codable, Equatable, Sendable {
    /// EV stops, -2...2.
    public var exposure: Double
    /// 0.5...1.5, 1 = unchanged.
    public var contrast: Double
    /// 0...2, 1 = unchanged.
    public var saturation: Double
    /// -1 (cool) ... 1 (warm).
    public var warmth: Double
    /// -1...1, nil = unchanged.
    public var highlights: Double?
    public var shadows: Double?
    /// 0...1.
    public var sharpness: Double?
    /// 0...1.
    public var vignette: Double?
    /// -1 (green) ... 1 (magenta).
    public var tint: Double?
    /// 0...1 lifted blacks.
    public var fade: Double?
    /// 0...1 film grain.
    public var grain: Double?
    /// -1...1 midtone contrast.
    public var clarity: Double?

    public init(exposure: Double = 0, contrast: Double = 1, saturation: Double = 1, warmth: Double = 0) {
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.warmth = warmth
    }

    /// Drops extras that are (near) zero so neutral settings compare equal to `.neutral`.
    public func normalised() -> Adjustments {
        var a = self
        func z(_ v: Double?) -> Double? { (v.map { abs($0) < 0.005 } ?? true) ? nil : v }
        a.highlights = z(highlights)
        a.shadows = z(shadows)
        a.sharpness = z(sharpness)
        a.vignette = z(vignette)
        a.tint = z(tint)
        a.fade = z(fade)
        a.grain = z(grain)
        a.clarity = z(clarity)
        return a
    }

    public static let neutral = Adjustments()
    public var isNeutral: Bool { self == .neutral }
}

/// Position, scale, rotation and opacity of a visual clip on the canvas.
/// `x` and `y` are fractions of the canvas size (0 = centred, +y = down).
public struct ClipTransform: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var scale: Double
    /// Degrees, clockwise.
    public var rotation: Double
    public var opacity: Double

    public init(x: Double = 0, y: Double = 0, scale: Double = 1, rotation: Double = 0, opacity: Double = 1) {
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
    }

    public static let identity = ClipTransform()
    public var isIdentity: Bool { self == .identity }

    /// Linear interpolation between two transforms.
    public static func mix(_ a: ClipTransform, _ b: ClipTransform, _ t: Double) -> ClipTransform {
        let u = min(max(t, 0), 1)
        func l(_ p: Double, _ q: Double) -> Double { p + (q - p) * u }
        return ClipTransform(
            x: l(a.x, b.x), y: l(a.y, b.y), scale: l(a.scale, b.scale),
            rotation: l(a.rotation, b.rotation), opacity: l(a.opacity, b.opacity)
        )
    }
}

/// A transform pinned to a moment inside a clip. `time` is seconds from the clip start.
public struct Keyframe: Codable, Equatable, Sendable {
    public var time: Double
    public var transform: ClipTransform

    public init(time: Double, transform: ClipTransform) {
        self.time = time
        self.transform = transform
    }
}

/// Single-source transitions played at the start of a clip (and the end of the one before).
public enum TransitionKind: String, Codable, CaseIterable, Sendable {
    case fade, flash, zoom, blur, slide, spin, wipe, iris, glitch, whip, pixel, shake

    public var title: String {
        switch self {
        case .wipe: return "Wipe"
        case .iris: return "Iris"
        case .glitch: return "Glitch"
        case .whip: return "Whip"
        case .pixel: return "Pixelate"
        case .shake: return "Shake"
        case .fade: return "Fade"
        case .flash: return "Flash"
        case .zoom: return "Zoom"
        case .blur: return "Blur"
        case .slide: return "Slide"
        case .spin: return "Spin"
        }
    }
}

public struct ClipTransition: Codable, Equatable, Sendable {
    public var kind: TransitionKind
    /// Total length, split evenly across the cut.
    public var duration: Double

    public init(kind: TransitionKind, duration: Double = 0.6) {
        self.kind = kind
        self.duration = duration
    }
}

/// Removes a colour (green or blue screen) from a clip.
public struct ChromaKey: Codable, Equatable, Sendable {
    /// Hue in degrees: 120 green, 220 blue.
    public var hue: Double
    /// 0.05 ... 0.5 of the hue circle half-width.
    public var tolerance: Double

    public init(hue: Double = 120, tolerance: Double = 0.22) {
        self.hue = hue
        self.tolerance = tolerance
    }
}

/// One piece of media (or text) placed on a track.
///
/// Times are seconds. `start` is the position on the timeline, `sourceIn` the
/// offset into the source media, `duration` the length on the timeline.
public struct Clip: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case video, photo, audio, text, sticker
    }

    public var id: UUID
    public var kind: Kind
    public var name: String
    /// File name inside the app's media folder (never an absolute path).
    public var assetID: String?
    /// Length of the source media. `nil` for photos and text (unbounded).
    public var sourceDuration: Double?
    public var start: Double
    public var sourceIn: Double
    public var duration: Double
    public var speed: Double
    public var volume: Double
    /// Caption or title text for `.text` clips.
    public var text: String?
    /// Look preset identifier (see the app's look library). nil = original.
    public var filter: String?
    public var adjust: Adjustments?
    /// Cut the person out of the frame (Vision person segmentation).
    public var removeBackground: Bool?
    public var transform: ClipTransform?
    public var keyframes: [Keyframe]?
    /// Transition into this clip from the previous one on the main track.
    public var transitionIn: ClipTransition?
    /// Audio fades in seconds.
    public var fadeIn: Double?
    public var fadeOut: Double?
    public var chromaKey: ChromaKey?
    /// Font, colour, background and animation for `.text` and `.sticker` clips.
    public var textStyle: TextStyle?
    public var effect: VideoEffect?
    public var mask: ClipMask?
    public var crop: CropRect?
    public var flipH: Bool?
    public var flipV: Bool?
    /// Quarter turns clockwise applied to the source (0...3).
    public var quarterTurns: Int?
    /// How an overlay clip mixes with what is under it.
    public var blend: BlendMode?
    /// True when the media file holds the reversed source.
    public var reversed: Bool?

    public var end: Double { start + duration }

    /// Transform at a timeline time, interpolated between keyframes with an ease-in-out curve.
    public func transform(at timelineTime: Double) -> ClipTransform {
        guard let frames = keyframes, !frames.isEmpty else { return transform ?? .identity }
        let sorted = frames.sorted { $0.time < $1.time }
        let t = timelineTime - start
        if t <= sorted[0].time { return sorted[0].transform }
        if let last = sorted.last, t >= last.time { return last.transform }
        for i in 0..<(sorted.count - 1) {
            let a = sorted[i]
            let b = sorted[i + 1]
            if t >= a.time && t <= b.time {
                let span = max(b.time - a.time, 1e-6)
                let p = (t - a.time) / span
                let eased = p * p * (3 - 2 * p)
                return ClipTransform.mix(a.transform, b.transform, eased)
            }
        }
        return sorted[0].transform
    }

    public init(
        id: UUID = UUID(),
        kind: Kind,
        name: String,
        assetID: String? = nil,
        sourceDuration: Double? = nil,
        start: Double = 0,
        sourceIn: Double = 0,
        duration: Double,
        speed: Double = 1,
        volume: Double = 1,
        text: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.assetID = assetID
        self.sourceDuration = sourceDuration
        self.start = start
        self.sourceIn = sourceIn
        self.duration = duration
        self.speed = speed
        self.volume = volume
        self.text = text
    }
}

public struct Track: Codable, Equatable, Identifiable, Sendable {
    public enum Role: String, Codable, CaseIterable, Sendable {
        case main, overlay, audio, text, sticker
    }

    public var id: UUID
    public var role: Role
    public var clips: [Clip]

    public init(id: UUID = UUID(), role: Role, clips: [Clip] = []) {
        self.id = id
        self.role = role
        self.clips = clips
    }

    public var end: Double { clips.map { $0.end }.max() ?? 0 }
}

public struct Project: Codable, Equatable, Identifiable, Sendable {
    public static let minClipDuration: Double = 0.1

    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var aspect: CanvasAspect
    public var fps: Int
    public var tracks: [Track]
    public var export: ExportSettings
    /// What fills the canvas around media that does not cover it. nil = blurred fill.
    public var background: CanvasBackground?
    /// Beat or user markers on the timeline, in seconds.
    public var markers: [Double]?

    public init(
        id: UUID = UUID(),
        name: String = "Untitled",
        aspect: CanvasAspect = .portrait9x16,
        fps: Int = 30,
        now: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = now
        self.modifiedAt = now
        self.aspect = aspect
        self.fps = fps
        self.tracks = Track.Role.allCases.map { Track(role: $0) }
        self.export = ExportSettings()
    }

    /// Length of the whole edit in seconds.
    public var duration: Double { tracks.map { $0.end }.max() ?? 0 }

    public var isEmpty: Bool { tracks.allSatisfy { $0.clips.isEmpty } }

    public var clipCount: Int { tracks.reduce(0) { $0 + $1.clips.count } }
}
