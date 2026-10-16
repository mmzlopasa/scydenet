import AVFoundation
import CoreImage
import Foundation
import ImageIO
import Metal
import UIKit
import Vision
import SCYDECore

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
        /// Caption or title text, positioned and animated by the clip's text style.
        case text(String)
        /// Emoji or `sf:` symbol sticker.
        case sticker(String)
    }

    let source: Source
    let isMain: Bool
    var filter: String? = nil
    var adjust: Adjustments? = nil
    var cutout: Bool = false
    /// The clip this layer comes from (transform, keyframes, transitions, chroma key).
    var clip: Clip? = nil
    /// Transition into the next clip on the main track, played at the end of this one.
    var outTransition: ClipTransition? = nil
    /// Canvas fill behind the main track.
    var background: CanvasBackground? = nil
    /// Cross dissolve window (timeline seconds) over which this incoming clip fades in.
    var dissolve: ClosedRange<Double>? = nil

    var isGraphic: Bool {
        switch source {
        case .text, .sticker: return true
        default: return false
        }
    }
}

/// Transforms being dragged on the preview, read by the compositor every frame so
/// gestures update without rebuilding the composition.
final class LiveTransforms: @unchecked Sendable {
    static let shared = LiveTransforms()
    private let lock = NSLock()
    private var values: [UUID: ClipTransform] = [:]

    func set(_ id: UUID, _ t: ClipTransform?) {
        lock.lock()
        values[id] = t
        lock.unlock()
    }

    func get(_ id: UUID) -> ClipTransform? {
        lock.lock()
        defer { lock.unlock() }
        return values[id]
    }

    func clear() {
        lock.lock()
        values.removeAll()
        lock.unlock()
    }
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
    private let context: CIContext = {
        let options: [CIContextOption: Any] = [.cacheIntermediates: false, .priorityRequestLow: false]
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: options)
        }
        return CIContext(options: options)
    }()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    private let lock = NSLock()
    private var photoCache: [String: CIImage] = [:]
    private var cubeCache: [String: Data] = [:]
    private var cancelled = false
    private lazy var segmentation: VNGeneratePersonSegmentationRequest = {
        let r = VNGeneratePersonSegmentationRequest()
        r.qualityLevel = .balanced
        r.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return r
    }()

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
        let now = request.compositionTime.seconds
        if let instruction = request.videoCompositionInstruction as? SXInstruction {
            for layer in instruction.layers {
                if layer.isGraphic {
                    if let g = graphic(layer, canvas: canvas, now: now) {
                        image = g.cropped(to: canvas).composited(over: image)
                    }
                    continue
                }
                guard var source = sourceImage(for: layer, request: request) else {
                    missing += 1
                    continue
                }
                if let clip = layer.clip {
                    source = Self.prepare(source, clip: clip)
                }
                source = Looks.apply(source, filter: layer.filter, adjust: layer.adjust)
                if let key = layer.clip?.chromaKey {
                    source = chroma(source, key)
                }
                var transform = ClipTransform.identity
                if let clip = layer.clip {
                    transform = LiveTransforms.shared.get(clip.id) ?? clip.transform(at: now)
                }
                let mask = layer.clip?.mask(at: now)

                var piece: CIImage
                if layer.cutout, let cut = personCutout(source) {
                    piece = Self.apply(transform, to: Self.place(cut, in: canvas, fill: false), canvas: canvas)
                    if let m = mask { piece = Masks.apply(piece, m, canvas: canvas, offset: transform) }
                    // A cut-out sits on black unless the canvas has a colour or gradient.
                    if layer.isMain, let bg = layer.background, bg.kind != .blur {
                        piece = piece.composited(over: Self.backdrop(source, canvas: canvas, background: bg))
                    }
                } else if layer.isMain {
                    let fill = Self.backdrop(source, canvas: canvas, background: layer.background)
                    let fit = Self.apply(transform, to: Self.place(source, in: canvas, fill: false), canvas: canvas)
                    piece = fit.composited(over: fill)
                    // A masked main clip reveals the black canvas, not its own blurred fill.
                    if let m = mask { piece = Masks.apply(piece.cropped(to: canvas), m, canvas: canvas, offset: transform) }
                } else {
                    // Picture in picture: centred at 55% width, then the clip's transform.
                    let w = canvas.width * 0.55
                    let rect = CGRect(x: (canvas.width - w) / 2, y: (canvas.height - w) / 2, width: w, height: w)
                    piece = Self.apply(transform, to: Self.place(source, in: rect, fill: false), canvas: canvas)
                    if let m = mask { piece = Masks.apply(piece, m, canvas: canvas, offset: transform) }
                }
                if let clip = layer.clip, let effect = clip.effect {
                    piece = Effects.apply(piece, Self.ramped(effect, clip, now), canvas: canvas, t: now - clip.start)
                }
                if layer.isMain, let clip = layer.clip {
                    piece = Self.transition(piece, clip: clip, out: layer.outTransition, now: now, canvas: canvas)
                }
                if let w = layer.dissolve, now < w.upperBound {
                    let alpha = (now - w.lowerBound) / max(w.upperBound - w.lowerBound, 0.001)
                    piece = Self.opacity(piece.cropped(to: canvas), min(max(alpha, 0), 1))
                }
                piece = piece.cropped(to: canvas)
                if !layer.isMain, let mode = layer.clip?.blend, mode != .normal {
                    image = Blends.apply(piece, over: image, mode)
                } else {
                    image = piece.composited(over: image)
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
            var image = CIImage(cvPixelBuffer: buffer)
            if let clip = layer.clip, let stab = clip.stabilization {
                image = Self.stabilize(image, stab, sourceTime: clip.sourceIn + (request.compositionTime.seconds - clip.start) * clip.speed)
            }
            if let o = CGImagePropertyOrientation(rawValue: orientation), o != .up {
                return image.oriented(o)
            }
            return image
        case let .photo(assetID):
            return photo(assetID)
        case .text, .sticker:
            return nil
        }
    }

    /// Effect with its intensity ramp evaluated at `now`.
    static func ramped(_ effect: VideoEffect, _ clip: Clip, _ now: Double) -> VideoEffect {
        guard effect.endIntensity != nil, clip.duration > 0 else { return effect }
        var e = effect
        e.intensity = effect.intensity(at: (now - clip.start) / clip.duration)
        return e
    }

    /// Shifts the frame against measured camera shake and zooms in to hide the edges.
    static func stabilize(_ image: CIImage, _ stab: Stabilization, sourceTime: Double) -> CIImage {
        let e = image.extent
        guard e.width.isFinite, e.width > 0 else { return image }
        let (dx, dy) = stab.offset(at: sourceTime)
        let z = CGFloat(max(1, stab.zoom))
        let m = CGAffineTransform(translationX: -e.midX, y: -e.midY)
            .concatenating(CGAffineTransform(scaleX: z, y: z))
            .concatenating(CGAffineTransform(translationX: e.midX + CGFloat(dx) * e.width * z, y: e.midY + CGFloat(dy) * e.height * z))
        return image.transformed(by: m).cropped(to: e)
    }

    /// Crop, quarter turns and flips on the source frame.
    static func prepare(_ image: CIImage, clip: Clip) -> CIImage {
        var out = image
        if let turns = clip.quarterTurns, turns % 4 != 0 {
            let o: CGImagePropertyOrientation
            switch ((turns % 4) + 4) % 4 {
            case 1: o = .right
            case 2: o = .down
            default: o = .left
            }
            out = out.oriented(o)
        }
        if clip.flipH == true { out = out.oriented(.upMirrored) }
        if clip.flipV == true { out = out.oriented(.downMirrored) }
        if let c = clip.crop, !c.isFull {
            let e = out.extent
            let rect = CGRect(
                x: e.minX + CGFloat(c.x) * e.width,
                y: e.minY + CGFloat(1 - c.y - c.height) * e.height,
                width: CGFloat(c.width) * e.width,
                height: CGFloat(c.height) * e.height
            )
            if rect.width > 2, rect.height > 2 {
                out = out.cropped(to: rect)
            }
        }
        return out
    }

    /// What fills the canvas behind the main clip.
    static func backdrop(_ source: CIImage, canvas: CGRect, background: CanvasBackground?) -> CIImage {
        let bg = background ?? .standard
        switch bg.kind {
        case .color:
            return CIImage(color: CIColor(color: UIColor(hex: bg.color))).cropped(to: canvas)
        case .gradient:
            return CIImage.empty().sx("CILinearGradient", [
                "inputPoint0": CIVector(x: canvas.midX, y: canvas.maxY),
                "inputPoint1": CIVector(x: canvas.midX, y: canvas.minY),
                "inputColor0": CIColor(color: UIColor(hex: bg.color)),
                "inputColor1": CIColor(color: UIColor(hex: bg.color2)),
            ]).cropped(to: canvas)
        case .blur:
            let size = max(canvas.width, canvas.height)
            return place(source, in: canvas, fill: true)
                .clampedToExtent()
                .applyingGaussianBlur(sigma: Double(size) * (0.005 + 0.05 * max(0, min(1, bg.blur))))
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputBrightnessKey: -0.08,
                    kCIInputSaturationKey: 1.1,
                ])
                .cropped(to: canvas)
        }
    }

    /// Text or sticker, styled, positioned, transformed and animated.
    private func graphic(_ layer: SXLayer, canvas: CGRect, now: Double) -> CIImage? {
        let isSticker: Bool
        let content: String
        switch layer.source {
        case let .text(t): content = t; isSticker = false
        case let .sticker(t): content = t; isSticker = true
        default: return nil
        }
        let clip = layer.clip
        let style = clip?.textStyle ?? (isSticker ? .sticker : .caption)
        let local = now - (clip?.start ?? now)
        let anim = TextAnimState.at(style, local: local, duration: clip?.duration ?? 1)
        guard anim.opacity > 0.003 else { return nil }
        var art: CIImage?
        if isSticker {
            art = TextRenderer.shared.sticker(content, style: style, canvas: canvas)
        } else {
            var visible: Int?
            if anim.chars < 0.999 {
                let count = (content as NSString).length
                visible = Int((Double(count) * anim.chars).rounded(.down))
                if visible == 0 { return nil }
            }
            art = TextRenderer.shared.text(content, style: style, canvas: canvas, visible: visible)
        }
        guard var img = art else { return nil }
        let e = img.extent
        img = img.transformed(by: CGAffineTransform(translationX: -e.midX, y: -e.midY))
        if anim.blur > 0.3 {
            img = img.clampedToExtent().applyingGaussianBlur(sigma: anim.blur)
                .cropped(to: CGRect(x: -e.width / 2, y: -e.height / 2, width: e.width, height: e.height).insetBy(dx: -CGFloat(anim.blur) * 3, dy: -CGFloat(anim.blur) * 3))
        }
        var t = ClipTransform.identity
        if let c = clip { t = LiveTransforms.shared.get(c.id) ?? c.transform(at: now) }
        let s = CGFloat(t.scale * anim.scale)
        let angle = CGFloat(-(t.rotation + anim.rotation) * .pi / 180)
        let cx = canvas.midX + CGFloat(t.x + anim.dx) * canvas.width
        let cy = canvas.midY - CGFloat(style.anchorY + t.y + anim.dy) * canvas.height
        img = img.transformed(by: CGAffineTransform(scaleX: s, y: s)
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(CGAffineTransform(translationX: cx, y: cy)))
        let o = t.opacity * anim.opacity
        if o < 0.999 { img = Self.opacity(img, o) }
        if let effect = clip?.effect, let c = clip {
            img = Effects.apply(img, Self.ramped(effect, c, now), canvas: canvas, t: now - c.start)
        }
        return img
    }

    /// Person cut-out with a transparent background, or nil if Vision finds nothing.
    private func personCutout(_ image: CIImage) -> CIImage? {
        let extent = image.extent
        guard extent.width.isFinite, extent.width > 0 else { return nil }
        let handler = VNImageRequestHandler(ciImage: image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)), options: [:])
        do {
            try handler.perform([segmentation])
        } catch {
            CompositorStats.shared.error("segmentation: \(error.localizedDescription)")
            return nil
        }
        guard let buffer = segmentation.results?.first?.pixelBuffer else { return nil }
        var mask = CIImage(cvPixelBuffer: buffer)
        let sx = extent.width / mask.extent.width
        let sy = extent.height / mask.extent.height
        mask = mask.transformed(by: CGAffineTransform(scaleX: sx, y: sy).concatenating(CGAffineTransform(translationX: extent.minX, y: extent.minY)))
        return image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: mask,
        ])
    }

    private func photo(_ assetID: String) -> CIImage? {
        lock.lock()
        if let cached = photoCache[assetID] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let url = MediaStore.url(for: assetID)
        // Decode at most 2560 px on the long side: big camera photos would otherwise
        // cost hundreds of megabytes per frame.
        var decoded: CIImage?
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
               kCGImageSourceCreateThumbnailFromImageAlways: true,
               kCGImageSourceCreateThumbnailWithTransform: true,
               kCGImageSourceThumbnailMaxPixelSize: 2560,
               kCGImageSourceShouldCacheImmediately: true,
           ] as CFDictionary) {
            decoded = CIImage(cgImage: cg)
        }
        guard let image = decoded ?? CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { return nil }
        lock.lock()
        if photoCache.count > 24 { photoCache.removeAll() }
        photoCache[assetID] = image
        lock.unlock()
        return image
    }

    // MARK: Transform, transitions, chroma key

    /// Scale and rotate about the canvas centre, then offset, then opacity.
    static func apply(_ t: ClipTransform, to image: CIImage, canvas: CGRect) -> CIImage {
        guard !t.isIdentity else { return image }
        let cx = canvas.midX
        let cy = canvas.midY
        let radians = CGFloat(-t.rotation * .pi / 180)
        let m = CGAffineTransform(translationX: -cx, y: -cy)
            .concatenating(CGAffineTransform(scaleX: CGFloat(t.scale), y: CGFloat(t.scale)))
            .concatenating(CGAffineTransform(rotationAngle: radians))
            .concatenating(CGAffineTransform(translationX: cx + CGFloat(t.x) * canvas.width, y: cy - CGFloat(t.y) * canvas.height))
        var out = image.transformed(by: m)
        if t.opacity < 0.999 {
            out = opacity(out, t.opacity)
        }
        return out
    }

    static func opacity(_ image: CIImage, _ value: Double) -> CIImage {
        let o = CGFloat(max(0, min(1, value)))
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: o, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: o, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: o, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: o),
        ])
    }

    static func transition(_ image: CIImage, clip: Clip, out: ClipTransition?, now: Double, canvas: CGRect) -> CIImage {
        var amount = 0.0
        var kind: TransitionKind?
        var entering = true
        if let t = clip.transitionIn, t.duration > 0.01 {
            let half = t.duration / 2
            let p = (now - clip.start) / half
            if p < 1 { amount = 1 - max(0, p); kind = t.kind }
        }
        if kind == nil, let t = out, t.duration > 0.01 {
            let half = t.duration / 2
            let p = (clip.end - now) / half
            if p < 1 { amount = 1 - max(0, p); kind = t.kind; entering = false }
        }
        guard let k = kind, amount > 0.001, k != .dissolve else { return image }
        let a = CGFloat(amount)
        let cx = canvas.midX
        let cy = canvas.midY
        let black = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: canvas)
        switch k {
        case .fade:
            return opacity(image, 1 - amount).composited(over: black)
        case .flash:
            let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: a)).cropped(to: canvas)
            return white.composited(over: image)
        case .zoom:
            let s = 1 + 0.35 * a
            return image.transformed(by: CGAffineTransform(translationX: -cx, y: -cy)
                .concatenating(CGAffineTransform(scaleX: s, y: s))
                .concatenating(CGAffineTransform(translationX: cx, y: cy)))
        case .blur:
            return image.clampedToExtent().applyingGaussianBlur(sigma: Double(a) * 40).cropped(to: canvas)
        case .slide:
            let dx = (entering ? 1 : -1) * a * canvas.width
            return image.transformed(by: CGAffineTransform(translationX: dx, y: 0)).composited(over: black)
        case .spin:
            let angle = (entering ? -1 : 1) * a * .pi / 2
            let s = 1 + 0.3 * a
            return image.transformed(by: CGAffineTransform(translationX: -cx, y: -cy)
                .concatenating(CGAffineTransform(scaleX: s, y: s))
                .concatenating(CGAffineTransform(rotationAngle: angle))
                .concatenating(CGAffineTransform(translationX: cx, y: cy)))
                .composited(over: black)
        case .dissolve:
            return image
        case .wipe:
            // Entering: revealed from the left; leaving: covered from the left.
            let visibleW = canvas.width * (1 - a)
            let rect = entering
                ? CGRect(x: canvas.maxX - visibleW, y: canvas.minY, width: visibleW, height: canvas.height)
                : CGRect(x: canvas.minX, y: canvas.minY, width: visibleW, height: canvas.height)
            return image.cropped(to: rect).composited(over: black)
        case .iris:
            let r = max(canvas.width, canvas.height) * 0.75 * (1 - a)
            let mask = CIImage.empty().sx("CIRadialGradient", [
                kCIInputCenterKey: CIVector(x: cx, y: cy),
                "inputRadius0": max(0, r - 2),
                "inputRadius1": r + 1,
                "inputColor0": CIColor(red: 1, green: 1, blue: 1),
                "inputColor1": CIColor(red: 0, green: 0, blue: 0),
            ]).cropped(to: canvas)
            return image.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: black,
                kCIInputMaskImageKey: mask,
            ])
        case .glitch:
            let dx = canvas.width * 0.06 * a
            let split = Effects.rgbSplit(image, dx: dx)
            let shift = canvas.width * 0.08 * a * CGFloat(sin(now * 90))
            return split.transformed(by: CGAffineTransform(translationX: shift, y: 0)).cropped(to: canvas).composited(over: black)
        case .whip:
            let dx = (entering ? 1 : -1) * a * canvas.width * 0.6
            let blurred = image.clampedToExtent()
                .applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: 60 * a, kCIInputAngleKey: 0])
                .cropped(to: canvas)
            return blurred.transformed(by: CGAffineTransform(translationX: dx, y: 0)).composited(over: black)
        case .pixel:
            let scale = max(1, canvas.width * 0.12 * a)
            return image.clampedToExtent()
                .applyingFilter("CIPixellate", parameters: [kCIInputCenterKey: CIVector(x: cx, y: cy), kCIInputScaleKey: scale])
                .cropped(to: canvas)
        case .shake:
            let amp = canvas.width * 0.05 * a
            let dx = amp * CGFloat(sin(now * 70))
            let dy = amp * CGFloat(cos(now * 53))
            return Effects.zoom(image, 1 + 0.1 * a, canvas)
                .transformed(by: CGAffineTransform(translationX: dx, y: dy))
                .cropped(to: canvas)
        }
    }

    private func chroma(_ image: CIImage, _ key: ChromaKey) -> CIImage {
        let id = "\(Int(key.hue))-\(Int(key.tolerance * 100))"
        lock.lock()
        var data = cubeCache[id]
        lock.unlock()
        if data == nil {
            let made = Self.chromaCube(hue: key.hue, tolerance: key.tolerance)
            lock.lock()
            cubeCache[id] = made
            lock.unlock()
            data = made
        }
        guard let cube = data else { return image }
        return image.applyingFilter("CIColorCube", parameters: [
            "inputCubeDimension": 32,
            "inputCubeData": cube,
        ])
    }

    /// Colour cube that makes pixels near `hue` transparent (premultiplied RGBA floats).
    static func chromaCube(hue: Double, tolerance: Double) -> Data {
        let n = 32
        var values = [Float](repeating: 0, count: n * n * n * 4)
        var i = 0
        for b in 0..<n {
            for g in 0..<n {
                for r in 0..<n {
                    let rf = Double(r) / Double(n - 1)
                    let gf = Double(g) / Double(n - 1)
                    let bf = Double(b) / Double(n - 1)
                    let maxV = max(rf, gf, bf)
                    let minV = min(rf, gf, bf)
                    let delta = maxV - minV
                    var h = 0.0
                    if delta > 0 {
                        if maxV == rf { h = 60 * ((gf - bf) / delta).truncatingRemainder(dividingBy: 6) }
                        else if maxV == gf { h = 60 * ((bf - rf) / delta + 2) }
                        else { h = 60 * ((rf - gf) / delta + 4) }
                    }
                    if h < 0 { h += 360 }
                    let sat = maxV == 0 ? 0 : delta / maxV
                    var diff = abs(h - hue)
                    if diff > 180 { diff = 360 - diff }
                    let keyed = diff < tolerance * 180 && sat > 0.3 && maxV > 0.15
                    let alpha: Float = keyed ? 0 : 1
                    values[i] = Float(rf) * alpha
                    values[i + 1] = Float(gf) * alpha
                    values[i + 2] = Float(bf) * alpha
                    values[i + 3] = alpha
                    i += 4
                }
            }
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
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
