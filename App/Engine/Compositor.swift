import AVFoundation
import CoreImage
import Foundation
import ImageIO

// The single compositor used by preview and (from Phase 5) export, so what you
// see is what you get.

#if compiler(>=6.0)
typealias SXPixelAttributes = [String: any Sendable]
#else
typealias SXPixelAttributes = [String: Any]
#endif

/// One visual layer active during an instruction's time range.
struct SXLayer: Sendable {
    enum Source: Sendable {
        /// A frame from a composition video track. `orientation` is a CGImagePropertyOrientation raw value.
        case video(trackID: CMPersistentTrackID, orientation: UInt32)
        /// A still image from the media folder.
        case photo(assetID: String)
    }

    let source: Source
    let isMain: Bool
}

/// Instruction covering a span where the set of visible clips does not change.
final class SXInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing: Bool = false
    let containsTweening: Bool = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    let layers: [SXLayer]

    init(timeRange: CMTimeRange, layers: [SXLayer]) {
        self.timeRange = timeRange
        self.layers = layers
        var ids: [CMPersistentTrackID] = []
        for layer in layers {
            if case let .video(trackID, _) = layer.source, !ids.contains(trackID) {
                ids.append(trackID)
            }
        }
        self.requiredSourceTrackIDs = ids.isEmpty ? nil : ids.map { NSNumber(value: $0) }
        super.init()
    }
}

/// Counters shown in the CI diagnostics overlay.
final class CompositorStats: @unchecked Sendable {
    static let shared = CompositorStats()
    private let lock = NSLock()
    private var frames = 0
    private var missing = 0
    private var lastError = ""

    func frame(missingSources: Int) {
        lock.lock(); frames += 1; missing += missingSources; lock.unlock()
    }

    func error(_ text: String) {
        lock.lock(); lastError = text; lock.unlock()
    }

    var summary: String {
        lock.lock(); defer { lock.unlock() }
        return "frames \(frames) · missing \(missing)" + (lastError.isEmpty ? "" : " · \(lastError)")
    }
}

final class SXCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.scyde.compositor", qos: .userInteractive)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    private let lock = NSLock()
    private var photoCache: [String: CIImage] = [:]
    private var cancelled = false

    var sourcePixelBufferAttributes: SXPixelAttributes? {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Int](),
        ]
    }

    var requiredPixelBufferAttributesForRenderContext: SXPixelAttributes {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Int](),
        ]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        lock.lock()
        cancelled = false
        lock.unlock()
        queue.async { [weak self] in
            guard let self = self else {
                request.finishCancelledRequest()
                return
            }
            autoreleasepool {
                self.render(request)
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        lock.lock()
        cancelled = true
        lock.unlock()
        queue.async { [weak self] in
            self?.lock.lock()
            self?.cancelled = false
            self?.lock.unlock()
        }
    }

    // MARK: Rendering

    private func render(_ request: AVAsynchronousVideoCompositionRequest) {
        lock.lock()
        let isCancelled = cancelled
        lock.unlock()
        if isCancelled {
            request.finishCancelledRequest()
            return
        }
        guard let output = request.renderContext.newPixelBuffer() else {
            CompositorStats.shared.error("no output buffer")
            request.finish(with: NSError(domain: "dev.scyde.compositor", code: 1))
            return
        }
        let size = request.renderContext.size
        let canvas = CGRect(origin: .zero, size: size)
        var image = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: canvas)

        var missing = 0
        if let instruction = request.videoCompositionInstruction as? SXInstruction {
            for layer in instruction.layers {
                guard let source = sourceImage(for: layer, request: request) else {
                    missing += 1
                    continue
                }
                if layer.isMain {
                    let fill = Self.place(source, in: canvas, fill: true)
                        .clampedToExtent()
                        .applyingGaussianBlur(sigma: Double(max(size.width, size.height)) * 0.025)
                        .applyingFilter("CIColorControls", parameters: [
                            kCIInputBrightnessKey: -0.08,
                            kCIInputSaturationKey: 1.1,
                        ])
                        .cropped(to: canvas)
                    image = fill.composited(over: image)
                    image = Self.place(source, in: canvas, fill: false).composited(over: image)
                } else {
                    // Picture in picture until Phase 7 adds transforms: centred at 55% width.
                    let w = canvas.width * 0.55
                    let rect = CGRect(x: (canvas.width - w) / 2, y: (canvas.height - w) / 2, width: w, height: w)
                    image = Self.place(source, in: rect, fill: false).composited(over: image)
                }
            }
        } else {
            CompositorStats.shared.error("unexpected instruction type")
        }
        CompositorStats.shared.frame(missingSources: missing)

        context.render(image, to: output, bounds: canvas, colorSpace: colorSpace)
        request.finish(withComposedVideoFrame: output)
    }

    private func sourceImage(for layer: SXLayer, request: AVAsynchronousVideoCompositionRequest) -> CIImage? {
        switch layer.source {
        case let .video(trackID, orientation):
            guard let buffer = request.sourceFrame(byTrackID: trackID) else { return nil }
            let image = CIImage(cvPixelBuffer: buffer)
            if let o = CGImagePropertyOrientation(rawValue: orientation), o != .up {
                return image.oriented(o)
            }
            return image
        case let .photo(assetID):
            return photo(assetID)
        }
    }

    private func photo(_ assetID: String) -> CIImage? {
        lock.lock()
        if let cached = photoCache[assetID] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let url = MediaStore.url(for: assetID)
        guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { return nil }
        lock.lock()
        photoCache[assetID] = image
        lock.unlock()
        return image
    }

    /// Scales `image` to fit (or fill) `rect`, centred.
    static func place(_ image: CIImage, in rect: CGRect, fill: Bool) -> CIImage {
        let e = image.extent
        guard e.width > 0, e.height > 0, e.width.isFinite, e.height.isFinite else { return image }
        let s = fill ? max(rect.width / e.width, rect.height / e.height) : min(rect.width / e.width, rect.height / e.height)
        let w = e.width * s
        let h = e.height * s
        let t = CGAffineTransform(translationX: -e.minX, y: -e.minY)
            .concatenating(CGAffineTransform(scaleX: s, y: s))
            .concatenating(CGAffineTransform(translationX: rect.minX + (rect.width - w) / 2, y: rect.minY + (rect.height - h) / 2))
        return image.transformed(by: t)
    }
}
