import Foundation

/// Canvas shapes the editor can produce. `ratio` is width / height.
public enum CanvasAspect: String, Codable, CaseIterable, Sendable {
    case portrait9x16 = "9:16"
    case landscape16x9 = "16:9"
    case square1x1 = "1:1"
    case portrait4x5 = "4:5"
    case cinema21x9 = "21:9"

    public var ratio: Double {
        switch self {
        case .portrait9x16: return 9.0 / 16.0
        case .landscape16x9: return 16.0 / 9.0
        case .square1x1: return 1.0
        case .portrait4x5: return 4.0 / 5.0
        case .cinema21x9: return 21.0 / 9.0
        }
    }

    public var label: String { rawValue }
}

/// One piece of media (or text) placed on a track.
///
/// Times are seconds. `start` is the position on the timeline, `sourceIn` the
/// offset into the source media, `duration` the length on the timeline.
public struct Clip: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case video, photo, audio, text
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

    public var end: Double { start + duration }

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
        volume: Double = 1
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
    }
}

public struct Track: Codable, Equatable, Identifiable, Sendable {
    public enum Role: String, Codable, CaseIterable, Sendable {
        case main, overlay, audio, text
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
