import SwiftUI
import UIKit
import SCYDECore

struct EditHomeView: View {
    @EnvironmentObject private var app: AppModel

    private enum Action {
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

    private let tools: [Tool] = [
        Tool(id: "captions", icon: "captions.bubble", title: "Auto captions", action: .editorTool("Captions")),
        Tool(id: "cutout", icon: "person.crop.rectangle", title: "Remove background", action: .photo(3)),
        Tool(id: "autocut", icon: "wand.and.stars", title: "AutoCut", action: .editorTool("AutoCut")),
        Tool(id: "enhance", icon: "sparkles", title: "Auto enhance", action: .photo(1)),
        Tool(id: "voice", icon: "mic", title: "Voice-over", action: .editorTool("Audio")),
        Tool(id: "speed", icon: "speedometer", title: "Speed", action: .editorTool("Speed")),
        Tool(id: "cover", icon: "photo.on.rectangle.angled", title: "Cover maker", action: .editorTool("Cover")),
        Tool(id: "collage", icon: "square.grid.2x2", title: "Collage", action: .collage),
        Tool(id: "templates", icon: "rectangle.stack", title: "Templates", action: .templates),
        Tool(id: "stock", icon: "play.square.stack", title: "Stock videos", action: .editorTool("Stock")),
        Tool(id: "photo", icon: "photo", title: "Photo editor", action: .photo(0)),
        Tool(id: "captions2", icon: "text.bubble", title: "Subtitles", action: .editorTool("Text")),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    @State private var topInset: CGFloat = 54

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                hero
                SectionLabel(index: "01", title: "Tools")
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 16)
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(tools) { tool in
                        toolTile(tool)
                    }
                }
                .padding(.horizontal, 14)

                if !app.projects.isEmpty {
                    SectionLabel(index: "02", title: "Recent", trailing: "\(app.projects.count)")
                        .padding(.horizontal, 20)
                        .padding(.top, 34)
                        .padding(.bottom, 14)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(app.projects.prefix(8)) { project in
                                ProjectCard(project: project) { app.open(project) }
                                    .frame(width: 168)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .ignoresSafeArea(edges: .top)
        .background(SX.C.bg.ignoresSafeArea())
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { topInset = max(geo.safeAreaInsets.top, 20) }
            }
        )
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            HeroBackdrop()
                .frame(height: 460 + topInset)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    (Text("scyde").foregroundColor(.white) + Text(".").foregroundColor(SX.C.gold))
                        .font(.display(26, bold: true, fixed: true))
                    Spacer()
                    Menu {
                        Picker("Appearance", selection: $app.appearance) {
                            ForEach(AppModel.Appearance.allCases) { option in
                                Label(option.label.loc, systemImage: option.icon).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: app.appearance.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                    }
                    .accessibilityLabel("Appearance")
                }
                .padding(.bottom, 92)

                Text("Video editing")
                    .font(.ui(17, .medium))
                    .foregroundColor(Color.white.opacity(0.75))
                    .padding(.bottom, 4)
                Button {
                    Haptics.light()
                    app.showNewProject = true
                } label: {
                    HStack(spacing: 10) {
                        Text("Get started")
                            .font(.display(36, bold: true))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.2)))
                    }
                }
                .buttonStyle(PressableStyle())
                .padding(.bottom, 22)

                HStack(spacing: 12) {
                    BigActionCard(icon: "plus", title: "New video", badge: nil, wide: true) {
                        Haptics.medium()
                        app.showNewProject = true
                    }
                    BigActionCard(icon: "photo", title: "Edit photo", badge: nil, wide: false) {
                        app.openPhotoEditor()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, topInset + 8)
        }
    }

    private func toolTile(_ tool: Tool) -> some View {
        Button {
            switch tool.action {
            case let .editorTool(name): app.openEditorTool(name)
            case let .photo(tab): app.openPhotoEditor(tab: tab)
            case .collage:
                Haptics.light()
                app.showCollage = true
            case .templates:
                Haptics.selection()
                app.tab = .templates
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: tool.icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(SX.C.ink)
                    .frame(width: 58, height: 58)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SX.C.glass))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SX.C.line2, lineWidth: 1))
                Text(tool.title.loc)
                    .font(.ui(13, .medium, fixed: true))
                    .foregroundColor(SX.C.body)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 34, alignment: .top)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(tool.title)
    }
}

/// Violet-to-background header with a warm glow, like the site's hero.
private struct HeroBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(UIColor(hex: 0x241E63)), location: 0),
                    .init(color: Color(UIColor(hex: 0x4A3BC9)), location: 0.42),
                    .init(color: SX.C.bg, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [SX.C.gold.opacity(0.42), Color.clear],
                center: UnitPoint(x: 0.95, y: 0.1),
                startRadius: 0,
                endRadius: 300
            )
            RadialGradient(
                colors: [Color(UIColor(hex: 0x8EF0C8)).opacity(0.18), Color.clear],
                center: UnitPoint(x: 0.0, y: 0.55),
                startRadius: 0,
                endRadius: 260
            )
        }
        .ignoresSafeArea(edges: .top)
    }
}

private struct BigActionCard: View {
    let icon: String
    let title: String
    let badge: String?
    let wide: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(SX.C.onAccent)
                        .frame(width: 46, height: 46)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(SX.accentGradient))
                        .shadow(color: SX.C.accent.opacity(0.45), radius: 12, x: 0, y: 6)
                    Text(title.loc)
                        .font(.display(19))
                        .foregroundColor(SX.C.ink)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                if let badge = badge {
                    Text(badge.loc)
                        .font(.mono(10, medium: true))
                        .foregroundColor(SX.C.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(SX.C.glass))
                        .overlay(Capsule().strokeBorder(SX.C.line2, lineWidth: 1))
                        .padding(10)
                }
            }
            .sxCard(radius: SX.R.xl)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .frame(maxWidth: wide ? .infinity : 128)
        .accessibilityLabel(badge == nil ? title : "\(title), coming soon")
    }
}
