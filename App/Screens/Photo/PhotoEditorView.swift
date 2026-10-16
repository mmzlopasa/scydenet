import CoreImage
import Photos
import PhotosUI
import SwiftUI
import UIKit
import Vision
import SCYDECore

/// Person cut-out for still images (accurate quality).
enum PersonSegmenter {
    static func cutout(_ image: CIImage) -> CIImage? {
        let extent = image.extent
        guard extent.width.isFinite, extent.width > 0 else { return nil }
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let normalized = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        let handler = VNImageRequestHandler(ciImage: normalized, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let buffer = request.results?.first?.pixelBuffer else { return nil }
        var mask = CIImage(cvPixelBuffer: buffer)
        mask = mask.transformed(by: CGAffineTransform(scaleX: extent.width / mask.extent.width, y: extent.height / mask.extent.height))
        return normalized.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: mask,
        ])
    }
}

enum PhotoCrop: String, CaseIterable, Identifiable {
    case original = "Original"
    case square = "1:1"
    case portrait = "4:5"
    case story = "9:16"
    case wide = "16:9"

    var id: String { rawValue }

    var ratio: CGFloat? {
        switch self {
        case .original: return nil
        case .square: return 1
        case .portrait: return 4.0 / 5.0
        case .story: return 9.0 / 16.0
        case .wide: return 16.0 / 9.0
        }
    }
}

struct PhotoEditorView: View {
    let initialTab: Int
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var pick: [PhotosPickerItem] = []
    @State private var source: CIImage?
    @State private var preview: UIImage?
    @State private var tab = 0
    @State private var filter = "original"
    @State private var adjust = Adjustments()
    @State private var crop: PhotoCrop = .original
    @State private var turns = 0
    @State private var cutout = false
    @State private var thumbs: [String: UIImage] = [:]
    @State private var working = false
    @State private var saved = false

    private let context = CIContext()

    var body: some View {
        ZStack {
            SX.C.editorBg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                ZStack {
                    if let preview = preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .background(cutout ? CheckerBackground() : nil)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(16)
                    } else {
                        picker
                    }
                    if working {
                        ProgressView().tint(SX.C.accent).scaleEffect(1.3)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if source != nil {
                    controls
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(SX.C.surface.ignoresSafeArea(edges: .bottom))
                }
            }
        }
        .onAppear { tab = initialTab }
        .onChange(of: pick) { items in
            guard let item = items.first else { return }
            pick = []
            Task { await load(item) }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            GlassIconButton(systemName: "xmark", label: "Close", size: 38) { dismiss() }
            Spacer()
            Text("Edit photo")
                .font(.ui(16, .semibold, fixed: true))
                .foregroundColor(SX.C.ink)
            Spacer()
            if source != nil {
                Button {
                    Task { await save() }
                } label: {
                    HStack(spacing: 6) {
                        Text(saved ? "Saved" : "Save")
                        Image(systemName: saved ? "checkmark" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .buttonStyle(PillButtonStyle())
                .disabled(working || saved)
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
    }

    private var picker: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $pick, maxSelectionCount: 1, matching: .images) {
                ZStack {
                    Circle()
                        .fill(SX.accentGradient)
                        .frame(width: 72, height: 72)
                        .shadow(color: SX.C.accent.opacity(0.45), radius: 18, x: 0, y: 8)
                    Image(systemName: "photo")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(SX.C.onAccent)
                }
            }
            .buttonStyle(PressableStyle())
            Text("Choose a photo")
                .font(.display(20))
                .foregroundColor(SX.C.ink)
            Text("Filters, colour, crop and background removal. Saved back to Photos.")
                .font(.ui(14))
                .foregroundColor(SX.C.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 14) {
            Picker("", selection: $tab) {
                Text("Filters").tag(0)
                Text("Adjust").tag(1)
                Text("Crop").tag(2)
                Text("Cut-out").tag(3)
            }
            .pickerStyle(.segmented)

            Group {
                switch tab {
                case 0: filterStrip
                case 1: adjustPanel
                case 2: cropPanel
                default: cutoutPanel
                }
            }
            .frame(minHeight: 120, alignment: .top)

            if saved {
                ShareLink(item: Image(uiImage: preview ?? UIImage()), preview: SharePreview("Photo", image: Image(uiImage: preview ?? UIImage()))) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Looks.presets) { preset in
                    Button {
                        Haptics.selection()
                        filter = preset.id
                        refresh()
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                SX.C.surface3
                                if let img = thumbs[preset.id] {
                                    Image(uiImage: img).resizable().scaledToFill()
                                }
                            }
                            .frame(width: 66, height: 82)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(filter == preset.id ? SX.C.accent : Color.clear, lineWidth: 2)
                            )
                            Text(preset.name)
                                .font(.ui(11.5, .medium, fixed: true))
                                .foregroundColor(filter == preset.id ? SX.C.ink : SX.C.body)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var adjustPanel: some View {
        VStack(spacing: 10) {
            adjustSlider("Exposure", value: $adjust.exposure, range: -1.5...1.5, neutral: 0)
            adjustSlider("Contrast", value: $adjust.contrast, range: 0.6...1.4, neutral: 1)
            adjustSlider("Saturation", value: $adjust.saturation, range: 0...2, neutral: 1)
            adjustSlider("Warmth", value: $adjust.warmth, range: -1...1, neutral: 0)
            HStack(spacing: 10) {
                Button {
                    guard let src = source else { return }
                    adjust = Looks.autoAdjust(for: src, context: context)
                    refresh()
                    Haptics.success()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Auto enhance")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                Button {
                    adjust = Adjustments()
                    refresh()
                } label: { Text("Reset") }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var cropPanel: some View {
        VStack(spacing: 14) {
            ChipRow(items: PhotoCrop.allCases, selection: crop, title: { $0.rawValue }) { value in
                crop = value
                refresh()
            }
            Button {
                turns = (turns + 1) % 4
                refresh()
                Haptics.light()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rotate.right")
                    Text("Rotate 90°")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var cutoutPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(get: { cutout }, set: { cutout = $0; refresh() })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Remove background")
                        .font(.ui(16, .medium))
                        .foregroundColor(SX.C.ink)
                    Text("Keeps people, saved as a transparent PNG.")
                        .font(.ui(12.5))
                        .foregroundColor(SX.C.muted)
                }
            }
            .tint(SX.C.accent)
            .padding(16)
            .sxCard(radius: SX.R.l)
        }
    }

    private func adjustSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, neutral: Double) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.ui(13, .medium, fixed: true))
                .foregroundColor(SX.C.ink)
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: range, onEditingChanged: { editing in
                if !editing { refresh() }
            })
            .tint(SX.C.accent)
            Text(String(format: "%+.1f", value.wrappedValue - neutral))
                .font(.mono(10.5))
                .foregroundColor(SX.C.muted)
                .frame(width: 38, alignment: .trailing)
        }
    }

    // MARK: Processing

    private func load(_ item: PhotosPickerItem) async {
        working = true
        defer { working = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            app.showToast("Could not open that photo")
            return
        }
        source = image
        saved = false
        refresh()
        if let small = render(scaledTo: 160, applyLook: false) {
            thumbs = Self.filterThumbs(small, context: context)
        }
    }

    private func refresh() {
        saved = false
        preview = render(scaledTo: 1400, applyLook: true)
    }

    private func processed(_ input: CIImage, applyLook: Bool) -> CIImage {
        var img = input
        let orientations: [CGImagePropertyOrientation] = [.up, .right, .down, .left]
        if turns != 0 { img = img.oriented(orientations[turns]) }
        img = img.transformed(by: CGAffineTransform(translationX: -img.extent.minX, y: -img.extent.minY))
        if let ratio = crop.ratio {
            let e = img.extent
            var w = e.width
            var h = w / ratio
            if h > e.height {
                h = e.height
                w = h * ratio
            }
            img = img.cropped(to: CGRect(x: (e.width - w) / 2, y: (e.height - h) / 2, width: w, height: h))
            img = img.transformed(by: CGAffineTransform(translationX: -img.extent.minX, y: -img.extent.minY))
        }
        if applyLook { img = Looks.apply(img, filter: filter, adjust: adjust) }
        if cutout, let cut = PersonSegmenter.cutout(img) { img = cut }
        return img
    }

    private func render(scaledTo maxSide: CGFloat?, applyLook: Bool) -> UIImage? {
        guard var img = source else { return nil }
        if let maxSide = maxSide {
            let s = min(1, maxSide / max(img.extent.width, img.extent.height))
            img = img.transformed(by: CGAffineTransform(scaleX: s, y: s))
        }
        let out = processed(img, applyLook: applyLook)
        guard let cg = context.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func filterThumbs(_ image: UIImage, context: CIContext) -> [String: UIImage] {
        guard let cg = image.cgImage else { return [:] }
        let src = CIImage(cgImage: cg)
        var result: [String: UIImage] = [:]
        for preset in Looks.presets {
            let out = Looks.apply(src, filter: preset.id, adjust: nil)
            if let r = context.createCGImage(out, from: src.extent) { result[preset.id] = UIImage(cgImage: r) }
        }
        return result
    }

    private func save() async {
        working = true
        defer { working = false }
        guard let full = render(scaledTo: nil, applyLook: true) else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            app.showToast("Allow adding to Photos in Settings")
            return
        }
        let data: Data?
        if cutout {
            data = full.pngData()
        } else {
            data = full.jpegData(compressionQuality: 0.95)
        }
        guard let bytes = data else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: bytes, options: nil)
            }
            saved = true
            Haptics.success()
        } catch {
            app.showToast(error.localizedDescription)
        }
    }
}

/// Checkerboard behind transparent cut-outs.
struct CheckerBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 12
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = row % 2 == 0 ? 0 : s
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(Color.white.opacity(0.12)))
                    x += s * 2
                }
                y += s
                row += 1
            }
        }
        .background(Color(UIColor(hex: 0x262A35)))
    }
}
