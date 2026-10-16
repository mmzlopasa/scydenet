import AVFoundation
import SwiftUI
import UIKit
import SCYDECore

/// Text styles, stickers, effects, masks, crop, blend, canvas, beats, reverse, freeze and speech.
extension EditorViewModel {

    // MARK: Selection helpers

    var selectedIsSticker: Bool { selectedClip?.kind == .sticker }
    var selectedIsGraphic: Bool { selectedClip?.kind == .text || selectedClip?.kind == .sticker }
    var selectedIsVideo: Bool { selectedClip?.kind == .video }

    var selectedIsOverlay: Bool {
        guard let id = selection, let loc = project.locate(id) else { return false }
        return project.tracks[loc.track].role == .overlay
    }

    /// The clip effects act on: the selection (visual, text or sticker) or the main clip under the playhead.
    var effectTarget: Clip? {
        if let c = selectedClip, c.kind != .audio { return c }
        return project.clip(at: playhead, role: .main)
    }

    /// One undoable change to a clip's non-timing properties.
    func editClip(_ id: UUID, _ name: String, _ change: (inout Clip) -> Void) {
        perform(name) { p in p.updateClip(id) { change(&$0) } }
    }

    // MARK: Text style

    func addStyledText(_ text: String, style: TextStyle) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var newID: UUID?
        let at = playhead
        perform("Add text") { p in
            var clip = Clip(kind: .text, name: String(trimmed.prefix(24)), duration: 3, text: trimmed)
            clip.textStyle = style == .caption ? nil : style
            newID = p.addClip(clip, role: .text, at: at)
            return true
        }
        if let id = newID { selection = id }
        Haptics.light()
    }

    func setTextStyle(_ id: UUID, _ style: TextStyle) {
        editClip(id, "Text style") { $0.textStyle = style }
    }

    // MARK: Stickers

    func addSticker(_ sticker: String) {
        if let c = selectedClip, c.kind == .sticker {
            editClip(c.id, "Replace sticker") { clip in
                clip.text = sticker
                clip.name = Self.stickerName(sticker)
            }
            Haptics.light()
            return
        }
        var newID: UUID?
        let at = playhead
        perform("Add sticker") { p in
            var clip = Clip(kind: .sticker, name: Self.stickerName(sticker), duration: 3, text: sticker)
            clip.textStyle = TextStyle(size: 3, color: 0xFFFFFF, background: .none, shadow: true, anchorY: 0, animIn: .pop, animOut: .fade, animDuration: 0.4)
            newID = p.addClip(clip, role: .sticker, at: at)
            return true
        }
        if let id = newID { selection = id }
        Haptics.light()
    }

    static func stickerName(_ s: String) -> String {
        s.hasPrefix("sf:") ? String(s.dropFirst(3)).replacingOccurrences(of: ".fill", with: "") : s
    }

    // MARK: Effects, masks, crop, blend

    func setEffect(_ id: UUID, _ effect: VideoEffect?) {
        editClip(id, effect == nil ? "Remove effect" : "Effect") { $0.effect = effect }
    }

    func setMask(_ id: UUID, _ mask: ClipMask?) {
        editClip(id, mask == nil ? "Remove mask" : "Mask") { $0.mask = mask }
    }

    func setCrop(_ id: UUID, _ crop: CropRect?) {
        editClip(id, "Crop") { $0.crop = (crop?.isFull ?? true) ? nil : crop }
    }

    func rotateQuarter(_ id: UUID) {
        editClip(id, "Rotate") { c in
            let t = ((c.quarterTurns ?? 0) + 1) % 4
            c.quarterTurns = t == 0 ? nil : t
            c.crop = nil
        }
        Haptics.light()
    }

    func flip(_ id: UUID, horizontal: Bool) {
        editClip(id, "Flip") { c in
            if horizontal {
                c.flipH = (c.flipH ?? false) ? nil : true
            } else {
                c.flipV = (c.flipV ?? false) ? nil : true
            }
        }
        Haptics.light()
    }

    func setBlend(_ id: UUID, _ mode: LayerBlend) {
        editClip(id, "Blend") { $0.blend = mode == .normal ? nil : mode }
    }

    func setOpacity(_ id: UUID, _ value: Double) {
        guard let c = project.clip(id) else { return }
        var t = transformAtPlayhead(c)
        t.opacity = min(max(value, 0), 1)
        applyTransform(id, t)
    }

    // MARK: Canvas

    func setAspect(_ aspect: CanvasAspect) {
        perform("Ratio") { $0.setAspect(aspect) }
    }

    func setBackground(_ bg: CanvasBackground?) {
        perform("Background") { p in
            let new = bg == .standard ? nil : bg
            guard p.background != new else { return false }
            p.background = new
            return true
        }
    }

    // MARK: Reverse, freeze, extract audio

    func reverseSelected() async {
        guard let c = selectedClip, c.kind == .video, let assetID = c.assetID else {
            showToast("Select a video clip first")
            return
        }
        stopPlayback()
        let range = c.sourceIn...(c.sourceIn + c.duration * c.speed)
        busyMessage = "Reversing"
        defer { busyMessage = nil }
        do {
            let result = try await VideoReverser.reverse(assetID: assetID, range: range) { _ in }
            perform("Reverse") { p in
                p.updateClip(c.id) { clip in
                    clip.assetID = result.assetID
                    clip.sourceIn = 0
                    clip.sourceDuration = result.duration
                    clip.reversed = (c.reversed ?? false) ? nil : true
                    clip.keyframes = nil
                }
            }
            showToast("Clip reversed")
            Haptics.success()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func freezeAtPlayhead() async {
        let target: Clip?
        if let c = selectedClip, c.kind == .video { target = c } else { target = project.clip(at: playhead, role: .main) }
        guard let c = target, c.kind == .video, let assetID = c.assetID,
              playhead >= c.start, playhead <= c.end else {
            showToast("Move the playhead over a video clip")
            return
        }
        stopPlayback()
        busyMessage = "Freezing frame"
        defer { busyMessage = nil }
        let sourceTime = c.sourceIn + (playhead - c.start) * c.speed
        guard let still = await FrameGrabber.still(assetID: assetID, at: sourceTime) else {
            showToast("Could not read that frame")
            return
        }
        let t = playhead
        var newID: UUID?
        perform("Freeze frame") { p in
            newID = p.freeze(c.id, at: t, frameAssetID: still, length: 3)
            return newID != nil
        }
        if let id = newID { selection = id }
        Haptics.success()
    }

    func extractAudio() {
        guard let c = selectedClip, c.kind == .video, let assetID = c.assetID else {
            showToast("Select a video clip first")
            return
        }
        perform("Extract audio") { p in
            var audio = Clip(
                kind: .audio,
                name: "\(c.name) · audio",
                assetID: assetID,
                sourceDuration: c.sourceDuration,
                sourceIn: c.sourceIn,
                duration: c.duration,
                speed: c.speed,
                volume: c.volume
            )
            audio.fadeIn = c.fadeIn
            audio.fadeOut = c.fadeOut
            p.addClip(audio, role: .audio, at: c.start)
            p.updateClip(c.id) { $0.volume = 0 }
            return true
        }
        showToast("Audio moved to its own track")
        Haptics.success()
    }

    // MARK: Beats and markers

    var markerCount: Int { project.markers?.count ?? 0 }

    func toggleMarkerAtPlayhead() {
        let t = playhead
        perform("Marker") { $0.toggleMarker(at: t) }
        Haptics.light()
    }

    func clearMarkers() {
        perform("Clear markers") { p in
            guard p.markers != nil else { return false }
            p.markers = nil
            return true
        }
    }

    /// Detects beats in the selected audio clip, the first music clip, or the main track's sound.
    func detectBeats(sensitivity: Double) async {
        var source: Clip?
        if let c = selectedClip, (c.kind == .audio || c.kind == .video), c.assetID != nil { source = c }
        if source == nil {
            source = project.tracks.first(where: { $0.role == .audio })?.clips.first { $0.assetID != nil }
        }
        if source == nil {
            source = project.tracks.first(where: { $0.role == .main })?.clips.first { $0.kind == .video && $0.assetID != nil }
        }
        guard let c = source, let assetID = c.assetID else {
            showToast("Add music or a video with sound first")
            return
        }
        stopPlayback()
        busyMessage = "Finding the beat"
        defer { busyMessage = nil }
        let range = c.sourceIn...(c.sourceIn + c.duration * c.speed)
        let found = await BeatDetector.beats(url: MediaStore.url(for: assetID), range: range, sensitivity: sensitivity)
        let times = found.map { c.start + ($0 - c.sourceIn) / c.speed }.filter { $0 >= c.start && $0 <= c.end }
        guard !times.isEmpty else {
            showToast("No clear beat found")
            return
        }
        perform("Beats") { $0.setMarkers(times) }
        showToast("Found %d beats".locf(times.count))
        Haptics.success()
    }

    func syncToBeats() {
        guard markerCount > 0 else {
            showToast("Add beat markers first")
            return
        }
        perform("Cut to beat") { $0.syncToMarkers() }
        showToast("Clips now cut on the beat")
        Haptics.success()
    }

    // MARK: Speed curve and stabilisation

    func setSpeedCurve(_ id: UUID, _ points: [Double]?) {
        editClip(id, points == nil ? "Constant speed" : "Speed curve") { $0.speedCurve = points }
    }

    func stabilizeSelected(strength: Double) async {
        guard let c = selectedClip, c.kind == .video, let assetID = c.assetID else {
            showToast("Select a video clip first")
            return
        }
        stopPlayback()
        busyMessage = "Stabilising"
        defer { busyMessage = nil }
        let range = c.sourceIn...(c.sourceIn + c.duration * c.speed)
        do {
            let result = try await Stabilizer.analyse(assetID: assetID, range: range, strength: strength)
            editClip(c.id, "Stabilise") { $0.stabilization = result }
            showToast("Clip stabilised")
            Haptics.success()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func removeStabilization() {
        guard let id = selection else { return }
        editClip(id, "Remove stabilisation") { $0.stabilization = nil }
    }

    func setMaskEnd(_ id: UUID, _ mask: ClipMask?) {
        editClip(id, "Mask animation") { $0.maskEnd = mask }
    }

    // MARK: Library media

    func addPackTrack(_ track: MediaPack.Track) async {
        busyMessage = "Downloading"
        defer { busyMessage = nil }
        guard let assetID = await MediaLibrary.shared.importToMedia(track.file) else {
            showToast("Could not download that track")
            return
        }
        let at = playhead
        var newID: UUID?
        perform("Add music") { p in
            newID = p.addClip(Clip(kind: .audio, name: "\(track.title) · \(track.author)", assetID: assetID, sourceDuration: track.duration, duration: track.duration), role: .audio, at: at)
            return true
        }
        selection = newID
        Haptics.success()
        showToast("Music: %@ (%@)".locf(track.author, track.license))
    }

    func addPackVideo(_ video: MediaPack.Video) async {
        busyMessage = "Downloading"
        defer { busyMessage = nil }
        guard let clip = await MediaLibrary.shared.clip(for: video, duration: video.duration, aspect: project.aspect) else {
            showToast("Could not download that clip")
            return
        }
        var newID: UUID?
        perform("Add library clip") { p in
            newID = p.addClip(clip, role: .main)
            return true
        }
        selection = newID
        if let id = newID, let c = project.clip(id) { playhead = c.start }
        Haptics.success()
    }

    func addSoundEffect(_ effect: SoundEffects.Effect) {
        do {
            let assetID = try SoundEffects.asset(effect)
            let at = playhead
            var newID: UUID?
            perform("Add sound effect") { p in
                newID = p.addClip(Clip(kind: .audio, name: effect.name, assetID: assetID, sourceDuration: effect.length, duration: effect.length), role: .audio, at: at)
                return true
            }
            selection = newID
            Haptics.light()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: Thumbnails

    /// A small frame to render live tool previews on: the clip under the playhead, or a sample.
    func frameForThumbnails() async -> UIImage {
        var target = selectedClip
        if target == nil || target?.assetID == nil || !(target?.kind == .video || target?.kind == .photo) {
            target = project.clip(at: playhead, role: .main) ?? project.tracks.first(where: { $0.role == .main })?.clips.first
        }
        if let c = target, let assetID = c.assetID, c.kind == .video || c.kind == .photo {
            let t = c.sourceTime(at: min(max(playhead, c.start), c.end))
            if let img = await ThumbnailCache.shared.image(assetID: assetID, kind: c.kind, at: t) { return img }
        }
        return Self.sampleFrame
    }

    static let sampleFrame: UIImage = {
        let size = CGSize(width: 160, height: 200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let colors = [UIColor(hex: 0x5A49E6).cgColor, UIColor(hex: 0xFFD76A).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            UIColor(white: 1, alpha: 0.9).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 50, y: 70, width: 60, height: 60))
            UIColor(hex: 0x1B1530, alpha: 0.6).setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 150, width: size.width, height: 50))
        }
    }()

    // MARK: Clip animation

    func setMotion(_ id: UUID, _ motion: ClipAnimation?) {
        editClip(id, "Animation") { $0.motion = (motion?.isNone ?? true) ? nil : motion }
    }

    // MARK: Text to speech

    func readAloud(_ text: String, language: String, rate: Double, pitch: Double) async {
        stopPlayback()
        busyMessage = "Creating voice"
        defer { busyMessage = nil }
        let at = (selectedClip?.kind == .text ? selectedClip?.start : nil) ?? playhead
        do {
            let renderer = SpeechRenderer()
            let result = try await renderer.render(text, language: language, rate: rate, pitch: pitch)
            var newID: UUID?
            perform("Text to speech") { p in
                newID = p.addClip(
                    Clip(kind: .audio, name: "Voice · \(String(text.prefix(18)))", assetID: result.assetID, sourceDuration: result.duration, duration: result.duration),
                    role: .audio,
                    at: at
                )
                return true
            }
            selection = newID
            Haptics.success()
        } catch {
            showToast(error.localizedDescription)
        }
    }
}
