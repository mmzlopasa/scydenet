import AVFoundation
import SwiftUI
import UIKit
import SCYDECore

/// Transform, keyframes, transitions, volume/fades, chroma key and subtitles.
extension EditorViewModel {

    // MARK: Transform

    var selectedCanTransition: Bool {
        guard let c = selectedClip, c.kind == .video || c.kind == .photo,
              let loc = project.locate(c.id), project.tracks[loc.track].role == .main else { return false }
        return loc.clip > 0
    }

    func transformAtPlayhead(_ clip: Clip) -> ClipTransform {
        LiveTransforms.shared.get(clip.id) ?? clip.transform(at: min(max(playhead, clip.start), clip.end))
    }

    func keyframeAtPlayhead(_ clip: Clip) -> Bool {
        let local = playhead - clip.start
        return clip.keyframes?.contains { abs($0.time - local) < 0.05 } ?? false
    }

    /// Live update while dragging (no rebuild, no undo step).
    func liveTransform(_ id: UUID, _ t: ClipTransform) {
        stopPlayback()
        LiveTransforms.shared.set(id, t)
        refreshFrame()
    }

    /// Commits a transform: keyframe at the playhead if the clip is animated, otherwise static.
    func applyTransform(_ id: UUID, _ t: ClipTransform) {
        LiveTransforms.shared.set(id, nil)
        let time = playhead
        perform("Transform") { p in
            guard let c = p.clip(id) else { return false }
            if let frames = c.keyframes, !frames.isEmpty {
                return p.setKeyframe(id, at: time, transform: t)
            }
            return p.updateClip(id) { $0.transform = t.isIdentity ? nil : t }
        }
        refreshFrame()
    }

    func addKeyframe(_ id: UUID) {
        guard let c = project.clip(id) else { return }
        let t = transformAtPlayhead(c)
        let time = playhead
        perform("Add keyframe") { $0.setKeyframe(id, at: time, transform: t) }
        Haptics.light()
    }

    func removeKeyframe(_ id: UUID) {
        let time = playhead
        perform("Remove keyframe") { $0.removeKeyframe(id, near: time) }
        Haptics.light()
    }

    func resetTransform(_ id: UUID) {
        LiveTransforms.shared.set(id, nil)
        perform("Reset transform") { p in
            p.updateClip(id) { c in
                c.transform = nil
                c.keyframes = nil
            }
        }
    }

    /// Re-renders the paused frame after a live change, without rebuilding the composition.
    func refreshFrame() {
        guard !isPlaying, let item = player.currentItem, let vc = item.videoComposition,
              let copy = vc.mutableCopy() as? AVVideoComposition else { return }
        item.videoComposition = copy
    }

    // MARK: Transitions

    func setTransition(_ id: UUID, _ transition: ClipTransition?) {
        perform(transition == nil ? "Remove transition" : "Transition") { p in
            p.updateClip(id) { $0.transitionIn = transition }
        }
    }

    func applyTransitionToAll(_ transition: ClipTransition?) {
        guard let main = project.tracks.first(where: { $0.role == .main }) else { return }
        let ids = main.clips.dropFirst().map { $0.id }
        perform("Transitions") { p in
            var changed = false
            for id in ids {
                if p.updateClip(id, { $0.transitionIn = transition }) { changed = true }
            }
            return changed
        }
        showToast(transition == nil ? "Transitions removed" : "Applied to every cut")
    }

    // MARK: Volume and fades

    func setAudio(_ id: UUID, volume: Double, fadeIn: Double, fadeOut: Double) {
        perform("Volume") { p in
            p.updateClip(id) { c in
                c.volume = min(max(volume, 0), 2)
                c.fadeIn = fadeIn > 0.01 ? fadeIn : nil
                c.fadeOut = fadeOut > 0.01 ? fadeOut : nil
            }
        }
    }

    // MARK: Chroma key

    func setChroma(_ id: UUID, _ key: ChromaKey?) {
        perform(key == nil ? "Remove chroma key" : "Chroma key") { p in
            p.updateClip(id) { $0.chromaKey = key }
        }
    }

    // MARK: Subtitles

    var hasTextClips: Bool {
        project.tracks.first(where: { $0.role == .text })?.clips.isEmpty == false
    }

    /// Writes the text clips to a temporary .srt for sharing.
    func subtitlesFile() -> URL? {
        let srt = Subtitles.srt(from: project)
        guard !srt.isEmpty else { return nil }
        let safe = project.name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe.isEmpty ? "captions" : safe).srt")
        do {
            try srt.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    func importSubtitles(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            showToast("Could not read that file")
            return
        }
        let cues = Subtitles.parse(text)
        guard !cues.isEmpty else {
            showToast("No subtitles found in that file")
            return
        }
        perform("Import subtitles") { p in
            if let ti = p.tracks.firstIndex(where: { $0.role == .text }) {
                p.tracks[ti].clips.removeAll { $0.name.hasPrefix("Caption") }
            }
            var lastEnd = 0.0
            for cue in cues {
                let start = max(cue.start, lastEnd)
                let length = max(0.3, cue.end - start)
                p.addClip(Clip(kind: .text, name: "Caption", duration: length, text: cue.text), role: .text, at: start)
                lastEnd = start + length
            }
            return true
        }
        showToast("Imported %d subtitles".locf(cues.count))
        Haptics.success()
    }
}
