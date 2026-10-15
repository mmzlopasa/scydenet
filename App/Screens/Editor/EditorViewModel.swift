import PhotosUI
import QuartzCore
import SwiftUI
import UIKit
import SCYDECore

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var history: History<Project>
    @Published var playhead: Double = 0 {
        didSet { if playhead != oldValue { schedulePreview() } }
    }
    @Published var selection: UUID?
    @Published var pxPerSecond: CGFloat = 64
    @Published private(set) var isPlaying = false
    @Published var showExport = false
    @Published private(set) var previewImage: UIImage?
    @Published private(set) var importing = false
    @Published private(set) var toast: String?
    @Published var pickerItems: [PhotosPickerItem] = [] {
        didSet {
            guard !pickerItems.isEmpty else { return }
            let items = pickerItems
            pickerItems = []
            importItems(items)
        }
    }

    var project: Project { history.present }

    private let onSave: (Project) -> Void
    private let frames = FrameProvider()
    private let fallbackFrame: UIImage?
    private var playTask: Task<Void, Never>?
    private var glideTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var previewInFlight = false
    private var previewDirty = false
    private var dirty = false
    private var lastSnapped = false

    init(project: Project, onSave: @escaping (Project) -> Void) {
        self.history = History(project)
        self.onSave = onSave
        self.fallbackFrame = Launch.demo ? Demo.previewImage() : nil
    }

    // MARK: Lifecycle

    func onAppear() {
        if let t = Launch.playhead { playhead = clampTime(t) }
        if let i = Launch.selectIndex,
           let main = project.tracks.first(where: { $0.role == .main }),
           i >= 0, i < main.clips.count {
            selection = main.clips[i].id
        }
        schedulePreview()
        if Launch.screen == "export" {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                self?.showExport = true
            }
        }
    }

    // MARK: Derived state

    var duration: Double { project.duration }
    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }

    var visibleTracks: [Track] {
        let order: [Track.Role] = [.text, .overlay, .main, .audio]
        return order.compactMap { (role: Track.Role) -> Track? in
            guard let t = project.tracks.first(where: { $0.role == role }) else { return nil }
            return (role == .main || !t.clips.isEmpty) ? t : nil
        }
    }

    var selectedClip: Clip? { selection.flatMap { project.clip($0) } }

    var splitTarget: UUID? {
        let m = Project.minClipDuration
        if let c = selectedClip, playhead > c.start + m, playhead < c.end - m { return c.id }
        if let c = project.clipUnder(playhead), playhead > c.start + m, playhead < c.end - m { return c.id }
        return nil
    }

    var canSplit: Bool { splitTarget != nil }

    var selectedIsMuted: Bool { (selectedClip?.volume ?? 1) == 0 }

    var canMute: Bool {
        guard let c = selectedClip else { return false }
        return c.kind == .video || c.kind == .audio
    }

    // MARK: Editing

    private func perform(_ name: String, _ change: (inout Project) -> Bool) {
        if history.perform(name, change) { didEdit() }
    }

    private func didEdit() {
        if let s = selection, project.clip(s) == nil { selection = nil }
        if playhead > duration { playhead = duration }
        dirty = true
        scheduleSave()
        schedulePreview()
    }

    func undo() {
        guard canUndo else { return }
        Haptics.light()
        history.undo()
        didEdit()
    }

    func redo() {
        guard canRedo else { return }
        Haptics.light()
        history.redo()
        didEdit()
    }

    func select(_ id: UUID) {
        Haptics.selection()
        withAnimation(SX.spring) {
            selection = (selection == id) ? nil : id
        }
    }

    func clearSelection() {
        guard selection != nil else { return }
        withAnimation(SX.spring) { selection = nil }
    }

    func split() {
        guard let id = splitTarget else {
            showToast("Move the playhead over a clip to split")
            return
        }
        let t = playhead
        Haptics.light()
        perform("Split") { $0.split(id, at: t) != nil }
    }

    func duplicateSelected() {
        guard let id = selection else { return }
        var newID: UUID?
        perform("Duplicate") { p in
            newID = p.duplicate(id)
            return newID != nil
        }
        if let n = newID { selection = n }
        Haptics.light()
    }

    func deleteSelected() {
        guard let id = selection, let loc = project.locate(id) else { return }
        let ripple = project.tracks[loc.track].role == .main
        Haptics.medium()
        withAnimation(SX.spring) {
            perform("Delete") { $0.delete(id, ripple: ripple) }
            selection = nil
        }
    }

    func toggleMute() {
        guard let c = selectedClip else { return }
        let target: Double = c.volume == 0 ? 1 : 0
        perform(target == 0 ? "Mute" : "Unmute") { $0.setVolume(c.id, to: target) }
        showToast(target == 0 ? "Clip muted" : "Clip unmuted")
    }

    // MARK: Gestures (one undo step per drag)

    func beginEdit() {
        stopPlayback()
        glideTask?.cancel()
        history.beginTransaction()
        lastSnapped = false
    }

    func updateTrim(_ id: UUID, edge: TrimEdge, to raw: Double) {
        let targets = project.snapTargets(excluding: id, playhead: playhead)
        let r = Project.snap(raw, targets: targets, threshold: snapThreshold)
        noteSnap(r.snapped)
        history.revise { $0.trim(id, edge: edge, to: r.time) }
    }

    func updateMove(_ id: UUID, to raw: Double) {
        guard let clip = project.clip(id) else { return }
        let targets = project.snapTargets(excluding: id, playhead: playhead)
        let r = Project.snapMove(start: raw, duration: clip.duration, targets: targets, threshold: snapThreshold)
        noteSnap(r.snapped)
        history.revise { $0.move(id, toStart: r.time) }
    }

    func endEdit(_ name: String) {
        history.commitTransaction(name)
        didEdit()
    }

    private var snapThreshold: Double { Double(8 / max(pxPerSecond, 1)) }

    private func noteSnap(_ snapped: Bool) {
        if snapped && !lastSnapped { Haptics.light() }
        lastSnapped = snapped
    }

    // MARK: Playhead, scrubbing, playback

    func clampTime(_ t: Double) -> Double { min(max(t, 0), duration) }

    func beginScrub() {
        stopPlayback()
        glideTask?.cancel()
    }

    func scrub(to t: Double) {
        playhead = clampTime(t)
    }

    /// Ease-out glide after a flick, so the timeline feels like it has momentum.
    func glide(to target: Double) {
        glideTask?.cancel()
        let from = playhead
        let to = clampTime(target)
        guard abs(to - from) > 0.01 else { return }
        let length = 0.5
        let start = CACurrentMediaTime()
        glideTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                guard let self = self, !Task.isCancelled else { return }
                let p = min(1, (CACurrentMediaTime() - start) / length)
                let eased = 1 - pow(1 - p, 3)
                self.playhead = from + (to - from) * eased
                if p >= 1 { return }
            }
        }
    }

    func togglePlay() {
        if isPlaying { stopPlayback(); return }
        guard duration > 0 else {
            showToast("Import media to play")
            return
        }
        glideTask?.cancel()
        if playhead >= duration - 0.02 { playhead = 0 }
        isPlaying = true
        playTask = Task { [weak self] in
            var last = CACurrentMediaTime()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                guard let self = self, !Task.isCancelled else { return }
                let now = CACurrentMediaTime()
                let next = self.playhead + (now - last)
                last = now
                if next >= self.duration {
                    self.playhead = self.duration
                    self.stopPlayback()
                    return
                }
                self.playhead = next
            }
        }
    }

    func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        if isPlaying { isPlaying = false }
    }

    func zoom(to pps: CGFloat) {
        pxPerSecond = min(max(pps, 12), 400)
    }

    // MARK: Import

    func importItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        stopPlayback()
        withAnimation(SX.ease) { importing = true }
        Task { [weak self] in
            var added: [Clip] = []
            for item in items {
                if let clip = await MediaImporter.clip(from: item) { added.append(clip) }
            }
            guard let self = self else { return }
            withAnimation(SX.ease) { self.importing = false }
            guard !added.isEmpty else {
                self.showToast("Could not import that item")
                return
            }
            var firstID: UUID?
            self.perform(added.count == 1 ? "Import clip" : "Import \(added.count) clips") { p in
                for clip in added {
                    let id = p.addClip(clip, role: .main)
                    if firstID == nil { firstID = id }
                }
                return true
            }
            if let id = firstID, let c = self.project.clip(id) {
                self.playhead = c.start
            }
            Haptics.success()
            if added.count < items.count {
                self.showToast("Imported \(added.count) of \(items.count)")
            }
        }
    }

    // MARK: Export settings (saved with the project, not undoable)

    func updateExport(_ change: (inout ExportSettings) -> Void) {
        var p = project
        change(&p.export)
        guard p != project else { return }
        history.replacePresent(p)
        dirty = true
        scheduleSave()
    }

    // MARK: Preview frames (throttled: at most one request in flight)

    func schedulePreview() {
        previewDirty = true
        guard !previewInFlight else { return }
        runPreview()
    }

    private func runPreview() {
        previewDirty = false
        previewInFlight = true
        let time = playhead
        let snapshot = project
        Task { [weak self] in
            guard let self = self else { return }
            let image = await self.frames.frame(for: snapshot, at: time, fallback: self.fallbackFrame)
            self.previewImage = image
            self.previewInFlight = false
            if self.previewDirty { self.runPreview() }
        }
    }

    // MARK: Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self = self, !Task.isCancelled else { return }
            self.flushSave()
        }
    }

    func flushSave() {
        guard dirty else { return }
        dirty = false
        var p = project
        p.modifiedAt = Date()
        onSave(p)
    }

    // MARK: Toast

    func showToast(_ text: String) {
        withAnimation(SX.spring) { toast = text }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard let self = self else { return }
            if self.toast == text {
                withAnimation(SX.spring) { self.toast = nil }
            }
        }
    }
}

extension Track.Role {
    var laneHeight: CGFloat {
        switch self {
        case .main: return 58
        case .overlay: return 40
        case .audio: return 36
        case .text: return 30
        }
    }
}
