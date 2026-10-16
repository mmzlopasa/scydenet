import SwiftUI
import SCYDECore

struct ExportSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exporter = Exporter()

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
                        GlassIconButton(systemName: "xmark", label: "Close", size: 36, enabled: !exporter.isBusy) { dismiss() }
                    }

                    summary(width: size.width, height: size.height, estimate: estimate, settings: settings)

                    VStack(spacing: 12) {
                        exportControls
                    }

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

                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 30)
            }
        }
        .interactiveDismissDisabled(exporter.isBusy)
        .onAppear {
            if Launch.autoExport {
                exporter.start(project: model.project)
            }
        }
    }

    @ViewBuilder
    private var exportControls: some View {
        switch exporter.state {
        case .idle:
            Button {
                model.stopPlayback()
                exporter.start(project: model.project)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .bold))
                    Text("Export video")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.project.isEmpty)
            if model.hasTextClips, let srt = model.subtitlesFile() {
                ShareLink(item: srt) {
                    HStack(spacing: 6) {
                        Image(systemName: "captions.bubble")
                        Text("Export subtitles (.srt)")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Text("Renders with the same engine as the preview. Settings are saved with the project.")
                .font(.ui(12.5))
                .foregroundColor(SX.C.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

        case .preparing:
            ExportProgress(progress: nil)

        case let .exporting(progress):
            ExportProgress(progress: progress)
            Button {
                exporter.cancel()
            } label: {
                Text("Cancel")
            }
            .buttonStyle(SecondaryButtonStyle())

        case let .finished(url):
            HStack(spacing: 14) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(SX.C.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(SX.accentGradient))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Export finished")
                        .font(.display(18))
                        .foregroundColor(SX.C.ink)
                    Text(Self.fileSize(url))
                        .font(.mono(11))
                        .foregroundColor(SX.C.muted)
                }
                Spacer()
            }
            .padding(16)
            .sxCard(radius: SX.R.l)

            Button {
                Task { await exporter.saveToPhotos() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: exporter.savedToPhotos ? "checkmark.circle.fill" : "photo.on.rectangle")
                        .font(.system(size: 15, weight: .bold))
                    Text(exporter.savedToPhotos ? "Saved to Photos" : "Save to Photos")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(exporter.savedToPhotos)

            HStack(spacing: 10) {
                ShareLink(item: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                Button {
                    exporter.reset()
                } label: {
                    Text("Export again")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

        case let .failed(message):
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(SX.C.err)
                Text(message)
                    .font(.ui(14))
                    .foregroundColor(SX.C.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(16)
            .sxCard(radius: SX.R.l)
            Button {
                exporter.reset()
            } label: {
                Text("Try again")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private static func fileSize(_ url: URL) -> String {
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        let f = ByteCountFormatter()
        f.countStyle = .file
        return "\(f.string(fromByteCount: bytes)) · MP4"
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
                Text(verbatim: "\(width) × \(height)")
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

private struct ExportProgress: View {
    let progress: Double?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(SX.C.line2, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(progress ?? 0.04))
                    .stroke(SX.accentGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: SX.C.accent.opacity(0.5), radius: 8)
                    .animation(.linear(duration: 0.12), value: progress ?? 0)
                Text(progress.map { "\(Int(($0 * 100).rounded()))%" } ?? "…")
                    .font(.dot(26))
                    .foregroundColor(SX.C.ink)
            }
            .frame(width: 120, height: 120)
            Text(progress == nil ? "Preparing" : "Rendering your video")
                .font(.ui(14, .medium, fixed: true))
                .foregroundColor(SX.C.body)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .sxCard(radius: SX.R.l)
    }
}
