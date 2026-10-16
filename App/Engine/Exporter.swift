import AVFoundation
import Photos
import SwiftUI
import SCYDECore

/// Renders a project to an MP4 with the same compositor the preview uses.
@MainActor
final class Exporter: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case exporting(Double)
        case finished(URL)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var savedToPhotos = false

    private let builder = CompositionBuilder()
    private var session: AVAssetExportSession?
    private var progressTask: Task<Void, Never>?

    var isBusy: Bool {
        switch state {
        case .preparing, .exporting: return true
        default: return false
        }
    }

    func start(project: Project) {
        guard !isBusy else { return }
        savedToPhotos = false
        state = .preparing
        Task { [weak self] in
            await self?.run(project)
        }
    }

    func cancel() {
        session?.cancelExport()
    }

    func reset() {
        if !isBusy { state = .idle }
    }

    private func run(_ project: Project) async {
        let settings = project.export
        let size = settings.pixelSize(for: project.aspect)
        guard let built = await builder.build(
            project,
            renderSize: CGSize(width: size.width, height: size.height),
            fps: settings.fps
        ) else {
            state = .failed("Nothing to export yet. Add a video or photo first.".loc)
            return
        }

        let preset = settings.codec == .hevc ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: built.composition, presetName: preset) else {
            state = .failed("This iPhone cannot export with %@.".locf(settings.codec.label))
            return
        }

        let url = Self.outputURL(for: project)
        try? FileManager.default.removeItem(at: url)
        session.outputURL = url
        session.outputFileType = .mp4
        session.videoComposition = built.videoComposition
        session.audioMix = built.audioMix
        session.shouldOptimizeForNetworkUse = true
        self.session = session

        state = .exporting(0)
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self = self, let s = self.session else { return }
                if case .exporting = self.state {
                    self.state = .exporting(Double(s.progress))
                }
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously {
                continuation.resume()
            }
        }
        progressTask?.cancel()
        progressTask = nil

        switch session.status {
        case .completed:
            state = .finished(url)
            Haptics.success()
        case .cancelled:
            state = .idle
        default:
            state = .failed(session.error?.localizedDescription ?? "Export failed.".loc)
        }
        self.session = nil
    }

    func saveToPhotos() async {
        guard case let .finished(url) = state else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            state = .failed("Allow SCYDE to add to Photos in Settings to save videos.".loc)
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: url, options: nil)
            }
            savedToPhotos = true
            Haptics.success()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func outputURL(for project: Project) -> URL {
        let safe = project.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let stamp = Int(Date().timeIntervalSince1970)
        let name = "SCYDE-\(safe.isEmpty ? "video" : safe)-\(stamp).mp4"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
}
