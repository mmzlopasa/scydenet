import Foundation

public struct ExportSettings: Codable, Equatable, Sendable {
    public enum Resolution: Int, Codable, CaseIterable, Sendable {
        case p720 = 720
        case p1080 = 1080
        case p1440 = 1440
        case p2160 = 2160

        public var label: String {
            switch self {
            case .p720: return "720p"
            case .p1080: return "1080p"
            case .p1440: return "2K"
            case .p2160: return "4K"
            }
        }
    }

    public enum Codec: String, Codable, CaseIterable, Sendable {
        case h264, hevc

        public var label: String {
            switch self {
            case .h264: return "H.264"
            case .hevc: return "HEVC"
            }
        }
    }

    public static let fpsOptions: [Int] = [24, 25, 30, 50, 60]

    public var resolution: Resolution
    public var fps: Int
    public var codec: Codec

    public init(resolution: Resolution = .p1080, fps: Int = 30, codec: Codec = .hevc) {
        self.resolution = resolution
        self.fps = fps
        self.codec = codec
    }

    /// Output size. The short side equals the chosen resolution (1080p vertical = 1080x1920).
    public func pixelSize(for aspect: CanvasAspect) -> (width: Int, height: Int) {
        let r = aspect.ratio
        let base = Double(resolution.rawValue)
        let w: Double
        let h: Double
        if r < 1 {
            w = base
            h = base / r
        } else {
            h = base
            w = base * r
        }
        return (Self.even(w), Self.even(h))
    }

    /// Video bitrate in bits per second. 10 Mbps for 1080p30 H.264, scaled by pixels and fps.
    public func videoBitrate(for aspect: CanvasAspect) -> Double {
        let size = pixelSize(for: aspect)
        let pixels = Double(size.width * size.height)
        let reference = 1920.0 * 1080.0
        let codecFactor = codec == .hevc ? 0.6 : 1.0
        return 10_000_000 * (pixels / reference) * (Double(fps) / 30.0) * codecFactor
    }

    public static let audioBitrate: Double = 192_000

    /// Rough output size in bytes.
    public func estimatedBytes(duration: Double, aspect: CanvasAspect) -> Int64 {
        let bits = (videoBitrate(for: aspect) + Self.audioBitrate) * max(0, duration)
        return Int64(bits / 8)
    }

    private static func even(_ value: Double) -> Int {
        let v = Int(value.rounded())
        return v % 2 == 0 ? v : v + 1
    }
}
