import SwiftUI
import SCYDECore

enum AppTab: String, CaseIterable, Identifiable {
    case edit, templates, ai, projects, me

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit: return "Edit"
        case .templates: return "Templates"
        case .ai: return "AI Lab"
        case .projects: return "Projects"
        case .me: return "Me"
        }
    }

    var icon: String {
        switch self {
        case .edit: return "scissors"
        case .templates: return "rectangle.stack"
        case .ai: return "sparkles"
        case .projects: return "folder"
        case .me: return "person.crop.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .edit: return "scissors"
        case .templates: return "rectangle.stack.fill"
        case .ai: return "sparkles"
        case .projects: return "folder.fill"
        case .me: return "person.crop.circle.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            Group {
                switch app.tab {
                case .edit: EditHomeView()
                case .templates: TemplatesView()
                case .ai: AILabView()
                case .projects: ProjectsView()
                case .me: MeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                TabBar(selection: $app.tab)
            }

            if let toast = app.toast {
                VStack {
                    Spacer()
                    ToastView(text: toast)
                        .padding(.bottom, 104)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $app.showNewProject) {
            NewProjectSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $app.photoEditor) { entry in
            PhotoEditorView(initialTab: entry.tab)
                .environmentObject(app)
                .preferredColorScheme(app.appearance.scheme)
        }
        .fullScreenCover(isPresented: $app.showCollage) {
            CollageView()
                .environmentObject(app)
                .preferredColorScheme(app.appearance.scheme)
        }
        .fullScreenCover(item: $app.openProject) { project in
            EditorView(
                project: project,
                onSave: { app.save($0) },
                onClose: { app.closeEditor() }
            )
            .preferredColorScheme(app.appearance.scheme)
        }
    }
}

private struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let selected = tab == selection
                Button {
                    guard !selected else { return }
                    Haptics.selection()
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selected ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 20, weight: selected ? .semibold : .regular))
                            .frame(height: 26)
                        Text(tab.title)
                            .font(.ui(10.5, .medium, fixed: true))
                    }
                    .foregroundColor(selected ? SX.C.ink : SX.C.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .overlay(alignment: .top) {
                        if selected {
                            Capsule()
                                .fill(SX.C.accent)
                                .frame(width: 18, height: 3)
                                .shadow(color: SX.C.accent.opacity(0.6), radius: 4)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.92))
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .background(
            SX.C.surface.opacity(0.94)
                .background(.ultraThinMaterial)
                .overlay(Rectangle().fill(SX.C.line).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Shared building blocks for the tab screens

/// Small "Soon" capsule for tools that land in a later phase.
struct SoonBadge: View {
    var body: some View {
        Text("Soon")
            .font(.mono(9, medium: true))
            .foregroundColor(SX.C.onAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(SX.C.accent))
    }
}

/// Outlined filter chip (All / 9:16 / …).
struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ui(14, .medium, fixed: true))
                .foregroundColor(selected ? SX.C.ink : SX.C.body)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    Capsule().fill(selected ? SX.C.glass : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? SX.C.ink.opacity(0.8) : SX.C.line2, lineWidth: selected ? 1.5 : 1)
                )
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Underlined section tabs (Local / Media).
struct UnderlineTabs<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        HStack(spacing: 26) {
            ForEach(items, id: \.self) { item in
                let selected = item == selection
                Button {
                    Haptics.selection()
                    withAnimation(SX.spring) { selection = item }
                } label: {
                    VStack(spacing: 9) {
                        Text(title(item))
                            .font(.ui(17, selected ? .semibold : .regular, fixed: true))
                            .foregroundColor(selected ? SX.C.ink : SX.C.muted)
                        Capsule()
                            .fill(selected ? SX.C.accent : Color.clear)
                            .frame(height: 3)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .overlay(Rectangle().fill(SX.C.line).frame(height: 1), alignment: .bottom)
    }
}

/// Rounded search field.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SX.C.muted)
            TextField(placeholder, text: $text)
                .font(.ui(16))
                .foregroundColor(SX.C.ink)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(SX.C.muted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: SX.R.m, style: .continuous).fill(SX.C.glass))
        .overlay(RoundedRectangle(cornerRadius: SX.R.m, style: .continuous).strokeBorder(SX.C.line2, lineWidth: 1))
    }
}
