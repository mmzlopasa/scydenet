import Foundation

public struct SnapResult: Equatable, Sendable {
    public var time: Double
    public var snapped: Bool

    public init(time: Double, snapped: Bool) {
        self.time = time
        self.snapped = snapped
    }
}

extension Project {
    /// Times that edits should snap to: timeline start, playhead and every clip edge.
    public func snapTargets(excluding id: UUID?, playhead: Double) -> [Double] {
        var targets: [Double] = [0, playhead]
        for track in tracks {
            for clip in track.clips where clip.id != id {
                targets.append(clip.start)
                targets.append(clip.end)
            }
        }
        targets.append(contentsOf: markers ?? [])
        return targets
    }

    /// Snaps a single time to the nearest target within `threshold` seconds.
    public static func snap(_ time: Double, targets: [Double], threshold: Double) -> SnapResult {
        var best: Double?
        var bestDistance = threshold
        for target in targets {
            let d = abs(target - time)
            if d <= bestDistance {
                bestDistance = d
                best = target
            }
        }
        if let best = best { return SnapResult(time: best, snapped: true) }
        return SnapResult(time: time, snapped: false)
    }

    /// Snaps a moving clip by whichever of its two edges is closest to a target.
    public static func snapMove(start: Double, duration: Double, targets: [Double], threshold: Double) -> SnapResult {
        let a = snap(start, targets: targets, threshold: threshold)
        let b = snap(start + duration, targets: targets, threshold: threshold)
        switch (a.snapped, b.snapped) {
        case (true, true):
            let da = abs(a.time - start)
            let db = abs(b.time - (start + duration))
            return da <= db ? SnapResult(time: a.time, snapped: true) : SnapResult(time: b.time - duration, snapped: true)
        case (true, false):
            return SnapResult(time: a.time, snapped: true)
        case (false, true):
            return SnapResult(time: b.time - duration, snapped: true)
        case (false, false):
            return SnapResult(time: start, snapped: false)
        }
    }
}
