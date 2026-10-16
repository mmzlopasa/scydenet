import AVFoundation
import CoreGraphics
import ImageIO
import SCYDECore

/// Turns a `Project` into an AVComposition + custom video composition + audio mix.
///
/// Track layout (fixed IDs):
/// - 1 main video, 2 overlay video
/// - 11 main audio (from main video clips), 12 overlay audio, 13 music/audio clips
/// Photos are empty ranges on the video track; the compositor draws them.
@MainActor
final class CompositionBuilder {
    struct Output {
        let composition: AVComposition
        let videoComposition: AVVideoComposition
        let audioMix: AVAudioMix
        let duration: Double
    }

    private struct Source {
        /// Kept alive on purpose: a track whose asset is released fails to insert (-11800).
        let asset: AVURLAsset
        let video: AVAssetTrack?
        let audio: AVAssetTrack?
        let duration: CMTime
        let orientation: UInt32
    }

    private struct PlacedLayer {
        let range: CMTimeRange
        let layer: SXLayer
    }

    static let mainVideoID: CMPersistentTrackID = 1
    static let overlayVideoID: CMPersistentTrackID = 2
    static let altVideoID: CMPersistentTrackID = 3
    static let mainAudioID: CMPersistentTrackID = 11
    static let overlayAudioID: CMPersistentTrackID = 12
    static let musicAudioID: CMPersistentTrackID = 13

    private var sources: [String: Source] = [:]
    /// Step-by-step notes from the last build (shown in the CI diagnostics overlay).
    private(set) var notes: [String] = []

    static func ct(_ seconds: Double) -> CMTime {
        CMTime(seconds: max(0, seconds), preferredTimescale: 600)
    }

    func build(_ project: Project, renderSize: CGSize, fps: Int? = nil) async -> Output? {
        notes = []
        let composition = AVMutableComposition()
        guard
            let mainV = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Self.mainVideoID),
            let overV = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Self.overlayVideoID),
            let mainA = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Self.mainAudioID),
            let overA = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Self.overlayAudioID),
            let musicA = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Self.musicAudioID)
        else {
            notes.append("addMutableTrack failed")
            return nil
        }

        var placed: [PlacedLayer] = []
        let mainParams = AVMutableAudioMixInputParameters(track: mainA)
        let overParams = AVMutableAudioMixInputParameters(track: overA)
        let musicParams = AVMutableAudioMixInputParameters(track: musicA)

        let visualRoles: [(Track.Role, AVMutableCompositionTrack, AVMutableCompositionTrack, AVMutableAudioMixInputParameters)] = [
            (.main, mainV, mainA, mainParams),
            (.overlay, overV, overA, overParams),
        ]
        // Second main video track: the incoming clip of a cross dissolve overlaps the outgoing one.
        var altV: AVMutableCompositionTrack?

        for (role, vTrack, aTrack, params) in visualRoles {
            let clips = project.tracks.first(where: { $0.role == role })?.clips ?? []
            var onAlt = false
            for (index, clip) in clips.enumerated() where clip.kind == .video || clip.kind == .photo {
                let isMain = role == .main
                let background = isMain ? project.background : nil
                let prev = index > 0 ? clips[index - 1] : nil
                let next = index + 1 < clips.count ? clips[index + 1] : nil
                guard let assetID = clip.assetID else { continue }

                // Cross dissolve: the incoming clip starts early, the outgoing one runs late.
                let dissolveIn = isMain && Self.dissolves(prev, into: clip)
                let dissolveOut = isMain && Self.dissolves(clip, into: next)
                if dissolveIn { onAlt.toggle() }
                var track = vTrack
                if isMain && onAlt {
                    if altV == nil {
                        altV = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Self.altVideoID)
                    }
                    if let alt = altV { track = alt }
                }
                var pre = 0.0
                var ext = 0.0
                if dissolveIn, let t = clip.transitionIn {
                    pre = t.duration / 2
                    if clip.kind == .video {
                        pre = clip.speedCurve == nil ? min(pre, clip.sourceIn / clip.speed) : 0
                    }
                    if clip.kind == .video {
                        pre = min(pre, max(0, clip.start - Self.end(of: track)))
                    }
                }
                if dissolveOut, let t = next?.transitionIn {
                    ext = t.duration / 2
                    if clip.kind == .video {
                        if clip.speedCurve != nil {
                            ext = 0
                        } else if let sd = clip.sourceDuration {
                            ext = min(ext, max(0, (sd - (clip.sourceIn + clip.duration * clip.speed)) / clip.speed))
                        }
                    }
                }
                let window: ClosedRange<Double>? = {
                    guard dissolveIn, let p = prev else { return nil }
                    let a = clip.start - pre
                    let b = p.end + Self.tail(of: p, into: clip)
                    return b - a > 0.02 ? a...b : nil
                }()

                let at = Self.ct(clip.start)
                let length = Self.ct(clip.duration)
                let range = CMTimeRange(start: Self.ct(clip.start - pre), end: Self.ct(clip.end + ext))
                var layer: SXLayer

                if clip.kind == .photo {
                    layer = Self.layer(.photo(assetID: assetID), clip: clip, isMain: isMain, next: next, background: background)
                    layer.dissolve = window
                    placed.append(PlacedLayer(range: range, layer: layer))
                    if isMain {
                        // Keep the main track continuous with blank video where it is free.
                        let from = max(clip.start, Self.end(of: mainV))
                        if clip.end - from > 0.01 {
                            Self.pad(mainV, to: Self.ct(from))
                            await fill(mainV, at: Self.ct(from), length: Self.ct(clip.end - from))
                        }
                    }
                    continue
                }

                guard let src = await source(assetID) else {
                    notes.append("\(clip.name): source failed")
                    continue
                }
                guard let video = src.video else {
                    notes.append("\(clip.name): no video track")
                    continue
                }
                let start = Self.ct(clip.start - pre)
                Self.pad(track, to: start)
                let inserted: Bool
                if pre > 0 || ext > 0 {
                    inserted = Self.insertRange(
                        from: video, sourceDuration: src.duration,
                        sourceStart: clip.sourceIn - pre * clip.speed,
                        sourceLength: (clip.duration + pre + ext) * clip.speed,
                        into: track, at: start, length: Self.ct(clip.duration + pre + ext)
                    )
                } else {
                    inserted = Self.insert(from: video, sourceDuration: src.duration, clip: clip, into: track, at: at, length: length)
                }
                guard inserted else {
                    notes.append("\(clip.name): insert failed \(Self.lastInsertError)")
                    continue
                }
                layer = Self.layer(.video(trackID: track.trackID, orientation: src.orientation), clip: clip, isMain: isMain, next: next, background: background)
                layer.dissolve = window
                placed.append(PlacedLayer(range: range, layer: layer))
                if let audio = src.audio {
                    Self.pad(aTrack, to: at)
                    if Self.insert(from: audio, sourceDuration: src.duration, clip: clip, into: aTrack, at: at, length: length) {
                        Self.applyVolume(params, clip: clip, at: at, length: length)
                    }
                }
            }
        }

        // Captions and titles.
        let textClips = project.tracks.first(where: { $0.role == .text })?.clips ?? []
        for clip in textClips {
            guard let text = clip.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { continue }
            placed.append(PlacedLayer(
                range: CMTimeRange(start: Self.ct(clip.start), duration: Self.ct(clip.duration)),
                layer: SXLayer(source: .text(text), isMain: false, clip: clip)
            ))
        }

        // Stickers.
        let stickerClips = project.tracks.first(where: { $0.role == .sticker })?.clips ?? []
        for clip in stickerClips {
            guard let id = clip.text, !id.isEmpty else { continue }
            placed.append(PlacedLayer(
                range: CMTimeRange(start: Self.ct(clip.start), duration: Self.ct(clip.duration)),
                layer: SXLayer(source: .sticker(id), isMain: false, clip: clip)
            ))
        }

        // Audio-only clips (music, voice-over).
        let audioClips = project.tracks.first(where: { $0.role == .audio })?.clips ?? []
        for clip in audioClips {
            guard let assetID = clip.assetID, let src = await source(assetID), let audio = src.audio else { continue }
            let at = Self.ct(clip.start)
            Self.pad(musicA, to: at)
            if Self.insert(from: audio, sourceDuration: src.duration, clip: clip, into: musicA, at: at, length: Self.ct(clip.duration)) {
                Self.applyVolume(musicParams, clip: clip, at: at, length: Self.ct(clip.duration))
            }
        }

        // Keep the main video track as long as the edit (text or overlays past the last clip).
        let total = Self.ct(project.duration)
        let mainEnd = mainV.timeRange.isValid ? mainV.timeRange.end : .zero
        if total > mainEnd {
            await fill(mainV, at: mainEnd, length: CMTimeSubtract(total, mainEnd))
        }

        for track in [overV, mainA, overA, musicA] + (altV.map { [$0] } ?? []) where track.segments.isEmpty {
            composition.removeTrack(track)
        }

        let duration = composition.duration
        notes.append("dur \(String(format: "%.2f", duration.seconds)) placed \(placed.count) mainV segs \(mainV.segments.count)")
        guard duration > .zero, !placed.isEmpty else { return nil }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = SXCompositor.self
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(fps ?? project.fps, 1)))
        videoComposition.instructions = Self.instructions(for: placed, duration: duration)

        let mix = AVMutableAudioMix()
        var inputs: [AVAudioMixInputParameters] = []
        for (params, track) in [(mainParams, mainA), (overParams, overA), (musicParams, musicA)] where !track.segments.isEmpty {
            inputs.append(params)
        }
        mix.inputParameters = inputs

        return Output(composition: composition, videoComposition: videoComposition, audioMix: mix, duration: duration.seconds)
    }

    // MARK: Helpers

    private var blank: Source?

    /// Inserts a stretch of the generated blank video so the track has real media there.
    private func fill(_ track: AVMutableCompositionTrack, at: CMTime, length: CMTime) async {
        guard length > .zero else { return }
        if blank == nil, let url = await BlankVideo.url() {
            let asset = AVURLAsset(url: url)
            if let v = try? await asset.loadTracks(withMediaType: .video).first,
               let d = try? await asset.load(.duration) {
                blank = Source(asset: asset, video: v, audio: nil, duration: d, orientation: CGImagePropertyOrientation.up.rawValue)
            }
        }
        guard let b = blank, let v = b.video else {
            notes.append("blank video unavailable")
            Self.pad(track, to: CMTimeAdd(at, length))
            return
        }
        let piece = CMTimeMinimum(b.duration, length)
        do {
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: piece), of: v, at: at)
            if piece != length {
                track.scaleTimeRange(CMTimeRange(start: at, duration: piece), toDuration: length)
            }
        } catch {
            notes.append("blank insert failed \((error as NSError).code)")
        }
    }

    private static func layer(_ source: SXLayer.Source, clip: Clip, isMain: Bool, next: Clip? = nil, background: CanvasBackground? = nil) -> SXLayer {
        var out: ClipTransition?
        if isMain, let n = next, abs(n.start - clip.end) < 0.05 {
            out = n.transitionIn
        }
        return SXLayer(
            source: source,
            isMain: isMain,
            filter: clip.filter,
            adjust: clip.adjust,
            cutout: clip.removeBackground ?? false,
            clip: clip,
            outTransition: out,
            background: background
        )
    }

    /// True when `b` follows `a` directly on the main track with a cross dissolve.
    private static func dissolves(_ a: Clip?, into b: Clip?) -> Bool {
        guard let a = a, let b = b, b.transitionIn?.kind == .dissolve,
              (a.kind == .video || a.kind == .photo), (b.kind == .video || b.kind == .photo),
              abs(b.start - a.end) < 0.05, (b.transitionIn?.duration ?? 0) > 0.05 else { return false }
        return true
    }

    /// How long `a` keeps running after its end to dissolve into `b`.
    private static func tail(of a: Clip, into b: Clip) -> Double {
        guard let t = b.transitionIn else { return 0 }
        var ext = t.duration / 2
        if a.kind == .video {
            if a.speedCurve != nil { return 0 }
            if let sd = a.sourceDuration {
                ext = min(ext, max(0, (sd - (a.sourceIn + a.duration * a.speed)) / a.speed))
            }
        }
        return ext
    }

    private static func end(of track: AVMutableCompositionTrack) -> Double {
        let r = track.timeRange
        return r.isValid ? r.end.seconds : 0
    }

    /// Inserts an explicit source range scaled to `length`.
    private static func insertRange(
        from sourceTrack: AVAssetTrack,
        sourceDuration: CMTime,
        sourceStart: Double,
        sourceLength: Double,
        into track: AVMutableCompositionTrack,
        at: CMTime,
        length: CMTime
    ) -> Bool {
        let s = ct(max(0, sourceStart))
        var l = ct(sourceLength)
        let available = CMTimeSubtract(sourceDuration, s)
        if l > available { l = available }
        guard l > .zero else { return false }
        do {
            try track.insertTimeRange(CMTimeRange(start: s, duration: l), of: sourceTrack, at: at)
        } catch {
            lastInsertError = (error as NSError).localizedDescription + " \((error as NSError).code)"
            return false
        }
        if CMTimeCompare(l, length) != 0 {
            track.scaleTimeRange(CMTimeRange(start: at, duration: l), toDuration: length)
        }
        return true
    }

    /// Volume with optional fade in/out ramps for one clip.
    private static func applyVolume(_ params: AVMutableAudioMixInputParameters, clip: Clip, at: CMTime, length: CMTime) {
        let v = Float(clip.volume)
        let total = length.seconds
        let fi = min(max(clip.fadeIn ?? 0, 0), total / 2)
        let fo = min(max(clip.fadeOut ?? 0, 0), total / 2)
        if fi > 0.01 {
            params.setVolumeRamp(fromStartVolume: 0, toEndVolume: v, timeRange: CMTimeRange(start: at, duration: ct(fi)))
        } else {
            params.setVolume(v, at: at)
        }
        if fo > 0.01 {
            let start = CMTimeAdd(at, ct(total - fo))
            if fi <= 0.01 || total - fo > fi {
                params.setVolumeRamp(fromStartVolume: v, toEndVolume: 0, timeRange: CMTimeRange(start: start, duration: ct(fo)))
            }
        }
    }

    /// Inserts the clip's source range (scaled for speed) at `at`. Returns false if nothing was inserted.
    private static var lastInsertError = ""

    private static func insert(
        from sourceTrack: AVAssetTrack,
        sourceDuration: CMTime,
        clip: Clip,
        into track: AVMutableCompositionTrack,
        at: CMTime,
        length: CMTime
    ) -> Bool {
        if let curve = clip.speedCurve, curve.count > 1 {
            return insertCurved(from: sourceTrack, sourceDuration: sourceDuration, clip: clip, curve: curve, into: track, at: at, length: length)
        }
        let sourceStart = ct(clip.sourceIn)
        var sourceLength = ct(clip.duration * clip.speed)
        let available = CMTimeSubtract(sourceDuration, sourceStart)
        if sourceLength > available { sourceLength = available }
        guard sourceLength > .zero else { return false }
        do {
            try track.insertTimeRange(CMTimeRange(start: sourceStart, duration: sourceLength), of: sourceTrack, at: at)
        } catch {
            lastInsertError = (error as NSError).localizedDescription + " \((error as NSError).code)"
            return false
        }
        if abs(clip.speed - 1) > 0.001 {
            track.scaleTimeRange(CMTimeRange(start: at, duration: sourceLength), toDuration: length)
        }
        return true
    }

    /// Speed ramp: equal timeline slices, each showing a share of the source set by the curve.
    private static func insertCurved(
        from sourceTrack: AVAssetTrack,
        sourceDuration: CMTime,
        clip: Clip,
        curve: [Double],
        into track: AVMutableCompositionTrack,
        at: CMTime,
        length: CMTime
    ) -> Bool {
        let n = 24
        let available = max(0, sourceDuration.seconds - clip.sourceIn)
        let sourceLength = min(clip.duration * clip.speed, available)
        guard sourceLength > 0.01 else { return false }
        let slices = SpeedCurves.sourceSlices(curve, segments: n, sourceLength: sourceLength)
        let total = length.seconds
        var src = clip.sourceIn
        var cursor = at
        for i in 0..<n {
            let s = CMTime(seconds: src, preferredTimescale: 6000)
            let l = CMTime(seconds: slices[i], preferredTimescale: 6000)
            // Timeline end of this slice, computed from the clip start so rounding never drifts.
            let sliceEnd = CMTimeAdd(at, CMTime(seconds: total * Double(i + 1) / Double(n), preferredTimescale: 6000))
            let target = CMTimeSubtract(sliceEnd, cursor)
            guard l > .zero, target > .zero else { continue }
            do {
                try track.insertTimeRange(CMTimeRange(start: s, duration: l), of: sourceTrack, at: cursor)
            } catch {
                lastInsertError = (error as NSError).localizedDescription + " \((error as NSError).code)"
                return i > 0
            }
            track.scaleTimeRange(CMTimeRange(start: cursor, duration: l), toDuration: target)
            cursor = sliceEnd
            src += slices[i]
        }
        return true
    }

    /// Extends a track with an empty range so the next insert lands at `time`.
    private static func pad(_ track: AVMutableCompositionTrack, to time: CMTime) {
        let range = track.timeRange
        let end = range.isValid ? range.end : .zero
        if time > end {
            track.insertEmptyTimeRange(CMTimeRange(start: end, end: time))
        }
    }

    /// Contiguous instructions from 0 to `duration`, one per span with a constant set of layers.
    private static func instructions(for placed: [PlacedLayer], duration: CMTime) -> [SXInstruction] {
        var bounds: [CMTime] = [.zero, duration]
        for p in placed {
            bounds.append(p.range.start)
            bounds.append(p.range.end)
        }
        let sorted = bounds
            .filter { $0 >= .zero && $0 <= duration }
            .sorted()
        var unique: [CMTime] = []
        for t in sorted where unique.last.map({ $0 != t }) ?? true {
            unique.append(t)
        }

        var result: [SXInstruction] = []
        var i = 0
        while i + 1 < unique.count {
            let a = unique[i]
            let b = unique[i + 1]
            let active = placed.filter { $0.range.start <= a && a < $0.range.end }
            let isText: (PlacedLayer) -> Bool = { p in
                if case .text = p.layer.source { return true }
                return false
            }
            let isSticker: (PlacedLayer) -> Bool = { p in
                if case .sticker = p.layer.source { return true }
                return false
            }
            let ordered = active.filter { $0.layer.isMain }
                + active.filter { !$0.layer.isMain && !$0.layer.isGraphic }
                + active.filter { isSticker($0) }
                + active.filter { isText($0) }
            result.append(SXInstruction(timeRange: CMTimeRange(start: a, end: b), layers: ordered.map { $0.layer }))
            i += 1
        }
        return result
    }

    private func source(_ assetID: String) async -> Source? {
        if let cached = sources[assetID] { return cached }
        let asset = AVURLAsset(url: MediaStore.url(for: assetID))
        do {
            let video = try await asset.loadTracks(withMediaType: .video).first
            let audio = try await asset.loadTracks(withMediaType: .audio).first
            let duration = try await asset.load(.duration)
            var orientation = CGImagePropertyOrientation.up.rawValue
            if let video = video {
                let t = try await video.load(.preferredTransform)
                orientation = Self.orientation(for: t).rawValue
            }
            let s = Source(asset: asset, video: video, audio: audio, duration: duration, orientation: orientation)
            sources[assetID] = s
            return s
        } catch {
            notes.append("load error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Maps a track's preferred transform to the image orientation that displays it upright.
    static func orientation(for t: CGAffineTransform) -> CGImagePropertyOrientation {
        let a = t.a.rounded(), b = t.b.rounded(), c = t.c.rounded(), d = t.d.rounded()
        if a == 0 && b == 1 && c == -1 && d == 0 { return .right }
        if a == 0 && b == -1 && c == 1 && d == 0 { return .left }
        if a == -1 && b == 0 && c == 0 && d == -1 { return .down }
        return .up
    }
}
