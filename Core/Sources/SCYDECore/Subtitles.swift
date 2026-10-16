import Foundation

/// SubRip (.srt) import and export for text clips.
public enum Subtitles {
    public struct Cue: Equatable, Sendable {
        public var start: Double
        public var end: Double
        public var text: String

        public init(start: Double, end: Double, text: String) {
            self.start = start
            self.end = end
            self.text = text
        }
    }

    /// Text clips of the project as SRT, in time order.
    public static func srt(from project: Project) -> String {
        let clips = project.tracks
            .filter { $0.role == .text }
            .flatMap { $0.clips }
            .filter { !($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.start < $1.start }
        var out = ""
        for (i, clip) in clips.enumerated() {
            out += "\(i + 1)\n\(stamp(clip.start)) --> \(stamp(clip.end))\n\(clip.text ?? "")\n\n"
        }
        return out
    }

    /// Parses SRT text. Malformed blocks are skipped.
    public static func parse(_ text: String) -> [Cue] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var cues: [Cue] = []
        for block in normalized.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard let arrowIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let parts = lines[arrowIndex].components(separatedBy: "-->")
            guard parts.count == 2,
                  let a = seconds(parts[0]),
                  let b = seconds(parts[1]),
                  b > a else { continue }
            let body = lines[(arrowIndex + 1)...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            cues.append(Cue(start: a, end: b, text: body))
        }
        return cues.sorted { $0.start < $1.start }
    }

    /// `HH:MM:SS,mmm`
    public static func stamp(_ seconds: Double) -> String {
        let ms = Int((max(0, seconds) * 1000).rounded())
        return String(format: "%02d:%02d:%02d,%03d", ms / 3_600_000, (ms / 60_000) % 60, (ms / 1000) % 60, ms % 1000)
    }

    static func seconds(_ raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: ",")
        let main = s.split(separator: " ").first.map(String.init) ?? s
        let pieces = main.split(separator: ",")
        guard let hms = pieces.first else { return nil }
        let units = hms.split(separator: ":").compactMap { Double($0) }
        guard units.count == 3 else { return nil }
        let millis = pieces.count > 1 ? (Double(pieces[1]) ?? 0) : 0
        return units[0] * 3600 + units[1] * 60 + units[2] + millis / 1000
    }
}
