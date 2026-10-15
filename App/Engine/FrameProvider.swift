import AVFoundation
import UIKit
import SCYDECore

/// Still frames for the preview while scrubbing. Phase 3 replaces this with the
/// real composition player; until then it shows the top visual clip at the playhead.
@MainActor
final class FrameProvider {
    private var generators: [String: AVAssetImageGenerator] = [:]
    private var photos: [String: UIImage] = [:]

    func frame(for project: Project, at time: Double, fallback: UIImage?) async -> UIImage? {
        let clip = project.clip(at: time, role: .main) ?? project.clip(at: time, role: .overlay)
        guard let clip = clip else { return nil }
        guard let assetID = clip.assetID else { return fallback }

        switch clip.kind {
        case .photo:
            return photo(assetID)
        case .video:
            let generator = self.generator(assetID)
            let source = clip.sourceIn + (time - clip.start) * clip.speed
            let cmTime = CMTime(seconds: max(0, source), preferredTimescale: 600)
            do {
                let result = try await generator.image(at: cmTime)
                return UIImage(cgImage: result.image)
            } catch {
                return nil
            }
        case .audio, .text:
            return nil
        }
    }

    private func generator(_ assetID: String) -> AVAssetImageGenerator {
        if let g = generators[assetID] { return g }
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: MediaStore.url(for: assetID)))
        g.appliesPreferredTrackTransform = true
        g.maximumSize = CGSize(width: 1080, height: 1080)
        let tolerance = CMTime(value: 1, timescale: 30)
        g.requestedTimeToleranceBefore = tolerance
        g.requestedTimeToleranceAfter = tolerance
        generators[assetID] = g
        return g
    }

    private func photo(_ assetID: String) -> UIImage? {
        if let p = photos[assetID] { return p }
        guard let image = UIImage(contentsOfFile: MediaStore.url(for: assetID).path) else { return nil }
        photos[assetID] = image
        return image
    }
}
