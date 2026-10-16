import Photos
import PhotosUI
import SwiftUI
import UIKit
import SCYDECore

struct CollageView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var pick: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var layoutIndex = 0
    @State private var aspect: CanvasAspect = .square1x1
    @State private var spacing: Double = 8
    @State private var radius: Double = 14
    @State private var light = false
    @State private var loading = false
    @State private var saved = false

    private let aspects: [CanvasAspect] = [.square1x1, .portrait4x5, .portrait9x16, .landscape16x9]

    private var layouts: [[CGRect]] { CollageLayouts.options(for: images.count) }

    private var preview: UIImage? {
        guard !images.isEmpty else { return nil }
        return CollageRenderer.render(
            images: images,
            frames: layouts[min(layoutIndex, max(layouts.count - 1, 0))],
            aspect: aspect,
            shortSide: 700,
            spacing: spacing,
            radius: radius,
            light: light
        )
    }

    var body: some View {
        ZStack {
            SX.C.editorBg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    GlassIconButton(systemName: "xmark", label: "Close", size: 38) { dismiss() }
                    Spacer()
                    Text("Collage")
                        .font(.ui(16, .semibold, fixed: true))
                        .foregroundColor(SX.C.ink)
                    Spacer()
                    if !images.isEmpty {
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
                        .disabled(saved)
                    } else {
                        Color.clear.frame(width: 38, height: 38)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                ZStack {
                    if let preview = preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 12)
                            .padding(20)
                    } else {
                        emptyState
                    }
                    if loading { ProgressView().tint(SX.C.accent).scaleEffect(1.3) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !images.isEmpty {
                    controls
                        .padding(16)
                        .background(SX.C.surface.ignoresSafeArea(edges: .bottom))
                }
            }
        }
        .onChange(of: pick) { items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $pick, maxSelectionCount: 6, matching: .images) {
                ZStack {
                    Circle()
                        .fill(SX.accentGradient)
                        .frame(width: 72, height: 72)
                        .shadow(color: SX.C.accent.opacity(0.45), radius: 18, x: 0, y: 8)
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(SX.C.onAccent)
                }
            }
            .buttonStyle(PressableStyle())
            Text("Choose 2 to 6 photos")
                .font(.display(20))
                .foregroundColor(SX.C.ink)
            Text("Pick a layout, spacing and corners, then save to Photos.")
                .font(.ui(14))
                .foregroundColor(SX.C.body)
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(layouts.indices, id: \.self) { i in
                        Button {
                            Haptics.selection()
                            layoutIndex = i
                            saved = false
                        } label: {
                            LayoutIcon(frames: layouts[i])
                                .frame(width: 48, height: 48)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(i == layoutIndex ? SX.C.accent.opacity(0.2) : SX.C.glass)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(i == layoutIndex ? SX.C.accent : SX.C.line2, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(PressableStyle())
                    }
                    PhotosPicker(selection: $pick, maxSelectionCount: 6, matching: .images) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(SX.C.ink)
                            .frame(width: 60, height: 60)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SX.C.glass))
                    }
                    .accessibilityLabel("Choose other photos")
                }
            }
            ChipRow(items: aspects, selection: aspect, title: { $0.label }) { value in
                aspect = value
                saved = false
            }
            HStack(spacing: 14) {
                labeledSlider("Spacing", value: $spacing, range: 0...30)
                labeledSlider("Corners", value: $radius, range: 0...40)
            }
            Toggle("Light background", isOn: Binding(get: { light }, set: { light = $0; saved = false }))
                .font(.ui(14, .medium))
                .foregroundColor(SX.C.ink)
                .tint(SX.C.accent)
        }
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.mono(9.5, medium: true))
                .tracking(1.2)
                .foregroundColor(SX.C.muted)
            Slider(value: value, in: range, onEditingChanged: { _ in saved = false })
                .tint(SX.C.accent)
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        loading = true
        defer { loading = false }
        var loaded: [UIImage] = []
        for item in items.prefix(6) {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                loaded.append(img)
            }
        }
        pick = []
        guard !loaded.isEmpty else {
            app.showToast("Could not open those photos")
            return
        }
        images = loaded
        layoutIndex = 0
        saved = false
    }

    private func save() async {
        guard !images.isEmpty else { return }
        let full = CollageRenderer.render(
            images: images,
            frames: layouts[min(layoutIndex, max(layouts.count - 1, 0))],
            aspect: aspect,
            shortSide: 2160,
            spacing: spacing * 3,
            radius: radius * 3,
            light: light
        )
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            app.showToast("Allow adding to Photos in Settings")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: full)
            }
            saved = true
            Haptics.success()
        } catch {
            app.showToast(error.localizedDescription)
        }
    }
}

private struct LayoutIcon: View {
    let frames: [CGRect]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(frames.indices, id: \.self) { i in
                    let f = frames[i]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SX.C.ink.opacity(0.75))
                        .frame(width: max(f.width * geo.size.width - 2, 1), height: max(f.height * geo.size.height - 2, 1))
                        .offset(x: f.minX * geo.size.width + 1, y: f.minY * geo.size.height + 1)
                }
            }
        }
    }
}

/// Unit-square layouts for 1–6 photos.
enum CollageLayouts {
    static func options(for count: Int) -> [[CGRect]] {
        let r = { (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) in CGRect(x: x, y: y, width: w, height: h) }
        switch count {
        case 0: return [[]]
        case 1: return [[r(0, 0, 1, 1)]]
        case 2: return [
            [r(0, 0, 0.5, 1), r(0.5, 0, 0.5, 1)],
            [r(0, 0, 1, 0.5), r(0, 0.5, 1, 0.5)],
        ]
        case 3: return [
            [r(0, 0, 0.6, 1), r(0.6, 0, 0.4, 0.5), r(0.6, 0.5, 0.4, 0.5)],
            [r(0, 0, 1, 0.6), r(0, 0.6, 0.5, 0.4), r(0.5, 0.6, 0.5, 0.4)],
            [r(0, 0, 1.0 / 3, 1), r(1.0 / 3, 0, 1.0 / 3, 1), r(2.0 / 3, 0, 1.0 / 3, 1)],
        ]
        case 4: return [
            [r(0, 0, 0.5, 0.5), r(0.5, 0, 0.5, 0.5), r(0, 0.5, 0.5, 0.5), r(0.5, 0.5, 0.5, 0.5)],
            [r(0, 0, 1, 0.6), r(0, 0.6, 1.0 / 3, 0.4), r(1.0 / 3, 0.6, 1.0 / 3, 0.4), r(2.0 / 3, 0.6, 1.0 / 3, 0.4)],
            [r(0, 0, 0.6, 1), r(0.6, 0, 0.4, 1.0 / 3), r(0.6, 1.0 / 3, 0.4, 1.0 / 3), r(0.6, 2.0 / 3, 0.4, 1.0 / 3)],
        ]
        case 5: return [
            [r(0, 0, 0.5, 0.5), r(0.5, 0, 0.5, 0.5), r(0, 0.5, 1.0 / 3, 0.5), r(1.0 / 3, 0.5, 1.0 / 3, 0.5), r(2.0 / 3, 0.5, 1.0 / 3, 0.5)],
            [r(0, 0, 1.0 / 3, 0.5), r(1.0 / 3, 0, 1.0 / 3, 0.5), r(2.0 / 3, 0, 1.0 / 3, 0.5), r(0, 0.5, 0.5, 0.5), r(0.5, 0.5, 0.5, 0.5)],
        ]
        default: return [
            [r(0, 0, 1.0 / 3, 0.5), r(1.0 / 3, 0, 1.0 / 3, 0.5), r(2.0 / 3, 0, 1.0 / 3, 0.5),
             r(0, 0.5, 1.0 / 3, 0.5), r(1.0 / 3, 0.5, 1.0 / 3, 0.5), r(2.0 / 3, 0.5, 1.0 / 3, 0.5)],
            [r(0, 0, 0.5, 1.0 / 3), r(0.5, 0, 0.5, 1.0 / 3), r(0, 1.0 / 3, 0.5, 1.0 / 3),
             r(0.5, 1.0 / 3, 0.5, 1.0 / 3), r(0, 2.0 / 3, 0.5, 1.0 / 3), r(0.5, 2.0 / 3, 0.5, 1.0 / 3)],
        ]
        }
    }
}

enum CollageRenderer {
    static func render(
        images: [UIImage],
        frames: [CGRect],
        aspect: CanvasAspect,
        shortSide: CGFloat,
        spacing: Double,
        radius: Double,
        light: Bool
    ) -> UIImage {
        let ratio = CGFloat(aspect.ratio)
        let size = ratio < 1
            ? CGSize(width: shortSide, height: (shortSide / ratio).rounded())
            : CGSize(width: (shortSide * ratio).rounded(), height: shortSide)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let gap = CGFloat(spacing)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            (light ? UIColor(hex: 0xF4F3F8) : UIColor(hex: 0x0D0F14)).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            for (i, unit) in frames.enumerated() where i < images.count {
                let rect = CGRect(
                    x: unit.minX * size.width,
                    y: unit.minY * size.height,
                    width: unit.width * size.width,
                    height: unit.height * size.height
                ).insetBy(dx: gap / 2, dy: gap / 2)
                    .offsetBy(dx: 0, dy: 0)
                let inner = rect.insetBy(dx: unit.minX == 0 ? gap / 2 : 0, dy: unit.minY == 0 ? gap / 2 : 0)
                let frame = CGRect(
                    x: inner.minX,
                    y: inner.minY,
                    width: inner.width - (unit.maxX >= 0.999 ? gap / 2 : 0),
                    height: inner.height - (unit.maxY >= 0.999 ? gap / 2 : 0)
                )
                guard frame.width > 1, frame.height > 1 else { continue }
                let img = images[i]
                let s = max(frame.width / img.size.width, frame.height / img.size.height)
                let w = img.size.width * s
                let h = img.size.height * s
                ctx.cgContext.saveGState()
                UIBezierPath(roundedRect: frame, cornerRadius: CGFloat(radius)).addClip()
                img.draw(in: CGRect(x: frame.midX - w / 2, y: frame.midY - h / 2, width: w, height: h))
                ctx.cgContext.restoreGState()
            }
        }
    }
}
