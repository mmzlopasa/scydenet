import Foundation

/// Ripple inserts, freeze frames, markers and beat sync.
extension Project {

    // MARK: Ripple insert

    /// Inserts `clip` at `time` on a track, pushing every clip that starts at or after
    /// `time` later by the clip's duration. Returns the new clip's id.
    @discardableResult
    public mutating func insertRipple(_ clip: Clip, role: Track.Role, at time: Double) -> UUID {
        let ti: Int
        if let i = tracks.firstIndex(where: { $0.role == role }) {
            ti = i
        } else {
            tracks.append(Track(role: role))
            ti = tracks.count - 1
        }
        let t = max(0, time)
        for i in tracks[ti].clips.indices where tracks[ti].clips[i].start >= t - 1e-6 {
            tracks[ti].clips[i].start += clip.duration
        }
        var c = clip
        c.start = t
        let idx = tracks[ti].clips.firstIndex(where: { $0.start > t }) ?? tracks[ti].clips.count
        tracks[ti].clips.insert(c, at: idx)
        return c.id
    }

    // MARK: Freeze frame

    /// Holds the frame of a visual clip at `time` for `length` seconds: the clip is
    /// split at `time` and a still (already written to `frameAssetID`) is inserted
    /// between the halves. Returns the id of the still.
    @discardableResult
    public mutating func freeze(_ id: UUID, at time: Double, frameAssetID: String, length: Double = 3) -> UUID? {
        guard let loc = locate(id) else { return nil }
        let original = tracks[loc.track].clips[loc.clip]
        guard original.kind == .video, time >= original.start, time <= original.end else { return nil }
        let role = tracks[loc.track].role
        let m = Project.minClipDuration
        var insertAt = time
        if time <= original.start + m {
            insertAt = original.start
        } else if time >= original.end - m {
            insertAt = original.end
        } else {
            guard split(id, at: time) != nil else { return nil }
        }
        var still = Clip(kind: .photo, name: "Freeze", assetID: frameAssetID, duration: max(length, m))
        still.filter = original.filter
        still.adjust = original.adjust
        still.effect = original.effect
        still.crop = original.crop
        still.flipH = original.flipH
        still.flipV = original.flipV
        still.transform = original.transform(at: insertAt)
        return insertRipple(still, role: role, at: insertAt)
    }

    // MARK: Markers

    /// Adds a marker at `time`, or removes the one within `tolerance` of it.
    @discardableResult
    public mutating func toggleMarker(at time: Double, tolerance: Double = 0.08) -> Bool {
        var list = markers ?? []
        if let i = list.firstIndex(where: { abs($0 - time) <= tolerance }) {
            list.remove(at: i)
        } else {
            list.append(max(0, time))
        }
        list.sort()
        markers = list.isEmpty ? nil : list
        return true
    }

    @discardableResult
    public mutating func setMarkers(_ times: [Double]) -> Bool {
        var list: [Double] = []
        for t in times.sorted() where t >= 0 {
            if let last = list.last, t - last < 0.05 { continue }
            list.append(t)
        }
        let new: [Double]? = list.isEmpty ? nil : list
        guard new != markers else { return false }
        markers = new
        return true
    }

    // MARK: Beat sync

    /// Re-times the main track so every cut lands on a marker. Clips are laid back to
    /// back from 0; each one ends on the first marker at least `minLength` after its
    /// start (limited by the source for videos). Returns false without markers.
    @discardableResult
    public mutating func syncToMarkers(minLength: Double = 0.3) -> Bool {
        guard let beats = markers, !beats.isEmpty,
              let ti = tracks.firstIndex(where: { $0.role == .main }),
              !tracks[ti].clips.isEmpty else { return false }
        let before = tracks[ti].clips
        var cursor = 0.0
        for i in tracks[ti].clips.indices {
            var c = tracks[ti].clips[i]
            c.start = cursor
            var maxLength = Double.infinity
            if let sd = c.sourceDuration {
                maxLength = max(Project.minClipDuration, (sd - c.sourceIn) / c.speed)
            }
            if let beat = beats.first(where: { $0 >= cursor + minLength }) {
                c.duration = min(beat - cursor, maxLength)
            } else {
                c.duration = min(c.duration, maxLength)
            }
            c.duration = max(c.duration, Project.minClipDuration)
            if c.kind == .video || c.kind == .audio {
                // Keep the source range valid.
                if let sd = c.sourceDuration, c.sourceIn + c.duration * c.speed > sd + 1e-6 {
                    c.duration = max(Project.minClipDuration, (sd - c.sourceIn) / c.speed)
                }
            }
            if let frames = c.keyframes {
                c.keyframes = frames.filter { $0.time <= c.duration + 1e-6 }
                if c.keyframes?.isEmpty == true { c.keyframes = nil }
            }
            tracks[ti].clips[i] = c
            cursor = c.end
        }
        return tracks[ti].clips != before
    }

    // MARK: Canvas

    @discardableResult
    public mutating func setAspect(_ aspect: CanvasAspect) -> Bool {
        guard self.aspect != aspect else { return false }
        self.aspect = aspect
        return true
    }
}

extension Clip {
    /// Source seconds shown at a timeline time, following the speed ramp when there is one.
    public func sourceTime(at timelineTime: Double) -> Double {
        let local = min(max(timelineTime - start, 0), duration)
        guard let curve = speedCurve, curve.count > 1, duration > 0 else {
            return sourceIn + local * speed
        }
        let n = 24
        let slices = SpeedCurves.sourceSlices(curve, segments: n, sourceLength: duration * speed)
        let seg = duration / Double(n)
        let f = local / seg
        let i = min(Int(f), n - 1)
        let before = slices.prefix(i).reduce(0, +)
        return sourceIn + before + slices[i] * min(1, f - Double(i))
    }

    /// Mask at a timeline time (animated when `maskEnd` is set).
    public func mask(at timelineTime: Double) -> ClipMask? {
        guard let a = mask else { return nil }
        guard let b = maskEnd, duration > 0 else { return a }
        return ClipMask.mix(a, b, (timelineTime - start) / duration)
    }
}
