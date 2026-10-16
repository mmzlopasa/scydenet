import AVFoundation
import Photos
import UIKit
import SCYDECore

/// Saves the composed frame under the playhead (all layers, looks and text) to Photos.
extension EditorViewModel {
    func saveSnapshot() async {
        guard hasPlayableMedia else {
            showToast("Import media first")
            return
        }
        stopPlayback()
        busyMessage = "Saving frame"
        defer { busyMessage = nil }
        let r = project.aspect.ratio
        let long: Double = 1920
        func even(_ v: Double) -> Double { (v / 2).rounded() * 2 }
        let size = r < 1 ? CGSize(width: even(long * r), height: long) : CGSize(width: long, height: even(long / r))
        let builder = CompositionBuilder()
        guard let built = await builder.build(project, renderSize: size, fps: 30) else {
            showToast("Could not render this frame")
            return
        }
        let seconds = min(max(0, playhead), max(0, project.duration - 0.05))
        let generator = AVAssetImageGenerator(asset: built.composition)
        generator.videoComposition = built.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image: UIImage? = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let cg = try? generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil) else { return nil }
            return UIImage(cgImage: cg)
        }.value
        guard let frame = image else {
            showToast("Could not render this frame")
            return
        }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            showToast("Allow adding photos in Settings to save frames")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: frame)
            }
            Haptics.success()
            showToast("Frame saved to Photos")
        } catch {
            showToast("Could not save the frame")
        }
    }
}
