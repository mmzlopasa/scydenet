import SwiftUI
import UIKit
import SCYDECore

struct ProjectsView: View {
    @EnvironmentObject private var app: AppModel

    enum Section: String, CaseIterable, Hashable {
        case local = "Local"
        case media = "Media"
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case recent = "Recently edited"
        case name = "Name"
        var id: String { rawValue }
    }

    @State private var section: Section = .local
    @State private var filter: CanvasAspect?
    @State private var searching = false
    @State private var query = ""
    @State private var sort: SortOrder = .recent
    @State private var renaming: Project?
    @State private var renameText = ""
    @State private var showRename = false

    private let filters: [(String, CanvasAspect?)] = [
        ("All", nil), ("9:16", .portrait9x16), ("16:9", .landscape16x9), ("1:1", .square1x1), ("4:5", .portrait4x5),
    ]
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var visible: [Project] {
        let filtered = app.projects.filter { p in
            (filter == nil || p.aspect == filter) && (query.isEmpty || p.name.localizedCaseInsensitiveContains(query))
        }
        switch sort {
        case .recent: return filtered
        case .name: return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 12)
            if searching {
                SearchField(placeholder: "Search projects", text: $query)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            UnderlineTabs(items: Section.allCases, selection: $section) { $0.rawValue }
                .padding(.horizontal, 20)
                .padding(.top, 16)

            switch section {
            case .local:
                localContent
            case .media:
                MediaLibraryView()
            }
        }
        .background(SX.C.bg.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            if section == .local {
                Button {
                    Haptics.medium()
                    app.showNewProject = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                        Text("Create")
                    }
                    .padding(.horizontal, 22)
                }
                .buttonStyle(PillButtonStyle())
                .scaleEffect(1.15)
                .padding(.trailing, 26)
                .padding(.bottom, 18)
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

    private var header: some View {
        HStack(spacing: 10) {
            Text("Projects")
                .font(.display(30))
                .foregroundColor(SX.C.ink)
            Spacer()
            GlassIconButton(systemName: searching ? "xmark" : "magnifyingglass", label: "Search") {
                withAnimation(SX.spring) {
                    searching.toggle()
                    if !searching { query = "" }
                }
            }
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                GlassIcon(systemName: "ellipsis")
            }
            .accessibilityLabel("Sort")
        }
    }

    @ViewBuilder
    private var localContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters.indices, id: \.self) { i in
                    FilterChip(title: filters[i].0, selected: filter == filters[i].1) {
                        Haptics.selection()
                        withAnimation(SX.spring) { filter = filters[i].1 }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }

        if visible.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "tray")
                    .font(.system(size: 52, weight: .light))
                    .foregroundColor(SX.C.muted.opacity(0.6))
                Text(app.projects.isEmpty ? "No projects yet" : "Nothing matches")
                    .font(.display(20))
                    .foregroundColor(SX.C.ink)
                Text(app.projects.isEmpty ? "Your projects will appear here." : "Try another filter or search.")
                    .font(.ui(15))
                    .foregroundColor(SX.C.body)
                if app.projects.isEmpty {
                    Button {
                        Haptics.light()
                        app.showNewProject = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Create")
                        }
                        .font(.ui(17, .medium, fixed: true))
                        .foregroundColor(SX.C.ink)
                        .padding(.horizontal, 26)
                        .frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: SX.R.m, style: .continuous).strokeBorder(SX.C.line2, lineWidth: 1.5))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 12)
                }
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(visible) { project in
                        ProjectCard(project: project) { app.open(project) }
                            .contextMenu {
                                Button {
                                    renaming = project
                                    renameText = project.name
                                    showRename = true
                                } label: { Label("Rename", systemImage: "pencil") }
                                Button {
                                    app.duplicate(project)
                                } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                Button(role: .destructive) {
                                    app.delete(project)
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 90)
            }
        }
    }
}

// MARK: - Media library

struct MediaItem: Identifiable {
    let id: String
    let kind: Clip.Kind
    let bytes: Int64
    let date: Date

    static func all() -> [MediaItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let urls = try? fm.contentsOfDirectory(at: MediaStore.directory, includingPropertiesForKeys: keys) else { return [] }
        return urls.compactMap { url -> MediaItem? in
            let ext = url.pathExtension.lowercased()
            let kind: Clip.Kind
            if ["jpg", "jpeg", "png", "heic"].contains(ext) {
                kind = .photo
            } else if ["mov", "mp4", "m4v"].contains(ext) {
                kind = .video
            } else {
                return nil
            }
            let values = try? url.resourceValues(forKeys: Set(keys))
            return MediaItem(
                id: url.lastPathComponent,
                kind: kind,
                bytes: Int64(values?.fileSize ?? 0),
                date: values?.contentModificationDate ?? .distantPast
            )
        }
        .sorted { $0.date > $1.date }
    }
}

private struct MediaLibraryView: View {
    @State private var items: [MediaItem] = []
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    private static let bytes: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    var body: some View {
        Group {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(SX.C.muted.opacity(0.6))
                    Text("No media yet")
                        .font(.display(20))
                        .foregroundColor(SX.C.ink)
                    Text("Photos and videos you import are kept here.")
                        .font(.ui(15))
                        .foregroundColor(SX.C.body)
                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(items.count) files · \(Self.bytes.string(fromByteCount: items.reduce(0) { $0 + $1.bytes }))")
                            .font(.mono(11))
                            .foregroundColor(SX.C.muted)
                            .padding(.horizontal, 20)
                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(items) { item in
                                MediaThumb(item: item)
                                    .aspectRatio(1, contentMode: .fill)
                            }
                        }
                        .padding(.horizontal, 3)
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear { items = MediaItem.all() }
    }
}

private struct MediaThumb: View {
    let item: MediaItem
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                SX.C.surface3
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                Image(systemName: item.kind == .video ? "video.fill" : "photo.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.4)))
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .task(id: item.id) {
            image = await ThumbnailCache.shared.image(assetID: item.id, kind: item.kind, at: 0)
        }
    }
}
