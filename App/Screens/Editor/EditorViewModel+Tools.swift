import AVFoundation
import SwiftUI
import UIKit
import SCYDECore

enum EditorSheet: String, Identifiable {
    case speed, text, look, voiceover, voiceFX, cover, transform, transition, volume, chroma
    var id: String { rawValue }
}

/// Editing tools: speed, text, looks, cut-out, captions, AutoCut, audio and covers.
extension EditorViewModel {

    // MARK: Selection helpers

    var selectedIsVisual: Bool {
        guard let c = selectedClip else { return false }
        return c.kind == .video || c.kind == .photo
    }

    var selectedIsText: Bool { selectedClip?.kind == .text }
    var selectedIsAudio: Bool { selectedClip?.kind == .audio }
    var selectedHasSpeed: Bool { selectedClip?.kind == .video || selectedClip?.kind == .audio }

    /// The visual clip a look tool should act on: the selection, or the main clip under the playhead.
    var lookTarget: Clip? {
        if let c = selectedClip, c.kind == .video || c.kind == .photo { return c }
        return project.clip(at: playhead, role: .main)
    }

    // MARK: Speed

    func setSpeed(_ speed: Double) {
        guard let id = selection else { return }
        perform("Speed") { $0.setSpeed(id, to: speed) }
    }

    // MARK: Text

    func addText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var newID: UUID?
        let at = playhead
        perform("Add text") { p in
            newID = p.addClip(Clip(kind: .text, name: String(trimmed.prefix(24)), duration: 3, text: trimmed), role: .text, at: at)
            return true
        }
        if let id = newID { selection = id }
        Haptics.light()
    }

    func updateText(_ text: String) {
        guard let id = selection else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        perform("Edit text") { p in
            p.updateClip(id) { c in
                c.text = trimmed
                c.name = String(trimmed.prefix(24))
            }
        }
    }

    // MARK: Looks (one undo step per sheet session)

    func beginLook() {
        stopPlayback()
        history.beginTransaction()
    }

    func previewLook(clipID: UUID, filter: String?, adjust: Adjustments?) {
        history.revise { p in
            p.updateClip(clipID) { c in
                c.filter = (filter == "original") ? nil : filter
                c.adjust = (adjust?.isNeutral ?? true) ? nil : adjust
            }
        }
        scheduleRebuild()
    }

    func endLook() {
        history.commitTransaction("Look")
        didEdit()
    }

    /// Analyses the frame under the playhead and returns suggested adjustments.
    func suggestedAdjustments(for clip: Clip) async -> Adjustments {
        guard let assetID = clip.assetID else { return Adjustments(contrast: 1.06, saturation: 1.12) }
        let t = clip.sourceIn + max(0, playhead - clip.start) * clip.speed
        guard let image = await ThumbnailCache.shared.image(assetID: assetID, kind: clip.kind, at: t),
              let cg = image.cgImage else {
            return Adjustments(contrast: 1.06, saturation: 1.12)
        }
        return Looks.autoAdjust(for: CIImage(cgImage: cg), context: CIContext())
    }

    // MARK: Cut-out

    func toggleCutout() {
        guard let c = selectedClip, c.kind == .video || c.kind == .photo else {
            showToast("Select a video or photo first")
            return
        }
        let on = !(c.removeBackground ?? false)
        perform(on ? "Remove background" : "Restore background") { p in
            p.updateClip(c.id) { $0.removeBackground = on ? true : nil }
        }
        showToast(on ? "Background removed" : "Background restored")
    }

    // MARK: Audio

    func importMusic(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased()
        let id = MediaStore.newAssetID(ext: ext)
        do {
            try FileManager.default.copyItem(at: url, to: MediaStore.url(for: id))
        } catch {
            showToast("Could not read that file")
            return
        }
        let name = url.deletingPathExtension().lastPathComponent
        Task { [weak self] in
            let asset = AVURLAsset(url: MediaStore.url(for: id))
            let seconds = (try? await asset.load(.duration))?.seconds ?? 0
            guard let self = self else { return }
            guard seconds.isFinite, seconds > 0.2 else {
                self.showToast("That file has no playable audio")
                return
            }
            let at = self.playhead
            var newID: UUID?
            self.perform("Add music") { p in
                newID = p.addClip(Clip(kind: .audio, name: String(name.prefix(24)), assetID: id, sourceDuration: seconds, duration: seconds), role: .audio, at: at)
                return true
            }
            self.selection = newID
            Haptics.success()
        }
    }

    func addVoiceOver(assetID: String, duration: Double, at start: Double) {
        var newID: UUID?
        perform("Voice-over") { p in
            newID = p.addClip(Clip(kind: .audio, name: "Voice-over", assetID: assetID, sourceDuration: duration, duration: duration), role: .audio, at: start)
            return true
        }
        selection = newID
        Haptics.success()
    }

    func applyVoiceEffect(_ preset: VoicePreset) async {
        guard let c = selectedClip, c.kind == .audio, let assetID = c.assetID else {
            showToast("Select an audio clip first")
            return
        }
        busyMessage = "Applying \(preset.title)"
        defer { busyMessage = nil }
        do {
            let result = try await VoiceFX.render(input: MediaStore.url(for: assetID), preset: preset)
            perform("Voice effect") { p in
                p.updateClip(c.id) { clip in
                    clip.assetID = result.assetID
                    clip.sourceDuration = result.duration
                    clip.name = "\(c.name) · \(preset.title)"
                }
            }
            Haptics.success()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: Auto captions

    func generateCaptions() async {
        guard hasPlayableMedia else {
            showToast("Import a video with speech first")
            return
        }
        stopPlayback()
        busyMessage = "Listening for speech"
        defer { busyMessage = nil }
        do {
            let url = try await exportAudioTrack()
            let lines = try await Captioner.transcribe(url: url)
            try? FileManager.default.removeItem(at: url)
            perform("Auto captions") { p in
                // Replace previous captions so they never stack.
                if let ti = p.tracks.firstIndex(where: { $0.role == .text }) {
                    p.tracks[ti].clips.removeAll { $0.name.hasPrefix("Caption") }
                }
                var lastEnd = 0.0
                for line in lines {
                    let start = max(line.start, lastEnd)
                    let length = max(0.3, line.duration - (start - line.start))
                    p.addClip(Clip(kind: .text, name: "Caption", duration: length, text: line.text), role: .text, at: start)
                    lastEnd = start + length
                }
                return true
            }
            showToast("Added \(lines.count) captions")
            Haptics.success()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    /// Mixes the project's audio into a temporary M4A on the project timeline.
    private func exportAudioTrack() async throws -> URL {
        guard let built = await builder.build(project, renderSize: CGSize(width: 360, height: 640)),
              built.composition.tracks(withMediaType: .audio).isEmpty == false else {
            throw Captioner.Failure.noSpeech
        }
        guard let session = AVAssetExportSession(asset: built.composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw Captioner.Failure.unavailable
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("captions-\(UUID().uuidString).m4a")
        session.outputURL = url
        session.outputFileType = .m4a
        session.audioMix = built.audioMix
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { c.resume() }
        }
        guard session.status == .completed else {
            throw session.error ?? Captioner.Failure.noSpeech
        }
        return url
    }

    // MARK: AutoCut (remove silences from the main track)

    func autoCut() async {
        let mains = project.tracks.first(where: { $0.role == .main })?.clips.filter { $0.kind == .video && $0.assetID != nil } ?? []
        guard !mains.isEmpty else {
            showToast("Import a video first")
            return
        }
        stopPlayback()
        busyMessage = "Finding silences"
        defer { busyMessage = nil }

        var spans: [ClosedRange<Double>] = []
        for clip in mains {
            guard let assetID = clip.assetID else { continue }
            let sourceRange = clip.sourceIn...(clip.sourceIn + clip.duration * clip.speed)
            let silent = await AudioAnalysis.silences(url: MediaStore.url(for: assetID), range: sourceRange)
            for s in silent {
                // Keep a little breathing room on both sides of each cut.
                let a = clip.start + (s.lowerBound - clip.sourceIn) / clip.speed + 0.12
                let b = clip.start + (s.upperBound - clip.sourceIn) / clip.speed - 0.12
                if b - a > 0.25 { spans.append(a...b) }
            }
        }
        guard !spans.isEmpty else {
            showToast("No long silences found")
            return
        }
        let ordered = spans.sorted { $0.lowerBound > $1.lowerBound }
        var removed = 0
        perform("AutoCut") { p in
            var changed = false
            for span in ordered {
                if let c = p.clip(at: span.lowerBound + 0.001, role: .main), p.cut(c.id, from: span.lowerBound, to: span.upperBound) {
                    changed = true
                    removed += 1
                }
            }
            return changed
        }
        showToast(removed > 0 ? "Removed \(removed) silent parts" : "No long silences found")
        if removed > 0 { Haptics.success() }
    }

    // MARK: Cover

    /// The composed frame under the playhead (with looks, captions and cut-outs).
    func coverFrame() async -> UIImage? {
        let size = ExportSettings(resolution: .p1080).pixelSize(for: project.aspect)
        guard let built = await builder.build(project, renderSize: CGSize(width: size.width, height: size.height)) else {
            return previewImage
        }
        let generator = AVAssetImageGenerator(asset: built.composition)
        generator.videoComposition = built.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let t = min(playhead, max(0, built.duration - 0.05))
        do {
            let result = try await generator.image(at: CMTime(seconds: t, preferredTimescale: 600))
            return UIImage(cgImage: result.image)
        } catch {
            return nil
        }
    }
}
