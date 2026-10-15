import SwiftUI
import SCYDECore

struct ExportSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    private static let bytes: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useMB, .useGB]
        return f
    }()

    var body: some View {
        let settings = model.project.export
        let size = settings.pixelSize(for: model.project.aspect)
        let estimate = settings.estimatedBytes(duration: model.duration, aspect: model.project.aspect)

        ZStack {
            SX.C.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Export")
                                .font(.display(28))
                                .foregroundColor(SX.C.ink)
                            Text(model.project.name)
                                .font(.ui(14))
                                .foregroundColor(SX.C.body)
                        }
                        Spacer()
                        GlassIconButton(systemName: "xmark", label: "Close", size: 36) { dismiss() }
                    }

                    summary(width: size.width, height: size.height, estimate: estimate, settings: settings)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(index: "01", title: "Resolution")
                        ChipRow(
                            items: ExportSettings.Resolution.allCases,
                            selection: settings.resolution,
                            title: { $0.label }
                        ) { r in
                            model.updateExport { $0.resolution = r }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(index: "02", title: "Frame rate")
                        ChipRow(
                            items: ExportSettings.fpsOptions,
                            selection: settings.fps,
                            title: { "\($0)" }
                        ) { fps in
                            model.updateExport { $0.fps = fps }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(index: "03", title: "Codec")
                        ChipRow(
                            items: ExportSettings.Codec.allCases,
                            selection: settings.codec,
                            title: { $0.label },
                            caption: { $0 == .hevc ? "smaller files" : "plays everywhere" }
                        ) { codec in
                            model.updateExport { $0.codec = codec }
                        }
                    }

                    VStack(spacing: 10) {
                        Button {} label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Export video")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(true)

                        Text("Rendering arrives in the next build. These settings are saved with the project.")
                            .font(.ui(12.5))
                            .foregroundColor(SX.C.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 30)
            }
        }
    }

    private func summary(width: Int, height: Int, estimate: Int64, settings: ExportSettings) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                let r = CGFloat(model.project.aspect.ratio)
                let box: CGFloat = 54
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(SX.C.accent.opacity(0.18))
                    .frame(width: r < 1 ? box * r : box, height: r < 1 ? box : box / r)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(SX.C.accent, lineWidth: 1.5)
                    .frame(width: r < 1 ? box * r : box, height: r < 1 ? box : box / r)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(width) × \(height)")
                    .font(.mono(20, medium: true))
                    .foregroundColor(SX.C.ink)
                Text("\(settings.fps) fps · \(settings.codec.label) · \(Timecode.short(model.duration))")
                    .font(.mono(11))
                    .foregroundColor(SX.C.muted)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text("≈ " + Self.bytes.string(fromByteCount: estimate))
                    .font(.ui(15, .semibold, fixed: true))
                    .foregroundColor(SX.C.ink)
                Text("estimated")
                    .font(.mono(10))
                    .foregroundColor(SX.C.muted)
            }
        }
        .padding(16)
        .sxCard(radius: SX.R.l)
    }
}
