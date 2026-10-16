import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import SCYDECore

/// Shared header for tool sheets.
struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.loc)
                    .font(.display(22))
                    .foregroundColor(SX.C.ink)
                if let subtitle = subtitle {
                    Text(subtitle.loc)
                        .font(.ui(13))
                        .foregroundColor(SX.C.body)
                }
            }
            Spacer()
            GlassIconButton(systemName: "checkmark", label: "Done", size: 36, action: onClose)
        }
    }
}

// MARK: - Speed

struct SpeedSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var speed: Double = 1

    private let presets: [Double] = [0.25, 0.5, 1, 1.5, 2, 3, 4]

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(title: "Speed", subtitle: "Slow motion or fast forward. Pitch follows speed.") { dismiss() }
                Text(String(format: "%.2g×", speed))
                    .font(.dot(40))
                    .foregroundColor(SX.C.ink)
                    .frame(maxWidth: .infinity)
                Slider(value: Binding(
                    get: { log2(speed) },
                    set: { speed = pow(2, $0) }
                ), in: -2...2, onEditingChanged: { editing in
                    if !editing { model.setSpeed(speed) }
                })
                .tint(SX.C.accent)
                ChipRow(items: presets, selection: presets.min(by: { abs($0 - speed) < abs($1 - speed) }) ?? 1, title: { String(format: "%g×", $0) }) { value in
                    speed = value
                    model.setSpeed(value)
                }
                if let c = model.selectedClip {
                    Text("Clip length \(Timecode.duration(c.duration))")
                        .font(.mono(11))
                        .foregroundColor(SX.C.muted)
                        .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onAppear { speed = model.selectedClip?.speed ?? 1 }
    }
}

// MARK: - Text

struct TextSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var importingSRT = false
    @FocusState private var focused: Bool

    private var editing: Bool { model.selectedIsText }

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: editing ? "Edit text" : "Add text", subtitle: "Shown in the lower third, like a caption.") {
                    dismiss()
                }
                TextField("Type something", text: $text, axis: .vertical)
                    .font(.display(22))
                    .foregroundColor(SX.C.ink)
                    .lineLimit(1...4)
                    .focused($focused)
                    .padding(16)
                    .sxCard(radius: SX.R.l)
                Button {
                    if editing { model.updateText(text.loc) } else { model.addText(text.loc) }
                    dismiss()
                } label: {
                    Text(editing ? "Save text" : "Add to timeline")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !editing {
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
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onAppear {
            text = editing ? (model.selectedClip?.text ?? "") : ""
            focused = !Launch.isAutomation
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
}

// MARK: - Filters & adjust

struct LookSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var clipID: UUID?
    @State private var filter: String = "original"
    @State private var adjust = Adjustments()
    @State private var tab = 0
    @State private var base: UIImage?
    @State private var thumbs: [String: UIImage] = [:]
    @State private var analysing = false

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(title: "Look", subtitle: "Filters and colour for this clip.") { dismiss() }
                Picker("", selection: $tab) {
                    Text("Filters").tag(0)
                    Text("Adjust").tag(1)
                }
                .pickerStyle(.segmented)

                if clipID == nil {
                    Text("Select a video or photo, or move the playhead over one.")
                        .font(.ui(14))
                        .foregroundColor(SX.C.muted)
                } else if tab == 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Looks.presets) { preset in
                                Button {
                                    Haptics.selection()
                                    filter = preset.id
                                    push()
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            SX.C.surface3
                                            if let img = thumbs[preset.id] {
                                                Image(uiImage: img).resizable().scaledToFill()
                                            }
                                        }
                                        .frame(width: 68, height: 86)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(filter == preset.id ? SX.C.accent : Color.clear, lineWidth: 2)
                                        )
                                        Text(preset.name.loc)
                                            .font(.ui(11.5, .medium, fixed: true))
                                            .foregroundColor(filter == preset.id ? SX.C.ink : SX.C.body)
                                    }
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    VStack(spacing: 14) {
                        slider("Exposure", value: $adjust.exposure, range: -1.5...1.5, neutral: 0)
                        slider("Contrast", value: $adjust.contrast, range: 0.6...1.4, neutral: 1)
                        slider("Saturation", value: $adjust.saturation, range: 0...2, neutral: 1)
                        slider("Warmth", value: $adjust.warmth, range: -1...1, neutral: 0)
                        HStack(spacing: 10) {
                            Button {
                                guard let id = clipID, let clip = model.project.clip(id) else { return }
                                analysing = true
                                Task {
                                    adjust = await model.suggestedAdjustments(for: clip)
                                    analysing = false
                                    push()
                                    Haptics.success()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                    Text(analysing ? "Analysing" : "Auto enhance")
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Button {
                                adjust = Adjustments()
                                push()
                            } label: {
                                Text("Reset")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onAppear {
            model.beginLook()
            let target = model.lookTarget
            clipID = target?.id
            filter = target?.filter ?? "original"
            adjust = target?.adjust ?? Adjustments()
            if let t = target, let assetID = t.assetID {
                Task {
                    let time = t.sourceIn + max(0, model.playhead - t.start) * t.speed
                    if let img = await ThumbnailCache.shared.image(assetID: assetID, kind: t.kind, at: time) {
                        base = img
                        thumbs = Self.renderThumbs(img)
                    }
                }
            }
            if Launch.autoEnhance { tab = 1 }
        }
        .onDisappear { model.endLook() }
    }

    private func push() {
        guard let id = clipID else { return }
        model.previewLook(clipID: id, filter: filter, adjust: adjust)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, neutral: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.loc)
                    .font(.ui(14, .medium, fixed: true))
                    .foregroundColor(SX.C.ink)
                Spacer()
                Text(String(format: "%+.2f", value.wrappedValue - neutral))
                    .font(.mono(11))
                    .foregroundColor(SX.C.muted)
            }
            Slider(value: value, in: range, onEditingChanged: { editing in
                if !editing { push() }
            })
            .tint(SX.C.accent)
        }
    }

    private static func renderThumbs(_ image: UIImage) -> [String: UIImage] {
        guard let cg = image.cgImage else { return [:] }
        let context = CIContext()
        let source = CIImage(cgImage: cg)
        var result: [String: UIImage] = [:]
        for preset in Looks.presets {
            let out = Looks.apply(source, filter: preset.id, adjust: nil)
            if let rendered = context.createCGImage(out, from: source.extent) {
                result[preset.id] = UIImage(cgImage: rendered)
            }
        }
        return result
    }
}

// MARK: - Voice-over

struct VoiceOverSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = VoiceRecorder()
    @State private var startAt: Double = 0
    @State private var error: String?

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(spacing: 22) {
                SheetHeader(title: "Voice-over", subtitle: "Records at the playhead (\(Timecode.string(startAt))).") {
                    if recorder.isRecording { finish() }
                    dismiss()
                }
                Spacer(minLength: 0)
                Text(Timecode.string(recorder.elapsed))
                    .font(.dot(40))
                    .foregroundColor(SX.C.ink)
                HStack(spacing: 4) {
                    ForEach(0..<24, id: \.self) { i in
                        Capsule()
                            .fill(SX.C.accent.opacity(0.85))
                            .frame(width: 4, height: 6 + CGFloat(recorder.level) * CGFloat(12 + (i * 7) % 30))
                    }
                }
                .frame(height: 50)
                .animation(.easeOut(duration: 0.08), value: recorder.level)
                Button {
                    if recorder.isRecording {
                        finish()
                        dismiss()
                    } else {
                        Task { await begin() }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(SX.C.line2, lineWidth: 4)
                            .frame(width: 88, height: 88)
                        RoundedRectangle(cornerRadius: recorder.isRecording ? 8 : 34, style: .continuous)
                            .fill(Color(UIColor(hex: 0xFF5A6E)))
                            .frame(width: recorder.isRecording ? 34 : 68, height: recorder.isRecording ? 34 : 68)
                            .animation(SX.spring, value: recorder.isRecording)
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
                if let error = error {
                    Text(error)
                        .font(.ui(13))
                        .foregroundColor(SX.C.err)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onAppear { startAt = model.playhead }
        .interactiveDismissDisabled(recorder.isRecording)
    }

    private func begin() async {
        guard await recorder.requestPermission() else {
            error = "Allow microphone access for SCYDE in Settings.".loc
            return
        }
        do {
            model.stopPlayback()
            try recorder.start()
            Haptics.medium()
        } catch {
            self.error = "Recording could not start.".loc
        }
    }

    private func finish() {
        if let result = recorder.stop() {
            model.addVoiceOver(assetID: result.assetID, duration: result.duration, at: startAt)
        }
    }
}

// MARK: - Voice effects

struct VoiceFXSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: "Voice effects", subtitle: "Creates a processed copy of the selected audio.") { dismiss() }
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(VoicePreset.allCases) { preset in
                        Button {
                            dismiss()
                            Task { await model.applyVoiceEffect(preset) }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(SX.C.accent)
                                Text(preset.title.loc)
                                    .font(.ui(13, .medium, fixed: true))
                                    .foregroundColor(SX.C.ink)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 86)
                            .sxCard(radius: SX.R.m)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }
}

// MARK: - Cover maker

struct CoverSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var frame: UIImage?
    @State private var title = ""
    @State private var saved = false
    @State private var loading = true

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SheetHeader(title: "Cover", subtitle: "Uses the frame under the playhead.") { dismiss() }
                    ZStack {
                        SX.C.surface3
                        if let img = composed {
                            Image(uiImage: img).resizable().scaledToFit()
                        } else if loading {
                            ProgressView().tint(SX.C.accent)
                        } else {
                            Text("Move the playhead over a clip.")
                                .font(.ui(13))
                                .foregroundColor(SX.C.muted)
                        }
                    }
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: SX.R.l, style: .continuous))
                    TextField("Cover title", text: $title)
                        .font(.display(18))
                        .foregroundColor(SX.C.ink)
                        .padding(14)
                        .sxCard(radius: SX.R.m)
                    Button {
                        Task { await save() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                            Text(saved ? "Saved to Photos" : "Save cover to Photos")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(composed == nil || saved)
                    if let img = composed {
                        ShareLink(item: Image(uiImage: img), preview: SharePreview("Cover", image: Image(uiImage: img))) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(20)
            }
        }
        .task {
            frame = await model.coverFrame()
            loading = false
        }
    }

    private var composed: UIImage? {
        guard let frame = frame else { return nil }
        return CoverRenderer.render(frame, title: title)
    }

    private func save() async {
        guard let img = composed else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            model.showToast("Allow adding to Photos in Settings")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: img)
            }
            saved = true
            Haptics.success()
        } catch {
            model.showToast(error.localizedDescription)
        }
    }
}

enum CoverRenderer {
    static func render(_ frame: UIImage, title: String) -> UIImage {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return frame }
        let size = frame.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = frame.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            frame.draw(in: CGRect(origin: .zero, size: size))
            let colors = [UIColor.clear.cgColor, UIColor(white: 0, alpha: 0.65).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: CGPoint(x: 0, y: size.height * 0.5), end: CGPoint(x: 0, y: size.height), options: [])
            }
            let fontSize = size.width * 0.09
            let font = UIFont(name: "Sora-Bold", size: fontSize) ?? UIFont.boldSystemFont(ofSize: fontSize)
            let style = NSMutableParagraphStyle()
            style.alignment = .left
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white, .paragraphStyle: style]
            let inset = size.width * 0.07
            let maxW = size.width - inset * 2
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: maxW, height: size.height),
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
            (text as NSString).draw(
                with: CGRect(x: inset, y: size.height - inset - bounds.height, width: maxW, height: bounds.height),
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
            UIColor(hex: 0xFFD76A).setFill()
            ctx.cgContext.fill(CGRect(x: inset, y: size.height - inset - bounds.height - fontSize * 0.45, width: fontSize * 1.2, height: max(4, fontSize * 0.09)))
        }
    }
}
