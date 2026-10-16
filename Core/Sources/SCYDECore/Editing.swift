import Foundation

public enum TrimEdge: Sendable {
    case leading, trailing
}

/// Pure editing operations. Each returns whether it changed anything so the
/// caller can decide to record an undo step.
extension Project {

    // MARK: Lookup

    public func locate(_ id: UUID) -> (track: Int, clip: Int)? {
        for (ti, track) in tracks.enumerated() {
            if let ci = track.clips.firstIndex(where: { $0.id == id }) {
                return (ti, ci)
            }
        }
        return nil
    }

    public func clip(_ id: UUID) -> Clip? {
        guard let loc = locate(id) else { return nil }
        return tracks[loc.track].clips[loc.clip]
    }

    /// The clip of a given track role under `time`, if any.
    public func clip(at time: Double, role: Track.Role) -> Clip? {
        guard let track = tracks.first(where: { $0.role == role }) else { return nil }
        return track.clips.first { time >= $0.start && time < $0.end }
    }

    /// Any clip under `time`, preferring the main track.
    public func clipUnder(_ time: Double) -> Clip? {
        let order: [Track.Role] = [.main, .overlay, .sticker, .text, .audio]
        for role in order {
            if let c = clip(at: time, role: role) { return c }
        }
        return nil
    }

    // MARK: Add

    /// Adds a clip to the track with the given role. Without `start` the clip is
    /// appended after the last clip. Returns the id of the added clip.
    @discardableResult
    public mutating func addClip(_ clip: Clip, role: Track.Role, at start: Double? = nil) -> UUID {
        var c = clip
        let ti = trackIndex(for: role)
        let desired = start ?? tracks[ti].end
        c.start = Project.freeStart(for: c.duration, desired: desired, among: tracks[ti].clips)
        insertSorted(c, track: ti)
        return c.id
    }

    private mutating func trackIndex(for role: Track.Role) -> Int {
        if let i = tracks.firstIndex(where: { $0.role == role }) { return i }
        tracks.append(Track(role: role))
        return tracks.count - 1
    }

    private mutating func insertSorted(_ clip: Clip, track ti: Int) {
        var clips = tracks[ti].clips
        let idx = clips.firstIndex(where: { $0.start > clip.start }) ?? clips.count
        clips.insert(clip, at: idx)
        tracks[ti].clips = clips
    }

    // MARK: Split

    /// Splits a clip at `time`. Returns the id of the new right-hand clip.
    @discardableResult
    public mutating func split(_ id: UUID, at time: Double) -> UUID? {
        guard let loc = locate(id) else { return nil }
        var left = tracks[loc.track].clips[loc.clip]
        let m = Project.minClipDuration
        guard time > left.start + m, time < left.end - m else { return nil }

        var right = left
        right.id = UUID()
        let leftDuration = time - left.start
        right.start = time
        right.sourceIn = left.sourceIn + leftDuration * left.speed
        right.duration = left.end - time
        right.transitionIn = nil
        // A speed ramp cannot be cut in two exactly; both halves play at constant speed.
        left.speedCurve = nil
        right.speedCurve = nil
        right.fadeIn = nil
        left.fadeOut = nil
        if let frames = left.keyframes {
            right.keyframes = frames.map { Keyframe(time: $0.time - leftDuration, transform: $0.transform) }
        }

        left.duration = leftDuration
        tracks[loc.track].clips[loc.clip] = left
        tracks[loc.track].clips.insert(right, at: loc.clip + 1)
        return right.id
    }

    // MARK: Delete / duplicate

    @discardableResult
    public mutating func delete(_ id: UUID, ripple: Bool = false) -> Bool {
        guard let loc = locate(id) else { return false }
        let removed = tracks[loc.track].clips.remove(at: loc.clip)
        if ripple {
            var i = loc.clip
            while i < tracks[loc.track].clips.count {
                tracks[loc.track].clips[i].start = max(0, tracks[loc.track].clips[i].start - removed.duration)
                i += 1
            }
        }
        return true
    }

    /// Places a copy right after the original (or at the next free spot).
    @discardableResult
    public mutating func duplicate(_ id: UUID) -> UUID? {
        guard let loc = locate(id) else { return nil }
        var copy = tracks[loc.track].clips[loc.clip]
        copy.id = UUID()
        let ti = loc.track
        copy.start = Project.freeStart(for: copy.duration, desired: copy.end, among: tracks[ti].clips)
        insertSorted(copy, track: ti)
        return copy.id
    }

    // MARK: Trim

    /// Moves one edge of a clip to `time` (timeline seconds), respecting neighbours,
    /// the minimum duration and the length of the source media.
    @discardableResult
    public mutating func trim(_ id: UUID, edge: TrimEdge, to time: Double) -> Bool {
        guard let loc = locate(id) else { return false }
        let clips = tracks[loc.track].clips
        let original = clips[loc.clip]
        var c = original
        let prevEnd = loc.clip > 0 ? clips[loc.clip - 1].end : 0
        let nextStart = loc.clip + 1 < clips.count ? clips[loc.clip + 1].start : Double.infinity
        let m = Project.minClipDuration

        switch edge {
        case .leading:
            var lower = prevEnd
            if c.sourceDuration != nil {
                lower = max(lower, c.start - c.sourceIn / c.speed)
            }
            let upper = c.end - m
            let t = min(max(time, lower), upper)
            let delta = t - c.start
            c.sourceIn += delta * c.speed
            c.start = t
            c.duration -= delta
        case .trailing:
            var upper = nextStart
            if let sd = c.sourceDuration {
                upper = min(upper, c.start + (sd - c.sourceIn) / c.speed)
            }
            let lower = c.start + m
            let t = min(max(time, lower), upper)
            c.duration = t - c.start
        }
        if c.sourceDuration == nil { c.sourceIn = 0 }

        guard c != original else { return false }
        tracks[loc.track].clips[loc.clip] = c
        return true
    }

    // MARK: Move

    /// Moves a clip so it starts at `desired`, sliding to the nearest free slot on its track.
    @discardableResult
    public mutating func move(_ id: UUID, toStart desired: Double) -> Bool {
        guard let loc = locate(id) else { return false }
        var c = tracks[loc.track].clips.remove(at: loc.clip)
        let before = c.start
        c.start = Project.freeStart(for: c.duration, desired: desired, among: tracks[loc.track].clips)
        insertSorted(c, track: loc.track)
        return abs(c.start - before) > 1e-9
    }

    static func freeStart(for duration: Double, desired: Double, among others: [Clip]) -> Double {
        var s = max(0, desired)
        let eps = 1e-9
        var pass = 0
        while pass <= others.count {
            guard let hit = others.first(where: { s < $0.end - eps && s + duration > $0.start + eps }) else {
                return s
            }
            let after = hit.end
            let before = hit.start - duration
            if before >= 0 && abs(before - s) < abs(after - s) {
                s = before
            } else {
                s = after
            }
            pass += 1
        }
        return others.map { $0.end }.max() ?? s
    }

    // MARK: Speed

    /// Changes playback speed, keeping the same source range. Later clips on the
    /// track shift so nothing overlaps (and gaps are preserved).
    @discardableResult
    public mutating func setSpeed(_ id: UUID, to speed: Double) -> Bool {
        guard let loc = locate(id) else { return false }
        var c = tracks[loc.track].clips[loc.clip]
        guard c.kind == .video || c.kind == .audio else { return false }
        let s = min(max(speed, 0.1), 8)
        guard abs(c.speed - s) > 1e-9 else { return false }
        let sourceLength = c.duration * c.speed
        let newDuration = max(sourceLength / s, Project.minClipDuration)
        let delta = newDuration - c.duration
        c.speed = s
        c.duration = newDuration
        tracks[loc.track].clips[loc.clip] = c
        var i = loc.clip + 1
        while i < tracks[loc.track].clips.count {
            tracks[loc.track].clips[i].start = max(0, tracks[loc.track].clips[i].start + delta)
            i += 1
        }
        return true
    }

    // MARK: Generic clip properties

    /// Applies `change` to one clip. Timing fields should go through the dedicated
    /// operations; this is for look, text and flags.
    @discardableResult
    public mutating func updateClip(_ id: UUID, _ change: (inout Clip) -> Void) -> Bool {
        guard let loc = locate(id) else { return false }
        var c = tracks[loc.track].clips[loc.clip]
        let before = c
        change(&c)
        guard c != before else { return false }
        c.id = before.id
        c.start = before.start
        c.duration = before.duration
        tracks[loc.track].clips[loc.clip] = c
        return true
    }

    /// Removes the timeline span [from, to) from a clip on the main track and closes the gap.
    @discardableResult
    public mutating func cut(_ id: UUID, from: Double, to: Double) -> Bool {
        guard let c = clip(id), to > from else { return false }
        let a = max(from, c.start)
        let b = min(to, c.end)
        guard b - a > 1e-6 else { return false }
        let m = Project.minClipDuration
        var target = id
        if a > c.start + m {
            guard let right = split(id, at: a) else { return false }
            target = right
        }
        if let t = clip(target), b < t.end - m {
            _ = split(target, at: b)
        }
        return delete(target, ripple: true)
    }

    // MARK: Keyframes

    /// Adds or replaces the keyframe at `time` (timeline seconds) on a clip.
    @discardableResult
    public mutating func setKeyframe(_ id: UUID, at time: Double, transform: ClipTransform) -> Bool {
        guard let loc = locate(id) else { return false }
        var c = tracks[loc.track].clips[loc.clip]
        let local = min(max(time - c.start, 0), c.duration)
        var frames = c.keyframes ?? []
        if let i = frames.firstIndex(where: { abs($0.time - local) < 0.05 }) {
            guard frames[i].transform != transform else { return false }
            frames[i].transform = transform
        } else {
            frames.append(Keyframe(time: local, transform: transform))
        }
        c.keyframes = frames.sorted { $0.time < $1.time }
        tracks[loc.track].clips[loc.clip] = c
        return true
    }

    @discardableResult
    public mutating func removeKeyframe(_ id: UUID, near time: Double) -> Bool {
        guard let loc = locate(id) else { return false }
        var c = tracks[loc.track].clips[loc.clip]
        let local = time - c.start
        guard var frames = c.keyframes, let i = frames.firstIndex(where: { abs($0.time - local) < 0.05 }) else { return false }
        frames.remove(at: i)
        c.keyframes = frames.isEmpty ? nil : frames
        tracks[loc.track].clips[loc.clip] = c
        return true
    }

    // MARK: Volume

    @discardableResult
    public mutating func setVolume(_ id: UUID, to volume: Double) -> Bool {
        guard let loc = locate(id) else { return false }
        let v = min(max(volume, 0), 2)
        guard abs(tracks[loc.track].clips[loc.clip].volume - v) > 1e-9 else { return false }
        tracks[loc.track].clips[loc.clip].volume = v
        return true
    }
}
