import AVFoundation
import SwiftUI
import UIKit
import SCYDECore

// MARK: - Effects

struct EffectsSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var clipID: UUID?
    @State private var kind: String?
    @State private var intensity = 0.6
    @State private var group = Effects.groups[0]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ToolSheetScaffold(title: "Effects", subtitle: "One effect per clip, rendered in preview and export.", onClose: { dismiss() }) {
            if clipID == nil {
                Text("Select a clip, or move the playhead over one.")
                    .font(.ui(14))
                    .foregroundColor(SX.C.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Effects.groups, id: \.self) { g in
                            FilterChip(title: g, selected: group == g) { group = g }
                        }
                    }
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    OptionTile(icon: "nosign", title: "None", selected: kind == nil) {
                        kind = nil
                        commit()
                    }
                    ForEach(Effects.all.filter { $0.group == group }) { e in
                        OptionTile(icon: e.icon, title: e.name, selected: kind == e.id) {
                            kind = e.id
                            commit()
                        }
                    }
                }
                if kind != nil {
                    SXSlider(title: "Intensity", value: $intensity, range: 0...1, format: "%.0f%%", scale: 100, onCommit: commit)
                }
            }
        }
        .onAppear {
            let target = model.effectTarget
            clipID = target?.id
            kind = target?.effect?.kind
            intensity = target?.effect?.intensity ?? 0.6
            if let k = kind, let info = Effects.info(k) { group = info.group }
        }
    }

    private func commit() {
        guard let id = clipID else { return }
        model.setEffect(id, kind.map { VideoEffect(kind: $0, intensity: intensity) })
    }
}

// MARK: - Mask

struct MaskSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mask: ClipMask?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ToolSheetScaffold(title: "Mask", subtitle: "Show part of the clip. Great on overlays.", onClose: { dismiss() }) {
            if let id = model.selection, model.selectedIsVisual {
                LazyVGrid(columns: columns, spacing: 12) {
                    OptionTile(icon: "nosign", title: "None", selected: mask == nil) {
                        mask = nil
                        model.setMask(id, nil)
                    }
                    ForEach(MaskShape.allCases, id: \.self) { shape in
                        OptionTile(icon: Self.icon(shape), title: Self.title(shape), selected: mask?.shape == shape) {
                            var m = mask ?? ClipMask(shape: shape)
                            m.shape = shape
                            mask = m
                            model.setMask(id, m)
                        }
                    }
                }
                if mask != nil {
                    sliders(id)
                }
            } else {
                Text("Select a video or photo first.")
                    .font(.ui(14))
                    .foregroundColor(SX.C.muted)
            }
        }
        .onAppear { mask = model.selectedClip?.mask }
    }

    @ViewBuilder
    private func sliders(_ id: UUID) -> some View {
        let binding = Binding<ClipMask>(get: { mask ?? ClipMask(shape: .circle) }, set: { mask = $0 })
        let commit = { model.setMask(id, mask) }
        SXSlider(title: "Position X", value: binding.x, range: -0.6...0.6, onCommit: commit)
        SXSlider(title: "Position Y", value: binding.y, range: -0.6...0.6, onCommit: commit)
        SXSlider(title: "Size", value: binding.size, range: 0.05...1.6, onCommit: commit)
        if mask?.shape == .circle || mask?.shape == .rectangle {
            SXSlider(title: "Width", value: binding.aspect, range: 0.2...3, onCommit: commit)
        }
        SXSlider(title: "Rotation", value: binding.rotation, range: -180...180, format: "%.0f°", onCommit: commit)
        SXSlider(title: "Feather", value: binding.feather, range: 0...1, format: "%.0f%%", scale: 100, onCommit: commit)
        Toggle("Invert", isOn: Binding(get: { mask?.invert ?? false }, set: { mask?.invert = $0; commit() }))
            .font(.ui(15, .medium))
            .foregroundColor(SX.C.ink)
            .tint(SX.C.accent)
            .padding(14)
            .sxCard(radius: SX.R.m)
    }

    static func icon(_ s: MaskShape) -> String {
        switch s {
        case .linear: return "minus"
        case .mirror: return "equal"
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .heart: return "heart"
        case .star: return "star"
        }
    }

    static func title(_ s: MaskShape) -> String {
        switch s {
        case .linear: return "Linear"
        case .mirror: return "Mirror"
        case .circle: return "Circle"
        case .rectangle: return "Rectangle"
        case .heart: return "Heart"
        case .star: return "Star"
        }
    }
}

// MARK: - Crop, rotate, flip

struct CropSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var ratio: Double = 0
    @State private var zoom = 1.0
    @State private var panX = 0.0
    @State private var panY = 0.0
    @State private var sourceRatio: Double = 1

    private let ratios: [(String, Double)] = [
        ("Original", 0), ("9:16", 9.0 / 16.0), ("16:9", 16.0 / 9.0), ("1:1", 1),
        ("4:5", 0.8), ("3:4", 0.75), ("4:3", 4.0 / 3.0), ("21:9", 21.0 / 9.0),
    ]

    var body: some View {
        ToolSheetScaffold(title: "Crop", subtitle: "Crop, rotate and flip the clip's picture.", onClose: { dismiss() }) {
            if let id = model.selection, model.selectedIsVisual {
                HStack(spacing: 10) {
                    OptionTile(icon: "rotate.right", title: "Rotate", selected: false) {
                        model.rotateQuarter(id)
                        Task { await loadRatio() }
                    }
                    OptionTile(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", title: "Flip H", selected: model.selectedClip?.flipH == true) {
                        model.flip(id, horizontal: true)
                    }
                    OptionTile(icon: "arrow.up.and.down.righttriangle.up.righttriangle.down", title: "Flip V", selected: model.selectedClip?.flipV == true) {
                        model.flip(id, horizontal: false)
                    }
                    OptionTile(icon: "arrow.counterclockwise", title: "Reset", selected: false) {
                        ratio = 0
                        zoom = 1
                        panX = 0
                        panY = 0
                        model.setCrop(id, nil)
                    }
                }
                SubLabel(text: "Ratio")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(ratios.indices, id: \.self) { i in
                        WordChip(title: ratios[i].0, selected: abs(ratio - ratios[i].1) < 0.001) {
                            ratio = ratios[i].1
                            commit(id)
                        }
                    }
                }
                SXSlider(title: "Zoom", value: $zoom, range: 1...4, format: "%.2f×", onCommit: { commit(id) })
                SXSlider(title: "Move X", value: $panX, range: -1...1, onCommit: { commit(id) })
                SXSlider(title: "Move Y", value: $panY, range: -1...1, onCommit: { commit(id) })
            } else {
                Text("Select a video or photo first.")
                    .font(.ui(14))
                    .foregroundColor(SX.C.muted)
            }
        }
        .task { await loadRatio() }
    }

    private func commit(_ id: UUID) {
        var base = ratio > 0 ? CropRect.centred(ratio: ratio, sourceRatio: sourceRatio) : .full
        let w = base.width / zoom
        let h = base.height / zoom
        let cx = base.x + base.width / 2 + panX * (base.width - w) / 2
        let cy = base.y + base.height / 2 + panY * (base.height - h) / 2
        base = CropRect(x: min(max(cx - w / 2, 0), 1 - w), y: min(max(cy - h / 2, 0), 1 - h), width: w, height: h)
        model.setCrop(id, base)
    }

    private func loadRatio() async {
        guard let c = model.selectedClip, let assetID = c.assetID else { return }
        var size = CGSize(width: 1, height: 1)
        if c.kind == .photo {
            if let img = UIImage(contentsOfFile: MediaStore.url(for: assetID).path) { size = img.size }
        } else {
            let asset = AVURLAsset(url: MediaStore.url(for: assetID))
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let natural = try? await track.load(.naturalSize),
               let t = try? await track.load(.preferredTransform) {
                let r = natural.applying(t)
                size = CGSize(width: abs(r.width), height: abs(r.height))
            }
        }
        let turns = model.selectedClip?.quarterTurns ?? 0
        if turns % 2 == 1 { size = CGSize(width: size.height, height: size.width) }
        if size.height > 0 { sourceRatio = Double(size.width / size.height) }
    }
}

// MARK: - Blend & opacity

struct BlendSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode: LayerBlend = .normal
    @State private var opacity = 1.0
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ToolSheetScaffold(title: "Blend", subtitle: "How this clip mixes with what is under it.", onClose: { dismiss() }) {
            if let id = model.selection {
                SXSlider(title: "Opacity", value: $opacity, range: 0...1, format: "%.0f%%", scale: 100, onCommit: {
                    model.setOpacity(id, opacity)
                })
                if model.selectedIsOverlay {
                    SubLabel(text: "Mode")
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(LayerBlend.allCases, id: \.self) { m in
                            WordChip(title: Blends.title(m), selected: mode == m) {
                                mode = m
                                model.setBlend(id, m)
                            }
                        }
                    }
                } else {
                    Text("Blend modes work on overlay clips. Add one with Overlay.")
                        .font(.ui(12.5))
                        .foregroundColor(SX.C.muted)
                }
            }
        }
        .onAppear {
            mode = model.selectedClip?.blend ?? .normal
            if let c = model.selectedClip { opacity = model.transformAtPlayhead(c).opacity }
        }
    }
}

// MARK: - Canvas

struct CanvasSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var bg = CanvasBackground.standard
    private let ratioColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ToolSheetScaffold(title: "Canvas", subtitle: "Format and the background behind your clips.", onClose: { dismiss() }) {
            SubLabel(text: "Ratio")
            LazyVGrid(columns: ratioColumns, spacing: 8) {
                ForEach(CanvasAspect.allCases, id: \.self) { a in
                    WordChip(title: a.label, selected: model.project.aspect == a) {
                        model.setAspect(a)
                    }
                }
            }
            SubLabel(text: "Background")
            HStack(spacing: 8) {
                WordChip(title: "Blur", selected: bg.kind == .blur) { bg.kind = .blur; commit() }
                WordChip(title: "Colour", selected: bg.kind == .color) { bg.kind = .color; commit() }
                WordChip(title: "Gradient", selected: bg.kind == .gradient) { bg.kind = .gradient; commit() }
            }
            switch bg.kind {
            case .blur:
                SXSlider(title: "Blur", value: $bg.blur, range: 0...1, format: "%.0f%%", scale: 100, onCommit: commit)
            case .color:
                ColorSwatches(selection: bg.color) { hex in
                    bg.color = hex
                    commit()
                }
            case .gradient:
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SheetKit.gradients.indices, id: \.self) { i in
                            let pair = SheetKit.gradients[i]
                            Button {
                                bg.color = pair.0
                                bg.color2 = pair.1
                                commit()
                            } label: {
                                LinearGradient(colors: [Color(UIColor(hex: pair.0)), Color(UIColor(hex: pair.1))], startPoint: .top, endPoint: .bottom)
                                    .frame(width: 54, height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(bg.color == pair.0 && bg.color2 == pair.1 ? SX.C.accent : SX.C.line2, lineWidth: bg.color == pair.0 && bg.color2 == pair.1 ? 2.5 : 1)
                                    )
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
        .onAppear { bg = model.project.background ?? .standard }
    }

    private func commit() {
        model.setBackground(bg)
    }
}

// MARK: - Beats

struct BeatsSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var sensitivity = 0.5

    var body: some View {
        ToolSheetScaffold(title: "Beats", subtitle: "Markers on the timeline that edits snap to.", onClose: { dismiss() }) {
            HStack {
                Text("\(model.markerCount)")
                    .font(.dot(40))
                    .foregroundColor(SX.C.ink)
                Text("markers")
                    .font(.ui(14))
                    .foregroundColor(SX.C.body)
                Spacer()
            }
            SXSlider(title: "Sensitivity", value: $sensitivity, range: 0...1, format: "%.0f%%", scale: 100, onCommit: {})
            Button {
                dismiss()
                Task { await model.detectBeats(sensitivity: sensitivity) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "metronome")
                    Text("Find beats in the music")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            Button {
                model.toggleMarkerAtPlayhead()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark")
                    Text("Add or remove marker at playhead")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            Button {
                model.syncToBeats()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "scissors")
                    Text("Cut clips to the beat")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(model.markerCount == 0)
            Button {
                model.clearMarkers()
            } label: {
                Text("Clear markers")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(model.markerCount == 0)
            Text("Cut to the beat lays the main track out so each clip ends on the next marker. Photos fit any beat; videos stop where their footage ends.")
                .font(.ui(12.5))
                .foregroundColor(SX.C.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
