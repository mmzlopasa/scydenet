import AVFoundation
import ImageIO
import SwiftUI
import UIKit
import SCYDECore

/// Small cached frames for timeline filmstrips. Times are quantised to 0.5 s.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private var images: [String: UIImage] = [:]
    private var generators: [String: AVAssetImageGenerator] = [:]

    static func quantise(_ seconds: Double) -> Double {
        (max(0, seconds) * 2).rounded() / 2
    }

    func image(assetID: String, kind: Clip.Kind, at seconds: Double) async -> UIImage? {
        let t = kind == .photo ? 0 : Self.quantise(seconds)
        let key = "\(assetID)@\(t)"
        if let cached = images[key] { return cached }
        if images.count > 900 { images.removeAll() }

        let result: UIImage?
        switch kind {
        case .photo:
            result = Self.downscaledPhoto(MediaStore.url(for: assetID), maxSide: 240)
        case .video:
            let generator = self.generator(assetID)
            do {
                let frame = try await generator.image(at: CMTime(seconds: t, preferredTimescale: 600))
                result = UIImage(cgImage: frame.image)
            } catch {
                result = nil
            }
        case .audio, .text:
            result = nil
        }
        if let r = result { images[key] = r }
        return result
    }

    private func generator(_ assetID: String) -> AVAssetImageGenerator {
        if let g = generators[assetID] { return g }
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: MediaStore.url(for: assetID)))
        g.appliesPreferredTrackTransform = true
        g.maximumSize = CGSize(width: 200, height: 200)
        let tolerance = CMTime(value: 1, timescale: 4)
        g.requestedTimeToleranceBefore = tolerance
        g.requestedTimeToleranceAfter = tolerance
        generators[assetID] = g
        return g
    }

    private static func downscaledPhoto(_ url: URL, maxSide: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Row of frames filling a clip block, like a film strip.
struct Filmstrip: View {
    let clip: Clip
    let assetID: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let tileW = max(height * 0.8, width / 60)
        let count = max(1, Int((width / tileW).rounded(.up)))
        let pps = width / CGFloat(max(clip.duration, 0.01))
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                let t = clip.sourceIn + Double(CGFloat(i) * tileW / pps) * clip.speed
                ThumbTile(assetID: assetID, kind: clip.kind, time: ThumbnailCache.quantise(t))
                    .frame(width: tileW, height: height)
                    .clipped()
            }
        }
        .frame(width: width, height: height, alignment: .leading)
        .clipped()
    }
}

private struct ThumbTile: View {
    let assetID: String
    let kind: Clip.Kind
    let time: Double
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .task(id: "\(assetID)@\(time)") {
            let loaded = await ThumbnailCache.shared.image(assetID: assetID, kind: kind, at: time)
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }
}
