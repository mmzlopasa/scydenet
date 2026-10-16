import SwiftUI
import UIKit
import SCYDECore

struct EditHomeView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var library = MediaLibrary.shared

    private enum Action {
        case launch(EditorLaunchAction, needsMedia: Bool)
        case editorTool(String)
        case photo(Int)
        case collage
        case templates
    }

    private struct Tool: Identifiable {
        let id: String
        let icon: String
        let title: String
        let action: Action
    }

    private struct Feature: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let action: Action
    }

    private let features: [Feature] = [
        Feature(id: "autocut", icon: "wand.and.stars", title: "AutoCut", subtitle: "Cut to the beat in one tap", action: .launch(.autoCut, needsMedia: true)),
        Feature(id: "captions", icon: "captions.bubble.fill", title: "Auto captions", subtitle: "Speech to text, offline", action: .launch(.captions, needsMedia: true)),
        Feature(id: "cutout", icon: "person.crop.rectangle.fill", title: "Remove background", subtitle: "Cut out people and things", action: .photo(3)),
        Feature(id: "collage", icon: "square.grid.2x2.fill", title: "Collage", subtitle: "Layouts for photos", action: .collage),
    ]

    private let tools: [Tool] = [
        Tool(id: "stock", icon: "play.square.stack.fill", title: "Footage", action: .launch(.sheet(.stock), needsMedia: false)),
        Tool(id: "music", icon: "music.note", title: "Music", action: .launch(.sheet(.music), needsMedia: false)),
        Tool(id: "text", icon: "textformat", title: "Text", action: .launch(.textSheet, needsMedia: false)),
        Tool(id: "effects", icon: "wand.and.rays", title: "Effects", action: .launch(.sheet(.effects), needsMedia: true)),
        Tool(id: "filters", icon: "camera.filters", title: "Filters", action: .launch(.sheet(.look), needsMedia: true)),
        Tool(id: "stickers", icon: "face.smiling.inverse", title: "Stickers", action: .launch(.stickers, needsMedia: false)),
        Tool(id: "voice", icon: "mic.fill", title: "Voice-over", action: .launch(.sheet(.voiceover), needsMedia: false)),
        Tool(id: "enhance", icon: "sparkles", title: "Enhance", action: .photo(1)),
        Tool(id: "beats", icon: "metronome", title: "Beats", action: .launch(.sheet(.beats), needsMedia: true)),
        Tool(id: "canvas", icon: "aspectratio", title: "Canvas", action: .launch(.sheet(.canvas), needsMedia: false)),
        Tool(id: "cover", icon: "photo.fill.on.rectangle.fill", title: "Cover", action: .launch(.sheet(.cover), needsMedia: true)),
        Tool(id: "speed", icon: "speedometer", title: "Speed", action: .editorTool("Speed")),
        Tool(id: "photo", icon: "photo.fill", title: "Photo editor", action: .photo(0)),
        Tool(id: "templates", icon: "rectangle.stack.fill", title: "Templates", action: .templates),
        Tool(id: "subtitles", icon: "text.bubble.fill", title: "Subtitles", action: .launch(.captions, needsMedia: true)),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)

    @State private var showAllTools = false
    @State private var appeared = Launch.isAutomation
    @State private var chosenTemplate: ProjectTemplate?
    @State private var openingClip: String?

    private var trending: [ProjectTemplate] {
        var seen = Set<TemplateCategory>()
        var out: [ProjectTemplate] = []
        for t in ProjectTemplate.all where !seen.contains(t.category) {
            seen.insert(t.category)
            out.append(t)
        }
        return Array(out.prefix(10))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 14)

                ShowreelHero(
                    videos: library.showcase(5),
                    onNew: {
                        Haptics.medium()
                        app.showNewProject = true
                    },
                    onPhoto: { app.openPhotoEditor() },
                    onTemplates: {
                        Haptics.selection()
                        app.tab = .templates
                    }
                )
                .padding(.horizontal, 16)
                .appear(appeared, index: 0)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(features.indices, id: \.self) { i in
                        featureCard(features[i])
                            .appear(appeared, index: i + 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                sectionHeader("Tools", action: showAllTools ? "Less" : "All tools") {
                    Haptics.selection()
                    withAnimation(SX.spring) { showAllTools.toggle() }
                }
                LazyVGrid(columns: columns, spacing: 18) {
                    let shown = showAllTools ? tools : Array(tools.prefix(10))
                    ForEach(shown.indices, id: \.self) { i in
                        toolTile(shown[i])
                            .appear(appeared, index: i + 3)
                    }
                }
                .padding(.horizontal, 10)

                sectionHeader("Trending templates", action: "See all") {
                    Haptics.selection()
                    app.tab = .templates
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(trending) { t in
                            Button {
                                Haptics.light()
                                chosenTemplate = t
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    TemplatePreviewView(template: t, playsVideo: false)
                                        .frame(width: 138, height: 220)
                                        .clipShape(RoundedRectangle(cornerRadius: SX.R.m, style: .continuous))
                                        .overlay(alignment: .topLeading) {
                                            Text(t.category.emoji)
                                                .font(.system(size: 13))
                                                .padding(6)
                                                .background(Circle().fill(Color.black.opacity(0.35)))
                                                .padding(7)
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                    Text(t.name.loc)
                                        .font(.ui(13, .semibold, fixed: true))
                                        .foregroundColor(SX.C.ink)
                                        .lineLimit(1)
                                    Text("\(t.slots.count) clips · \(Timecode.duration(t.totalDuration))")
                                        .font(.mono(10))
                                        .foregroundColor(SX.C.muted)
                                }
                                .frame(width: 138)
                            }
                            .buttonStyle(PressableStyle(scale: 0.96))
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if !app.projects.isEmpty {
                    sectionHeader("Your projects", action: "See all") {
                        Haptics.selection()
                        app.tab = .projects
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(app.projects.prefix(8)) { project in
                                ProjectCard(project: project) { app.open(project) }
                                    .frame(width: 160)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                let footage = library.showcase(12)
                if !footage.isEmpty {
                    sectionHeader("Free footage", action: "Library") {
                        app.launchTool(.sheet(.stock))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(footage) { v in
                                Button {
                                    guard openingClip == nil else { return }
                                    openingClip = v.id
                                    Task {
                                        await app.createWithPackVideo(v)
                                        openingClip = nil
                                    }
                                } label: {
                                    PackPosterTile(video: v, busy: openingClip == v.id)
                                        .frame(width: 112, height: 168)
                                        .clipShape(RoundedRectangle(cornerRadius: SX.R.m, style: .continuous))
                                }
                                .buttonStyle(PressableStyle(scale: 0.96))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    Text("Tap a clip to start a project with it. Free to use; credits stay in the clip name.")
                        .font(.ui(11.5))
                        .foregroundColor(SX.C.muted)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                if !library.genres.isEmpty {
                    sectionHeader("Music", action: "Open") {
                        app.launchTool(.sheet(.music))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(library.genres, id: \.self) { g in
                                Button {
                                    app.launchTool(.sheet(.music))
                                } label: {
                                    GenreCard(genre: g)
                                }
                                .buttonStyle(PressableStyle(scale: 0.95))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                HStack(spacing: 6) {
                    (Text("scyde").foregroundColor(SX.C.muted) + Text(".").foregroundColor(SX.C.accent))
                        .font(.display(15, bold: true, fixed: true))
                    Text("Photo & Video Editor")
                        .font(.mono(10.5))
                        .foregroundColor(SX.C.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 34)
            }
            .padding(.bottom, 28)
        }
        .background(
            ZStack(alignment: .top) {
                SX.C.bg
                LinearGradient(colors: [SX.C.glowB, .clear], startPoint: .top, endPoint: .center)
                    .frame(height: 420)
            }
            .ignoresSafeArea()
        )
        .onAppear { appeared = true }
        .task { await library.load() }
        .sheet(item: $chosenTemplate) { t in
            TemplateSheet(template: t)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            (Text("scyde").foregroundColor(SX.C.ink) + Text(".").foregroundColor(SX.C.accent))
                .font(.display(27, bold: true, fixed: true))
            Spacer()
            Button {
                Haptics.light()
                app.showPlans = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Pro")
                        .font(.ui(14, .semibold, fixed: true))
                }
                .foregroundColor(Color(UIColor(hex: 0x1B1530)))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(LinearGradient(colors: [Color(UIColor(hex: 0xFFE7A0)), Color(UIColor(hex: 0xE9B84A))], startPoint: .top, endPoint: .bottom)))
                .shadow(color: SX.C.gold.opacity(0.4), radius: 10, y: 4)
            }
            .buttonStyle(PressableStyle())
            Menu {
                Picker("Appearance", selection: $app.appearance) {
                    ForEach(AppModel.Appearance.allCases) { option in
                        Label(option.label.loc, systemImage: option.icon).tag(option)
                    }
                }
            } label: {
                Image(systemName: app.appearance.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SX.C.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(SX.C.glass))
                    .overlay(Circle().strokeBorder(SX.C.line2, lineWidth: 1))
            }
            .accessibilityLabel("Appearance")
            Button {
                Haptics.light()
                app.tab = .me
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SX.C.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(SX.C.glass))
                    .overlay(Circle().strokeBorder(SX.C.line2, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Settings")
        }
    }

    // MARK: Pieces

    private func sectionHeader(_ title: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.loc)
                .font(.display(20, bold: true))
                .foregroundColor(SX.C.ink)
            Spacer()
            Button(action: perform) {
                HStack(spacing: 3) {
                    Text(action.loc)
                        .font(.ui(13.5, .medium, fixed: true))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(SX.C.body)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 12)
    }

    private func run(_ action: Action) {
        switch action {
        case let .launch(a, needsMedia): app.launchTool(a, needsMedia: needsMedia)
        case let .editorTool(name): app.openEditorTool(name)
        case let .photo(tab): app.openPhotoEditor(tab: tab)
        case .collage:
            Haptics.light()
            app.showCollage = true
        case .templates:
            Haptics.selection()
            app.tab = .templates
        }
    }

    private func featureCard(_ f: Feature) -> some View {
        Button { run(f.action) } label: {
            HStack(spacing: 11) {
                ArtIcon(symbol: f.icon, palette: ArtPalette.forTool(f.id), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.title.loc)
                        .font(.ui(14, .semibold, fixed: true))
                        .foregroundColor(SX.C.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(f.subtitle.loc)
                        .font(.ui(11.5, fixed: true))
                        .foregroundColor(SX.C.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .sxCard(radius: SX.R.l)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel(f.title)
    }

    private func toolTile(_ tool: Tool) -> some View {
        Button { run(tool.action) } label: {
            VStack(spacing: 7) {
                ArtIcon(symbol: tool.icon, palette: ArtPalette.forTool(tool.id), size: 48)
                Text(tool.title.loc)
                    .font(.ui(11.5, .medium, fixed: true))
                    .foregroundColor(SX.C.body)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(height: 28, alignment: .top)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(tool.title)
    }
}

// MARK: - Showreel hero

/// Full-width card that plays SCYDE's footage behind the main actions, crossfading between clips.
private struct ShowreelHero: View {
    let videos: [MediaPack.Video]
    let onNew: () -> Void
    let onPhoto: () -> Void
    let onTemplates: () -> Void

    @State private var urls: [URL] = []
    @State private var index = 0
    @State private var zoom = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HeroBackdrop()
            if !urls.isEmpty {
                LoopingVideo(url: urls[index % urls.count])
                    .id(index % urls.count)
                    .transition(.opacity)
                    .scaleEffect(zoom ? 1.12 : 1.0)
                    .animation(.linear(duration: 6), value: zoom)
            }
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.25), location: 0),
                    .init(color: Color.black.opacity(0.05), location: 0.3),
                    .init(color: Color.black.opacity(0.78), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(SX.C.gold)
                        .frame(width: 6, height: 6)
                    Text("Video · Photo · Sound")
                        .font(.mono(10.5, medium: true))
                        .tracking(1.1)
                        .foregroundColor(Color.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.3)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                Spacer(minLength: 0)
                Text("What are we making today?")
                    .font(.display(29, bold: true))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.4), radius: 10, y: 3)
                    .padding(.bottom, 16)
                Button(action: onNew) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .heavy))
                        Text("New project")
                            .font(.ui(17, .semibold, fixed: true))
                    }
                    .foregroundColor(Color(UIColor(hex: 0x1B1530)))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule().fill(LinearGradient(colors: [Color(UIColor(hex: 0xFFF0B8)), Color(UIColor(hex: 0xFFD76A)), Color(UIColor(hex: 0xE9B84A))], startPoint: .top, endPoint: .bottom))
                    )
                    .shadow(color: SX.C.gold.opacity(0.45), radius: 16, y: 6)
                }
                .buttonStyle(PressableStyle(scale: 0.97))
                .accessibilityLabel("New project")
                HStack(spacing: 10) {
                    glassButton("photo.fill", "Edit photo", action: onPhoto)
                    glassButton("rectangle.stack.fill", "Templates", action: onTemplates)
                }
                .padding(.top, 10)
            }
            .padding(18)
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: SX.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SX.R.xl, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 26, x: 0, y: 16)
        .task(id: videos.map(\.id).joined()) {
            var found: [URL] = []
            for v in videos {
                if let url = await MediaLibrary.shared.file(v.file) {
                    found.append(url)
                    if found.count == 1 {
                        withAnimation(.easeOut(duration: 0.5)) { urls = found }
                        zoom = true
                    }
                }
            }
            urls = found
            guard found.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                zoom = false
                withAnimation(.easeInOut(duration: 0.9)) { index += 1 }
                try? await Task.sleep(nanoseconds: 50_000_000)
                zoom = true
            }
        }
    }

    private func glassButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title.loc)
                    .font(.ui(14.5, .semibold, fixed: true))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Capsule().fill(.ultraThinMaterial))
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .environment(\.colorScheme, .dark)
    }
}

/// Violet header with a warm glow, like the site's hero (shown until footage loads).
private struct HeroBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(UIColor(hex: 0x2A2272)), Color(UIColor(hex: 0x4A3BC9)), Color(UIColor(hex: 0x14161D))],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [SX.C.gold.opacity(0.45), Color.clear], center: UnitPoint(x: 0.9, y: 0.1), startRadius: 0, endRadius: 260)
            RadialGradient(colors: [Color(UIColor(hex: 0x8EF0C8)).opacity(0.22), Color.clear], center: UnitPoint(x: 0.05, y: 0.6), startRadius: 0, endRadius: 240)
        }
    }
}

// MARK: - Small cards

/// A footage still with its credit, shown before anything downloads in full.
struct PackPosterTile: View {
    let video: MediaPack.Video
    var busy: Bool = false
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SX.C.surface3
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
            LinearGradient(colors: [.clear, Color.black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 1) {
                Text(video.title)
                    .font(.ui(11, .semibold, fixed: true))
                    .lineLimit(1)
                Text(video.author)
                    .font(.mono(8.5))
                    .lineLimit(1)
                    .opacity(0.75)
            }
            .foregroundColor(.white)
            .padding(8)
            if busy {
                Color.black.opacity(0.45)
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Color(UIColor(hex: 0x1B1530)))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(SX.C.gold))
                    .padding(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .task(id: video.id) {
            let img = await MediaLibrary.shared.posterImage(for: video)
            withAnimation(.easeOut(duration: 0.2)) { image = img }
        }
    }
}

private struct GenreCard: View {
    let genre: String

    private var icon: String {
        switch genre.lowercased() {
        case "upbeat": return "sun.max.fill"
        case "cinematic": return "film.fill"
        case "electronic": return "waveform"
        case "chill": return "moon.stars.fill"
        case "rock": return "guitars.fill"
        case "piano": return "pianokeys"
        case "funk": return "music.mic"
        case "classical": return "music.quarternote.3"
        default: return "music.note"
        }
    }

    var body: some View {
        let palette = ArtPalette.forName(genre)
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(UIColor(hex: palette.top)), Color(UIColor(hex: palette.bottom))], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: icon)
                .font(.system(size: 54, weight: .bold))
                .foregroundColor(Color.white.opacity(0.22))
                .rotationEffect(.degrees(-12))
                .offset(x: 62, y: -26)
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(genre.loc)
                    .font(.ui(14, .semibold, fixed: true))
            }
            .foregroundColor(.white)
            .padding(11)
        }
        .frame(width: 118, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: SX.R.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SX.R.m, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Entrance

private extension View {
    /// Staggered rise-in on first appearance.
    func appear(_ on: Bool, index: Int) -> some View {
        opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 16)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(min(index, 14)) * 0.03), value: on)
    }
}
