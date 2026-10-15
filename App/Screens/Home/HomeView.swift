import SwiftUI
import SCYDECore

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @State private var aspect: CanvasAspect = .portrait9x16
    @State private var renaming: Project?
    @State private var renameText = ""
    @State private var showRename = false

    private let formats: [CanvasAspect] = [.portrait9x16, .landscape16x9, .square1x1, .portrait4x5]
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, 34)
                    hero
                        .padding(.bottom, 34)
                    SectionLabel(index: "01", title: "Format")
                        .padding(.bottom, 14)
                    formatRow
                        .padding(.bottom, 16)
                    createButton
                        .padding(.bottom, 44)
                    SectionLabel(
                        index: "02",
                        title: "Projects",
                        trailing: app.projects.isEmpty ? nil : "\(app.projects.count)"
                    )
                    .padding(.bottom, 14)
                    projects
                        .padding(.bottom, 40)
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .alert("Rename project", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let p = renaming { app.rename(p, to: renameText) }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Wordmark(size: 26)
            Spacer()
            Menu {
                Picker("Appearance", selection: $app.appearance) {
                    ForEach(AppModel.Appearance.allCases) { option in
                        Label(option.label, systemImage: option.icon).tag(option)
                    }
                }
            } label: {
                GlassIcon(systemName: app.appearance.icon)
            }
            .accessibilityLabel("Appearance")
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Photo & Video Editor")
            Text("What are we\nmaking today?")
                .font(.display(38))
                .foregroundColor(SX.C.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("Cut video, shape photos and add sound. Everything stays on your phone.")
                .font(.ui(16))
                .foregroundColor(SX.C.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Format

    private var formatRow: some View {
        HStack(spacing: 10) {
            ForEach(formats, id: \.self) { option in
                FormatCard(aspect: option, selected: option == aspect) {
                    Haptics.selection()
                    withAnimation(SX.spring) { aspect = option }
                }
            }
        }
    }

    private var createButton: some View {
        Button {
            Haptics.medium()
            app.createProject(aspect: aspect)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Create project")
                Text(aspect.label)
                    .font(.mono(13, medium: true))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(SX.C.onAccent.opacity(0.12)))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityLabel("Create \(aspect.label) project")
    }

    // MARK: Projects

    @ViewBuilder
    private var projects: some View {
        if app.projects.isEmpty {
            EmptyProjectsCard()
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(app.projects) { project in
                    ProjectCard(project: project) {
                        app.open(project)
                    }
                    .contextMenu {
                        Button {
                            renaming = project
                            renameText = project.name
                            showRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button {
                            app.duplicate(project)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        Button(role: .destructive) {
                            app.delete(project)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("SCYDE: Photo & Video Editor · v\(Self.version)")
                .font(.mono(11))
                .foregroundColor(SX.C.muted)
            HStack(spacing: 14) {
                Link("scyde.net", destination: URL(string: "https://scyde.net")!)
                Link("scyde.dev", destination: URL(string: "https://scyde.dev")!)
            }
            .font(.mono(11, medium: true))
            .foregroundColor(SX.C.body)
        }
        .frame(maxWidth: .infinity)
    }

    private static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }
}

// MARK: - Format card

private struct FormatCard: View {
    let aspect: CanvasAspect
    let selected: Bool
    let action: () -> Void

    private var caption: String {
        switch aspect {
        case .portrait9x16: return "Vertical"
        case .landscape16x9: return "Wide"
        case .square1x1: return "Square"
        case .portrait4x5: return "Portrait"
        case .cinema21x9: return "Cinema"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    let r = CGFloat(aspect.ratio)
                    let box: CGFloat = 40
                    let w = r < 1 ? box * r : box
                    let h = r < 1 ? box : box / r
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(selected ? SX.C.accent.opacity(0.22) : SX.C.glass)
                        .frame(width: w, height: h)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(selected ? SX.C.accent : SX.C.line2, lineWidth: 1.5)
                        .frame(width: w, height: h)
                }
                .frame(height: 44)
                VStack(spacing: 2) {
                    Text(aspect.label)
                        .font(.mono(13, medium: true))
                        .foregroundColor(SX.C.ink)
                    Text(caption)
                        .font(.ui(11, fixed: true))
                        .foregroundColor(SX.C.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .sxCard(radius: SX.R.m)
            .overlay(
                RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                    .strokeBorder(selected ? SX.C.accent : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: selected ? SX.C.accent.opacity(0.28) : .clear, radius: 16, x: 0, y: 8)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .accessibilityLabel("\(caption) \(aspect.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Empty state

private struct EmptyProjectsCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(SX.C.accent.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: "film.stack")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(SX.C.accent)
            }
            Text("Nothing here yet")
                .font(.display(18))
                .foregroundColor(SX.C.ink)
            Text("Pick a format and create a project.\nProjects save automatically as you edit.")
                .font(.ui(14))
                .foregroundColor(SX.C.body)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .sxCard(radius: SX.R.l)
    }
}
