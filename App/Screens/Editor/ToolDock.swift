import PhotosUI
import SwiftUI

/// Bottom tool row. Root tools when nothing is selected, clip tools when a clip is.
struct ToolDock: View {
    @ObservedObject var model: EditorViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if model.selection == nil {
                    rootTools
                } else {
                    clipTools
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .animation(SX.spring, value: model.selection)
        }
        .background(
            SX.C.surface
                .overlay(Rectangle().fill(SX.C.line).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private var rootTools: some View {
        PhotosPicker(
            selection: $model.pickerItems,
            maxSelectionCount: 20,
            matching: .any(of: [.videos, .images])
        ) {
            ToolItem(icon: "plus", title: "Import", enabled: true, prominent: true)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Import media")

        divider

        PhotosPicker(
            selection: $model.overlayPickerItems,
            maxSelectionCount: 5,
            matching: .any(of: [.videos, .images])
        ) {
            ToolItem(icon: "rectangle.on.rectangle", title: "Overlay", enabled: true)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Add overlay")
        ToolButton(icon: "play.square.stack", title: "Stock", enabled: true) { model.activeSheet = .stock }
        ToolButton(icon: "music.note", title: "Audio", enabled: true) { model.showAudioMenu = true }
        ToolButton(icon: "textformat", title: "Text", enabled: true) { model.activeSheet = .text }
        ToolButton(icon: "captions.bubble", title: "Captions", enabled: model.hasPlayableMedia) {
            Task { await model.generateCaptions() }
        }
        ToolButton(icon: "camera.filters", title: "Filters", enabled: model.lookTarget != nil) { model.activeSheet = .look }
        ToolButton(icon: "wand.and.stars", title: "AutoCut", enabled: model.hasPlayableMedia) {
            Task { await model.autoCut() }
        }
        ToolButton(icon: "scissors", title: "Split", enabled: model.canSplit) { model.split() }
        ToolButton(icon: "photo.on.rectangle.angled", title: "Cover", enabled: model.hasPlayableMedia) { model.activeSheet = .cover }
    }

    @ViewBuilder
    private var clipTools: some View {
        ToolButton(icon: "chevron.down", title: "Back", enabled: true) { model.clearSelection() }
        divider
        ToolButton(icon: "scissors", title: "Split", enabled: model.canSplit) { model.split() }
        if model.selectedHasSpeed {
            ToolButton(icon: "speedometer", title: "Speed", enabled: true) { model.activeSheet = .speed }
        }
        if model.selectedIsVisual {
            ToolButton(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "Transform", enabled: true) { model.activeSheet = .transform }
            if model.selectedCanTransition {
                ToolButton(icon: "square.split.diagonal.2x2", title: "Transition", enabled: true) { model.activeSheet = .transition }
            }
            ToolButton(icon: "camera.filters", title: "Filters", enabled: true) { model.activeSheet = .look }
            ToolButton(icon: "slider.horizontal.3", title: "Adjust", enabled: true) { model.activeSheet = .look }
            ToolButton(
                icon: (model.selectedClip?.removeBackground ?? false) ? "person.crop.rectangle.fill" : "person.crop.rectangle",
                title: (model.selectedClip?.removeBackground ?? false) ? "Restore BG" : "Remove BG",
                enabled: true
            ) { model.toggleCutout() }
            ToolButton(icon: "drop.halffull", title: "Chroma", enabled: true) { model.activeSheet = .chroma }
        }
        if model.selectedIsText {
            ToolButton(icon: "pencil", title: "Edit text", enabled: true) { model.activeSheet = .text }
        }
        if model.selectedIsAudio {
            ToolButton(icon: "waveform.badge.plus", title: "Voice FX", enabled: true) { model.activeSheet = .voiceFX }
        }
        if model.canMute {
            ToolButton(
                icon: model.selectedIsMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                title: "Volume",
                enabled: true
            ) { model.activeSheet = .volume }
        }
        ToolButton(icon: "plus.square.on.square", title: "Duplicate", enabled: true) { model.duplicateSelected() }
        ToolButton(icon: "trash", title: "Delete", enabled: true, destructive: true) { model.deleteSelected() }
    }

    private var divider: some View {
        Rectangle()
            .fill(SX.C.line2)
            .frame(width: 1, height: 34)
            .padding(.horizontal, 6)
    }
}

private struct ToolButton: View {
    let icon: String
    let title: String
    let enabled: Bool
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolItem(icon: icon, title: title, enabled: enabled, destructive: destructive)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

private struct ToolItem: View {
    let icon: String
    let title: String
    let enabled: Bool
    var prominent: Bool = false
    var destructive: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if prominent {
                    RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                        .fill(SX.accentGradient)
                        .shadow(color: SX.C.accent.opacity(0.35), radius: 10, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                        .fill(SX.C.glass)
                    RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                        .strokeBorder(SX.C.line2, lineWidth: 1)
                }
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(prominent ? SX.C.onAccent : (destructive ? SX.C.err : SX.C.ink))
            }
            .frame(width: 46, height: 46)
            Text(title.loc)
                .font(.ui(11, .medium, fixed: true))
                .foregroundColor(SX.C.body)
                .lineLimit(1)
        }
        .frame(width: 64)
        .opacity(enabled ? 1 : 0.35)
        .animation(SX.spring, value: enabled)
    }
}
