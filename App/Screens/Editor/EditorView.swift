import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import SCYDECore

struct EditorView: View {
    @StateObject private var model: EditorViewModel
    let onClose: () -> Void

    init(project: Project, onSave: @escaping (Project) -> Void, onClose: @escaping () -> Void) {
        _model = StateObject(wrappedValue: EditorViewModel(project: project, onSave: onSave))
        self.onClose = onClose
    }

    private var timelineHeight: CGFloat {
        let lanes = model.visibleTracks.reduce(CGFloat(0)) { $0 + $1.role.laneHeight + 8 }
        return max(150, 6 + 26 + 8 + lanes + 14)
    }

    var body: some View {
        ZStack {
            SX.C.editorBg.ignoresSafeArea()
            VStack(spacing: 0) {
                EditorTopBar(model: model) {
                    model.stopPlayback()
                    model.flushSave()
                    onClose()
                }
                PreviewCanvas(model: model)
                    .frame(maxHeight: .infinity)
                TransportBar(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                TimelinePanel(model: model)
                    .frame(height: timelineHeight)
                    .animation(SX.spring, value: model.visibleTracks.count)
                ToolDock(model: model)
            }

            if let toast = model.toast {
                VStack {
                    Spacer()
                    ToastView(text: toast)
                        .padding(.bottom, timelineHeight + 110)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }

            if model.importing {
                ImportingOverlay(text: "Importing")
                    .transition(.opacity)
            } else if let busy = model.busyMessage {
                ImportingOverlay(text: busy)
                    .transition(.opacity)
            }
        }
        .sheet(item: $model.activeSheet) { sheet in
            Group {
                switch sheet {
                case .speed: SpeedSheet(model: model)
                case .text: TextSheet(model: model)
                case .look: LookSheet(model: model)
                case .voiceover: VoiceOverSheet(model: model)
                case .voiceFX: VoiceFXSheet(model: model)
                case .cover: CoverSheet(model: model)
                }
            }
            .presentationDetents(sheet == .cover ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Add audio", isPresented: $model.showAudioMenu, titleVisibility: .visible) {
            Button("Music from Files") { model.showMusicImporter = true }
            Button("Record voice-over") { model.activeSheet = .voiceover }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(isPresented: $model.showMusicImporter, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.importMusic(from: url)
            }
        }
        .sheet(isPresented: $model.showExport) {
            ExportSheet(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { model.onAppear() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            model.stopPlayback()
            model.flushSave()
        }
    }
}

// MARK: - Top bar

private struct EditorTopBar: View {
    @ObservedObject var model: EditorViewModel
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            GlassIconButton(systemName: "chevron.down", label: "Close", size: 38, action: onClose)
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(model.project.name)
                    .font(.ui(15, .semibold, fixed: true))
                    .foregroundColor(SX.C.ink)
                    .lineLimit(1)
                Text("\(model.project.aspect.label) · \(model.project.fps) fps")
                    .font(.mono(10))
                    .foregroundColor(SX.C.muted)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.light()
                model.stopPlayback()
                model.showExport = true
            } label: {
                HStack(spacing: 6) {
                    Text("Export")
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

private struct PreviewCanvas: View {
    @ObservedObject var model: EditorViewModel

    var body: some View {
        GeometryReader { geo in
            let r = CGFloat(model.project.aspect.ratio)
            let availW = max(geo.size.width - 32, 10)
            let availH = max(geo.size.height - 12, 10)
            let w = min(availW, availH * r)
            let h = w / r
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            ZStack {
                shape.fill(Color.black)
                if model.hasPlayer {
                    PlayerLayerView(player: model.player)
                        .frame(width: w, height: h)
                } else if let image = model.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .blur(radius: 28)
                        .opacity(0.55)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: w, height: h)
                } else if model.project.isEmpty {
                    EmptyPreview(model: model)
                }
            }
            .frame(width: w, height: h)
            .overlay(alignment: .topLeading) {
                if Launch.sampleMedia && !model.diagnostics.isEmpty {
                    Text(model.diagnostics)
                        .font(.mono(9))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.45), radius: 30, x: 0, y: 18)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

private struct EmptyPreview: View {
    @ObservedObject var model: EditorViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(UIColor(hex: 0x1A1D25)), Color(UIColor(hex: 0x0D0F14))],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [SX.C.gold.opacity(0.16), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 320
            )
            VStack(spacing: 14) {
                PhotosPicker(
                    selection: $model.pickerItems,
                    maxSelectionCount: 20,
                    matching: .any(of: [.videos, .images])
                ) {
                    ZStack {
                        Circle()
                            .fill(SX.C.gold)
                            .frame(width: 68, height: 68)
                            .shadow(color: SX.C.gold.opacity(0.5), radius: 20, x: 0, y: 8)
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(SX.C.onClipDark)
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Import media")
                Text("Import media")
                    .font(.ui(16, .semibold, fixed: true))
                    .foregroundColor(Color(UIColor(hex: 0xF5F2FF)))
                Text("Videos and photos from your library")
                    .font(.ui(12.5, fixed: true))
                    .foregroundColor(Color(UIColor(hex: 0x8F8BBA)))
            }
            .padding(20)
        }
    }
}

// MARK: - Transport

private struct TransportBar: View {
    @ObservedObject var model: EditorViewModel

    var body: some View {
        ZStack {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Timecode.string(model.playhead, fps: model.project.fps))
                        .font(.dot(22))
                        .foregroundColor(SX.C.ink)
                        .monospacedDigit()
                    Text("/ " + Timecode.string(model.duration, fps: model.project.fps))
                        .font(.mono(10.5))
                        .foregroundColor(SX.C.muted)
                }
                Spacer()
                HStack(spacing: 10) {
                    GlassIconButton(systemName: "arrow.uturn.backward", label: "Undo", size: 38, enabled: model.canUndo) {
                        model.undo()
                    }
                    GlassIconButton(systemName: "arrow.uturn.forward", label: "Redo", size: 38, enabled: model.canRedo) {
                        model.redo()
                    }
                }
            }
            Button {
                Haptics.light()
                model.togglePlay()
            } label: {
                ZStack {
                    Circle()
                        .fill(SX.accentGradient)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0)], startPoint: .top, endPoint: .center),
                                lineWidth: 1
                            )
                        )
                        .shadow(color: SX.C.accent.opacity(0.45), radius: 16, x: 0, y: 6)
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(SX.C.onAccent)
                        .offset(x: model.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(PressableStyle(scale: 0.92))
            .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
        }
    }
}

// MARK: - Importing overlay

private struct ImportingOverlay: View {
    var text: String = "Importing"

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(SX.C.accent)
                    .scaleEffect(1.2)
                Text(text)
                    .font(.ui(14, .medium, fixed: true))
                    .foregroundColor(SX.C.ink)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 24)
            .sxCard(radius: SX.R.l)
        }
    }
}
