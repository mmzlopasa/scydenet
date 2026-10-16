import PhotosUI
import SwiftUI
import SCYDECore

@MainActor
final class AppModel: ObservableObject {
    enum Appearance: String, CaseIterable, Identifiable {
        case auto, light, dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .auto: return "Auto"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var icon: String {
            switch self {
            case .auto: return "circle.lefthalf.filled"
            case .light: return "sun.max"
            case .dark: return "moon"
            }
        }

        var scheme: ColorScheme? {
            switch self {
            case .auto: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    @Published var appearance: Appearance {
        didSet {
            if Launch.theme == nil {
                UserDefaults.standard.set(appearance.rawValue, forKey: "appearance")
            }
        }
    }
    @Published private(set) var projects: [Project] = []
    @Published var openProject: Project?
    @Published var tab: AppTab = .edit
    @Published var showNewProject = false
    @Published var photoEditor: PhotoEditorEntry?
    @Published var showCollage = false
    @Published var showPlans = false
    @Published private(set) var toast: String?
    @Published var defaultAspect: CanvasAspect {
        didSet { UserDefaults.standard.set(defaultAspect.rawValue, forKey: "defaultAspect") }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "haptics") }
    }

    let store: ProjectStore
    let isDemo: Bool

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        isDemo = Launch.demo || Launch.sampleMedia
        store = ProjectStore(directory: docs.appendingPathComponent("Projects", isDirectory: true))
        if let t = Launch.theme, let a = Appearance(rawValue: t) {
            appearance = a
        } else {
            appearance = Appearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .auto
        }
        defaultAspect = CanvasAspect(rawValue: UserDefaults.standard.string(forKey: "defaultAspect") ?? "") ?? .portrait9x16
        hapticsEnabled = (UserDefaults.standard.object(forKey: "haptics") as? Bool) ?? true
        if let t = Launch.tab, let parsed = AppTab(rawValue: t) { tab = parsed }
        if Launch.screen == "settings" { tab = .me }
        if Launch.screen == "photo" { photoEditor = PhotoEditorEntry(tab: 0) }
        if Launch.screen == "collage" { showCollage = true }
        if Launch.screen == "plans" { showPlans = true }
        reload()
        if Launch.sampleMedia {
            Task { [weak self] in
                let project = await SampleMedia.makeProject()
                self?.openProject = project
            }
        } else if Launch.screen == "editor" || Launch.screen == "export" {
            openProject = isDemo ? Demo.editorProject() : Project(name: "Project 1")
        }
    }

    func reload() {
        projects = isDemo ? Demo.homeProjects() : store.list()
    }

    func createProject(aspect: CanvasAspect) {
        let project = Project(name: "Project %d".locf(projects.count + 1), aspect: aspect)
        save(project)
        reload()
        openProject = project
    }

    /// Imports the picked items and fills the template's slots in order.
    func createFromTemplate(_ template: ProjectTemplate, items: [PhotosPickerItem]) async -> Bool {
        var clips: [Clip] = []
        for item in items {
            if let clip = await MediaImporter.clip(from: item) { clips.append(clip) }
        }
        guard !clips.isEmpty else { return false }
        let project = Self.templateProject(template, clips: clips)
        save(project)
        reload()
        openProject = project
        return true
    }

    /// Builds the template with SCYDE's sample footage so it can be tried without picking media.
    func createFromTemplateWithSamples(_ template: ProjectTemplate) async -> Bool {
        let library = MediaLibrary.shared
        await library.load()
        let videos = library.videos(for: template.category.rawValue)
        guard !videos.isEmpty else { return false }
        var clips: [Clip] = []
        for (i, slot) in template.slots.enumerated() {
            let v = videos[i % videos.count]
            if let c = await library.clip(for: v, duration: slot, aspect: template.aspect) { clips.append(c) }
        }
        guard !clips.isEmpty else { return false }
        let project = Self.templateProject(template, clips: clips)
        save(project)
        reload()
        openProject = project
        return true
    }

    /// The template recipe applied to clips: slot lengths, look, transitions, motion and a styled title.
    nonisolated static func templateProject(_ template: ProjectTemplate, clips: [Clip]) -> Project {
        var project = Project(name: template.name.loc, aspect: template.aspect)
        for (i, imported) in clips.enumerated() {
            var clip = imported
            let slot = template.slots[i % template.slots.count]
            clip.duration = min(slot, clip.sourceDuration ?? slot)
            clip.filter = template.filter
            if i > 0, let kind = template.transition {
                clip.transitionIn = ClipTransition(kind: kind, duration: min(0.6, clip.duration))
            }
            let base = clip.transform ?? .identity
            if template.kenBurns {
                var end = base
                end.scale = base.scale * 1.14
                clip.keyframes = [
                    Keyframe(time: 0, transform: base),
                    Keyframe(time: clip.duration, transform: end),
                ]
            }
            project.addClip(clip, role: .main)
        }
        if let title = template.title {
            var t = Clip(kind: .text, name: "Title", duration: min(2.4, project.duration), text: title)
            t.textStyle = template.category.titleStyle
            project.addClip(t, role: .text, at: 0)
        }
        return project
    }

    func showToast(_ text: String) {
        withAnimation(SX.spring) { toast = text }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self = self, self.toast == text else { return }
            withAnimation(SX.spring) { self.toast = nil }
        }
    }

    /// Opens the editor where a timeline tool lives (most recent project, or a new one).
    func openEditorTool(_ name: String) {
        Haptics.light()
        if let recent = projects.first {
            open(recent)
            showToast("%@ is in the editor toolbar".locf(name.loc))
        } else {
            showNewProject = true
            showToast("Create a project, then use %@".locf(name.loc))
        }
    }

    /// Opens a tool straight away: in the latest project when it has media, otherwise in a new
    /// 9:16 project (tools that need footage ask for it first).
    func launchTool(_ action: EditorLaunchAction, needsMedia: Bool = false) {
        Haptics.light()
        let recent = projects.first(where: { p in p.tracks.contains { $0.role == .main && !$0.clips.isEmpty } })
        if needsMedia {
            guard let recent = recent else {
                showNewProject = true
                showToast("Pick a video first, then the tool opens")
                return
            }
            EditorLaunch.pending = action
            open(recent)
            return
        }
        EditorLaunch.pending = action
        if let recent = recent {
            open(recent)
        } else {
            createProject(aspect: .portrait9x16)
        }
    }

    /// New 9:16 project that starts with a library clip.
    func createWithPackVideo(_ video: MediaPack.Video) async {
        Haptics.medium()
        guard let clip = await MediaLibrary.shared.clip(for: video, duration: video.duration, aspect: .portrait9x16) else {
            showToast("Could not download the clip")
            return
        }
        var project = Project(name: "Project %d".locf(projects.count + 1), aspect: .portrait9x16)
        project.addClip(clip, role: .main)
        save(project)
        reload()
        openProject = project
    }

    func openPhotoEditor(tab: Int = 0) {
        Haptics.light()
        photoEditor = PhotoEditorEntry(tab: tab)
    }

    func comingSoon(_ feature: String) {
        Haptics.light()
        showToast("\(feature) arrives in a later build")
    }

    func open(_ project: Project) {
        openProject = project
    }

    func save(_ project: Project) {
        guard !isDemo else { return }
        try? store.save(project)
    }

    func closeEditor() {
        openProject = nil
        reload()
    }

    func duplicate(_ project: Project) {
        guard !isDemo else { return }
        var copy = project
        copy.id = UUID()
        copy.name = project.name + " copy"
        copy.createdAt = Date()
        copy.modifiedAt = Date()
        save(copy)
        reload()
    }

    func rename(_ project: Project, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isDemo, !trimmed.isEmpty else { return }
        var p = project
        p.name = trimmed
        p.modifiedAt = Date()
        save(p)
        reload()
    }

    func delete(_ project: Project) {
        guard !isDemo else { return }
        try? store.delete(id: project.id)
        reload()
    }
}

struct PhotoEditorEntry: Identifiable {
    let id = UUID()
    let tab: Int
}
