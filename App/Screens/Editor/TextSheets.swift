import SwiftUI
import UIKit
import UniformTypeIdentifiers
import SCYDECore

// MARK: - Text (content, style, animation, voice)

struct TextSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var tab = 0
    @State private var style = TextStyle.caption
    @State private var importingSRT = false
    @State private var language = "auto"
    @State private var rate = 1.0
    @State private var pitch = 1.0
    @FocusState private var focused: Bool

    private var editing: Bool { model.selectedIsText }

    var body: some View {
        ToolSheetScaffold(title: editing ? "Edit text" : "Add text", onClose: { dismiss() }) {
            Picker("", selection: $tab) {
                Text("Text").tag(0)
                Text("Style").tag(1)
                Text("Animate").tag(2)
                Text("Voice").tag(3)
            }
            .pickerStyle(.segmented)
            switch tab {
            case 1: TextStylePanel(style: $style, onCommit: commitStyle)
            case 2: AnimationPanel(style: $style, onCommit: commitStyle)
            case 3: voicePanel
            default: textPanel
            }
        }
        .onAppear {
            text = editing ? (model.selectedClip?.text ?? "") : ""
            style = (editing ? model.selectedClip?.textStyle : nil) ?? .caption
            tab = model.textTab
            model.textTab = 0
            focused = tab == 0 && !Launch.isAutomation
        }
        .fileImporter(
            isPresented: $importingSRT,
            allowedContentTypes: [UTType(filenameExtension: "srt") ?? .plainText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.importSubtitles(from: url)
                dismiss()
            }
        }
    }

    private func commitStyle() {
        if editing, let id = model.selection {
            model.setTextStyle(id, style)
        }
    }

    private var textPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Type something", text: $text, axis: .vertical)
                .font(.display(22))
                .foregroundColor(SX.C.ink)
                .lineLimit(1...5)
                .focused($focused)
                .padding(16)
                .sxCard(radius: SX.R.l)
            Button {
                if editing { model.updateText(text) } else { model.addStyledText(text, style: style) }
                dismiss()
            } label: {
                Text(editing ? "Save text" : "Add to timeline")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if !editing {
                Text("Pick a look in Style and an entrance in Animate before adding, or change them later.")
                    .font(.ui(12.5))
                    .foregroundColor(SX.C.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    importingSRT = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "captions.bubble")
                        Text("Import subtitles (.srt)")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var voicePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reads the text aloud with an on-device voice and adds it to the audio track.")
                .font(.ui(13))
                .foregroundColor(SX.C.body)
                .fixedSize(horizontal: false, vertical: true)
            SubLabel(text: "Language")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(SpeechVoices.all) { v in
                    WordChip(title: v.name, selected: language == v.id) { language = v.id }
                }
            }
            SXSlider(title: "Speed", value: $rate, range: 0.5...1.6, format: "%.2f×", onCommit: {})
            SXSlider(title: "Pitch", value: $pitch, range: 0.6...1.6, format: "%.2f", onCommit: {})
            Button {
                let words = text
                dismiss()
                Task { await model.readAloud(words, language: language, rate: rate, pitch: pitch) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                    Text("Create voice-over")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

// MARK: - Style panel

struct TextStylePanel: View {
    @Binding var style: TextStyle
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubLabel(text: "Presets")
            presets
            SubLabel(text: "Font")
            fonts
            SubLabel(text: "Colour")
            ColorSwatches(selection: style.color) { hex in
                style.color = hex
                onCommit()
            }
            SubLabel(text: "Background")
            backgrounds
            if style.background != .none {
                ColorSwatches(selection: style.backgroundColor) { hex in
                    style.backgroundColor = hex
                    if style.backgroundOpacity < 0.2 { style.backgroundOpacity = 1 }
                    onCommit()
                }
                SXSlider(title: "Background opacity", value: $style.backgroundOpacity, range: 0...1, format: "%.0f%%", scale: 100, onCommit: onCommit)
            }
            SubLabel(text: "Outline")
            SXSlider(title: "Outline", value: $style.stroke, range: 0...0.3, format: "%.0f", scale: 100, onCommit: onCommit)
            if style.stroke > 0.005 {
                ColorSwatches(selection: style.strokeColor) { hex in
                    style.strokeColor = hex
                    onCommit()
                }
            }
            toggles
            SXSlider(title: "Size", value: $style.size, range: 0.4...3.5, format: "%.0f%%", scale: 100, onCommit: onCommit)
            SXSlider(title: "Letter spacing", value: $style.tracking, range: -0.05...0.5, format: "%.2f", onCommit: onCommit)
            SXSlider(title: "Vertical position", value: $style.anchorY, range: -0.45...0.45, format: "%.2f", onCommit: onCommit)
            Picker("", selection: Binding(get: { style.align }, set: { style.align = $0; onCommit() })) {
                Image(systemName: "text.alignleft").tag(TextAlign.left)
                Image(systemName: "text.aligncenter").tag(TextAlign.center)
                Image(systemName: "text.alignright").tag(TextAlign.right)
            }
            .pickerStyle(.segmented)
        }
    }

    private var presets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TextPreset.all) { preset in
                    Button {
                        Haptics.selection()
                        var s = preset.style
                        // Keep the position the user chose.
                        if preset.style.anchorY == TextStyle.caption.anchorY { s.anchorY = style.anchorY }
                        style = s
                        onCommit()
                    } label: {
                        VStack(spacing: 6) {
                            PresetSwatch(style: preset.style)
                                .frame(width: 78, height: 54)
                            Text(preset.name.loc)
                                .font(.ui(11, .medium, fixed: true))
                                .foregroundColor(SX.C.body)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var fonts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TextFont.all) { font in
                    Button {
                        Haptics.selection()
                        style.font = font.id
                        onCommit()
                    } label: {
                        Text(font.name)
                            .font(Font(font.uiFont(16) as CTFont))
                            .foregroundColor(style.font == font.id ? SX.C.onAccent : SX.C.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(style.font == font.id ? AnyShapeStyle(SX.accentGradient) : AnyShapeStyle(SX.C.glass))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(style.font == font.id ? Color.clear : SX.C.line2, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var backgrounds: some View {
        HStack(spacing: 8) {
            ForEach(TextBackground.allCases, id: \.self) { bg in
                WordChip(title: Self.title(bg), selected: style.background == bg) {
                    style.background = bg
                    onCommit()
                }
            }
        }
    }

    private var toggles: some View {
        HStack(spacing: 8) {
            WordChip(title: "Shadow", selected: style.shadow) {
                style.shadow.toggle()
                onCommit()
            }
            WordChip(title: "Glow", selected: style.glow) {
                style.glow.toggle()
                onCommit()
            }
            WordChip(title: "CAPS", selected: style.uppercase) {
                style.uppercase.toggle()
                onCommit()
            }
        }
    }

    static func title(_ bg: TextBackground) -> String {
        switch bg {
        case .none: return "None"
        case .pill: return "Pill"
        case .box: return "Box"
        case .rounded: return "Rounded"
        }
    }
}

/// Small "Aa" swatch showing a text preset.
private struct PresetSwatch: View {
    let style: TextStyle

    var body: some View {
        let font = TextFont.find(style.font).uiFont(18 * CGFloat(min(max(style.size, 0.8), 1.3)))
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor(hex: 0x262A35)))
            Text(style.uppercase ? "AA" : "Aa")
                .font(Font(font as CTFont))
                .foregroundColor(Color(UIColor(hex: style.color)))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: style.background == .pill ? 12 : (style.background == .rounded ? 5 : 0), style: .continuous)
                        .fill(Color(UIColor(hex: style.backgroundColor)).opacity(style.background == .none ? 0 : style.backgroundOpacity))
                )
                .shadow(color: style.glow ? Color(UIColor(hex: style.color)).opacity(0.9) : .clear, radius: 6)
        }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SX.C.line2, lineWidth: 1))
    }
}

// MARK: - Animation panel

struct AnimationPanel: View {
    @Binding var style: TextStyle
    let onCommit: () -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubLabel(text: "In")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(TextAnimation.allCases, id: \.self) { a in
                    WordChip(title: a.title, selected: style.animIn == a) {
                        style.animIn = a
                        onCommit()
                    }
                }
            }
            SubLabel(text: "Out")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(TextAnimation.allCases, id: \.self) { a in
                    WordChip(title: a.title, selected: style.animOut == a) {
                        style.animOut = a
                        onCommit()
                    }
                }
            }
            SubLabel(text: "Loop")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(TextLoop.allCases, id: \.self) { l in
                    WordChip(title: l.title, selected: style.loop == l) {
                        style.loop = l
                        onCommit()
                    }
                }
            }
            SXSlider(title: "Animation length", value: $style.animDuration, range: 0.15...2, format: "%.1fs", onCommit: onCommit)
        }
    }
}

// MARK: - Sticker style and animation

struct AnimateSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var style = TextStyle.sticker

    var body: some View {
        ToolSheetScaffold(title: "Animation", subtitle: "Entrance, exit and loop.", onClose: { dismiss() }) {
            if model.selectedIsGraphic {
                if model.selectedIsSticker {
                    SXSlider(title: "Size", value: $style.size, range: 0.8...8, format: "%.0f%%", scale: 100 / 3, onCommit: commit)
                    if model.selectedClip?.text?.hasPrefix("sf:") == true {
                        SubLabel(text: "Colour")
                        ColorSwatches(selection: style.color) { hex in
                            style.color = hex
                            commit()
                        }
                    }
                    HStack(spacing: 8) {
                        WordChip(title: "Shadow", selected: style.shadow) { style.shadow.toggle(); commit() }
                        WordChip(title: "Glow", selected: style.glow) { style.glow.toggle(); commit() }
                    }
                }
                AnimationPanel(style: $style, onCommit: commit)
            } else if model.selectedIsVisual {
                SubLabel(text: "Presets")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.combos.indices, id: \.self) { i in
                            WordChip(title: Self.combos[i].0, selected: false) {
                                let c = Self.combos[i].1
                                style.animIn = c.animIn
                                style.animOut = c.animOut
                                style.loop = c.loop
                                style.animDuration = c.duration
                                commit()
                            }
                            .frame(width: 104)
                        }
                    }
                }
                AnimationPanel(style: $style, onCommit: commit)
            } else {
                Text("Select a clip, text or sticker first.")
                    .font(.ui(14))
                    .foregroundColor(SX.C.muted)
            }
        }
        .onAppear {
            let c = model.selectedClip
            if let c = c, c.kind == .video || c.kind == .photo {
                let m = c.motion ?? ClipAnimation()
                style = TextStyle(animIn: m.animIn, animOut: m.animOut, loop: m.loop, animDuration: m.duration)
            } else {
                style = c?.textStyle ?? (c?.kind == .sticker ? .sticker : .caption)
            }
        }
    }

    /// Ready-made clip motion combinations.
    static let combos: [(String, ClipAnimation)] = [
        ("Zoom in", ClipAnimation(animIn: .zoom, duration: 0.5)),
        ("Pop", ClipAnimation(animIn: .pop, duration: 0.45)),
        ("Swing", ClipAnimation(animIn: .swing, animOut: .fade, duration: 0.6)),
        ("Slide", ClipAnimation(animIn: .slideLeft, animOut: .slideLeft, duration: 0.45)),
        ("Spin", ClipAnimation(animIn: .spin, duration: 0.6)),
        ("Blur in", ClipAnimation(animIn: .blur, animOut: .blur, duration: 0.5)),
        ("Bounce", ClipAnimation(animIn: .bounce, duration: 0.7)),
        ("Shake", ClipAnimation(loop: .shake)),
        ("Pulse", ClipAnimation(loop: .pulse)),
        ("Jelly", ClipAnimation(loop: .jelly)),
    ]

    private func commit() {
        guard let id = model.selection, let c = model.selectedClip else { return }
        if c.kind == .video || c.kind == .photo {
            model.setMotion(id, ClipAnimation(animIn: style.animIn, animOut: style.animOut, loop: style.loop, duration: style.animDuration))
        } else {
            model.setTextStyle(id, style)
        }
    }
}

// MARK: - Stickers

struct StickerSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var group = StickerLibrary.groups[0].id
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        ToolSheetScaffold(
            title: model.selectedIsSticker ? "Replace sticker" : "Stickers",
            subtitle: "Added at the playhead for 3 seconds. Drag, pinch and rotate it on the preview.",
            onClose: { dismiss() }
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StickerLibrary.groups) { g in
                        FilterChip(title: g.name, selected: group == g.id) { group = g.id }
                    }
                }
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items, id: \.self) { item in
                    Button {
                        model.addSticker(item)
                        dismiss()
                    } label: {
                        StickerGlyph(id: item)
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SX.C.glass))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(EditorViewModel.stickerName(item))
                }
            }
        }
    }

    private var items: [String] {
        StickerLibrary.groups.first { $0.id == group }?.items ?? []
    }
}

struct StickerGlyph: View {
    let id: String

    var body: some View {
        if id.hasPrefix("sf:") {
            Image(systemName: String(id.dropFirst(3)))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SX.C.ink)
        } else {
            Text(id).font(.system(size: 30))
        }
    }
}
