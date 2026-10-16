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
    static let mainAudioID: CMPersistentTrackID = 11
    static let overlayAudioID: CMPersistentTrackID = 12
    static let musicAudioID: CMPersistentTrackID = 13

    private var sources: [String: Source] = [:]

    static func ct(_ seconds: Double) -> CMTime {
        CMTime(seconds: max(0, seconds), preferredTimescale: 600)
    }

    func build(_ project: Project, renderSize: CGSize, fps: Int? = nil) async -> Output? {
        let composition = AVMutableComposition()
        guard
            let mainV = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Self.mainVideoID),
            let overV = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Self.overlayVideoID),
            let mainA = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Self.mainAudioID),
            let overA = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Self.overlayAudioID),
            let musicA = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Self.musicAudioID)
        else { return nil }

        var placed: [PlacedLayer] = []
        let mainParams = AVMutableAudioMixInputParameters(track: mainA)
        let overParams = AVMutableAudioMixInputParameters(track: overA)
        let musicParams = AVMutableAudioMixInputParameters(track: musicA)

        let visualRoles: [(Track.Role, AVMutableCompositionTrack, AVMutableCompositionTrack, AVMutableAudioMixInputParameters)] = [
            (.main, mainV, mainA, mainParams),
            (.overlay, overV, overA, overParams),
        ]

        for (role, vTrack, aTrack, params) in visualRoles {
            let clips = project.tracks.first(where: { $0.role == role })?.clips ?? []
            for clip in clips where clip.kind == .video || clip.kind == .photo {
                guard let assetID = clip.assetID else { continue }
                let at = Self.ct(clip.start)
                let length = Self.ct(clip.duration)
                let range = CMTimeRange(start: at, duration: length)

                if clip.kind == .photo {
                    placed.append(PlacedLayer(range: range, layer: SXLayer(source: .photo(assetID: assetID), isMain: role == .main)))
                    continue
                }

                guard let src = await source(assetID), let video = src.video else { continue }
                Self.pad(vTrack, to: at)
                let inserted = Self.insert(
                    from: video, sourceDuration: src.duration, clip: clip, into: vTrack, at: at, length: length
                )
                guard inserted else { continue }
                placed.append(PlacedLayer(
                    range: range,
                    layer: SXLayer(source: .video(trackID: vTrack.trackID, orientation: src.orientation), isMain: role == .main)
                ))
                if let audio = src.audio {
                    Self.pad(aTrack, to: at)
                    if Self.insert(from: audio, sourceDuration: src.duration, clip: clip, into: aTrack, at: at, length: length) {
                        params.setVolume(Float(clip.volume), at: at)
                    }
                }
            }
        }

        // Audio-only clips (music, voice-over).
        let audioClips = project.tracks.first(where: { $0.role == .audio })?.clips ?? []
        for clip in audioClips {
            guard let assetID = clip.assetID, let src = await source(assetID), let audio = src.audio else { continue }
            let at = Self.ct(clip.start)
            Self.pad(musicA, to: at)
            if Self.insert(from: audio, sourceDuration: src.duration, clip: clip, into: musicA, at: at, length: Self.ct(clip.duration)) {
                musicParams.setVolume(Float(clip.volume), at: at)
            }
        }

        // Keep the main video track as long as the edit so trailing photos still render.
        let total = Self.ct(project.duration)
        Self.pad(mainV, to: total)

        for track in [overV, mainA, overA, musicA] where track.segments.isEmpty {
            composition.removeTrack(track)
        }

        let duration = composition.duration
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

    /// Inserts the clip's source range (scaled for speed) at `at`. Returns false if nothing was inserted.
    private static func insert(
        from sourceTrack: AVAssetTrack,
        sourceDuration: CMTime,
        clip: Clip,
        into track: AVMutableCompositionTrack,
        at: CMTime,
        length: CMTime
    ) -> Bool {
        let sourceStart = ct(clip.sourceIn)
        var sourceLength = ct(clip.duration * clip.speed)
        let available = CMTimeSubtract(sourceDuration, sourceStart)
        if sourceLength > available { sourceLength = available }
        guard sourceLength > .zero else { return false }
        do {
            try track.insertTimeRange(CMTimeRange(start: sourceStart, duration: sourceLength), of: sourceTrack, at: at)
        } catch {
            return false
        }
        if abs(clip.speed - 1) > 0.001 {
            track.scaleTimeRange(CMTimeRange(start: at, duration: sourceLength), toDuration: length)
        }
        return true
    }

    /// Extends a track with an empty range so the next insert lands at `time`.
    private static func pad(_ track: AVMutableCompositionTrack, to time: CMTime) {
        let end = track.timeRange.end
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
            let ordered = active.filter { $0.layer.isMain } + active.filter { !$0.layer.isMain }
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
            let s = Source(video: video, audio: audio, duration: duration, orientation: orientation)
            sources[assetID] = s
            return s
        } catch {
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
