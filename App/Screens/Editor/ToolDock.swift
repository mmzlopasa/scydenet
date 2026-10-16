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
        ToolButton(icon: "textformat", title: "Text", enabled: true) {
            model.clearSelection()
            model.activeSheet = .text
        }
        ToolButton(icon: "face.smiling", title: "Stickers", enabled: true) {
            model.clearSelection()
            model.activeSheet = .sticker
        }
        ToolButton(icon: "sparkles", title: "Effects", enabled: model.effectTarget != nil) { model.activeSheet = .effects }
        ToolButton(icon: "camera.filters", title: "Filters", enabled: model.lookTarget != nil) { model.activeSheet = .look }
        ToolButton(icon: "aspectratio", title: "Canvas", enabled: true) { model.activeSheet = .canvas }
        ToolButton(icon: "metronome", title: "Beats", enabled: true) { model.activeSheet = .beats }
        ToolButton(icon: "captions.bubble", title: "Captions", enabled: model.hasPlayableMedia) {
            Task { await model.generateCaptions() }
        }
        ToolButton(icon: "wand.and.stars", title: "AutoCut", enabled: model.hasPlayableMedia) {
            Task { await model.autoCut() }
        }
        ToolButton(icon: "scissors", title: "Split", enabled: model.canSplit) { model.split() }
        ToolButton(icon: "pause.rectangle", title: "Freeze", enabled: model.project.clip(at: model.playhead, role: .main)?.kind == .video) {
            Task { await model.freezeAtPlayhead() }
        }
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
            ToolButton(icon: "sparkles", title: "Effects", enabled: true) { model.activeSheet = .effects }
            ToolButton(icon: "wand.and.rays", title: "Animation", enabled: true) { model.activeSheet = .animate }
            ToolButton(icon: "camera.filters", title: "Filters", enabled: true) { model.activeSheet = .look }
            ToolButton(icon: "slider.horizontal.3", title: "Adjust", enabled: true) { model.activeSheet = .look }
            ToolButton(icon: "crop.rotate", title: "Crop", enabled: true) { model.activeSheet = .crop }
            ToolButton(icon: "circle.dashed.inset.filled", title: "Mask", enabled: true) { model.activeSheet = .mask }
            ToolButton(icon: "square.2.layers.3d", title: "Blend", enabled: true) { model.activeSheet = .blend }
            if model.selectedIsVideo {
                ToolButton(icon: "camera.metering.center.weighted", title: "Stabilise", enabled: true) { model.activeSheet = .stabilize }
                ToolButton(icon: "backward.end.alt", title: "Reverse", enabled: true) {
                    Task { await model.reverseSelected() }
                }
                ToolButton(icon: "pause.rectangle", title: "Freeze", enabled: true) {
                    Task { await model.freezeAtPlayhead() }
                }
                ToolButton(icon: "waveform.badge.minus", title: "Extract audio", enabled: true) { model.extractAudio() }
            }
            ToolButton(
                icon: (model.selectedClip?.removeBackground ?? false) ? "person.crop.rectangle.fill" : "person.crop.rectangle",
                title: (model.selectedClip?.removeBackground ?? false) ? "Restore BG" : "Remove BG",
                enabled: true
            ) { model.toggleCutout() }
            ToolButton(icon: "drop.halffull", title: "Chroma", enabled: true) { model.activeSheet = .chroma }
        }
        if model.selectedIsText {
            ToolButton(icon: "pencil", title: "Edit text", enabled: true) {
                model.textTab = 0
                model.activeSheet = .text
            }
            ToolButton(icon: "paintpalette", title: "Style", enabled: true) {
                model.textTab = 1
                model.activeSheet = .text
            }
            ToolButton(icon: "wand.and.rays", title: "Animate", enabled: true) {
                model.textTab = 2
                model.activeSheet = .text
            }
            ToolButton(icon: "waveform", title: "Read aloud", enabled: true) {
                model.textTab = 3
                model.activeSheet = .text
            }
        }
        if model.selectedIsSticker {
            ToolButton(icon: "face.smiling", title: "Replace", enabled: true) { model.activeSheet = .sticker }
            ToolButton(icon: "wand.and.rays", title: "Animate", enabled: true) { model.activeSheet = .animate }
        }
        if model.selectedIsGraphic {
            ToolButton(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "Transform", enabled: true) { model.activeSheet = .transform }
            ToolButton(icon: "sparkles", title: "Effects", enabled: true) { model.activeSheet = .effects }
        }
        if model.selectedIsAudio {
            ToolButton(icon: "waveform.badge.plus", title: "Voice FX", enabled: true) { model.activeSheet = .voiceFX }
            ToolButton(icon: "metronome", title: "Beats", enabled: true) { model.activeSheet = .beats }
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
            ArtIcon(symbol: icon, palette: palette, size: 44, dimmed: !enabled)
                .frame(width: 46, height: 46)
            Text(title.loc)
                .font(.ui(11, .medium, fixed: true))
                .foregroundColor(SX.C.body)
                .lineLimit(1)
        }
        .frame(width: 64)
        .opacity(enabled ? 1 : 0.6)
        .animation(SX.spring, value: enabled)
    }

    private var palette: ArtPalette {
        if prominent { return .gold }
        if destructive { return .ruby }
        if title == "Back" { return .graphite }
        let key = title.lowercased().replacingOccurrences(of: " ", with: "")
        return ArtPalette.forTool(key)
    }
}
