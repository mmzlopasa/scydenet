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
        let project = Project(name: "Project \(projects.count + 1)", aspect: aspect)
        save(project)
        reload()
        openProject = project
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
