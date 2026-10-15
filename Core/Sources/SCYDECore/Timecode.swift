import Foundation

public enum Timecode {
    /// `m:ss.ff`, e.g. `0:03.12` at 30 fps.
    public static func string(_ seconds: Double, fps: Int = 30) -> String {
        let total = max(0, seconds.isFinite ? seconds : 0)
        let whole = Int(total)
        let rawFrames = Int((total - Double(whole)) * Double(fps) + 1e-6)
        let frames = min(max(fps - 1, 0), rawFrames)
        return String(format: "%d:%02d.%02d", whole / 60, whole % 60, frames)
    }

    /// Compact label for rulers and cards: `0:05`, `1:30`.
    public static func short(_ seconds: Double) -> String {
        let total = max(0, seconds.isFinite ? seconds : 0)
        let whole = Int(total.rounded())
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    /// Clip duration label: `4.2s` under a minute, otherwise `1:05`.
    public static func duration(_ seconds: Double) -> String {
        let total = max(0, seconds.isFinite ? seconds : 0)
        if total < 60 { return String(format: "%.1fs", total) }
        return short(total)
    }
}
