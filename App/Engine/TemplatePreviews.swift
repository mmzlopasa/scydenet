import AVFoundation
import CoreImage
import SwiftUI
import UIKit
import SCYDECore

/// Renders short looping preview videos for templates on device, using the same
/// looks and transitions as the editor, and caches them in Caches/TemplatePreviews.
actor TemplatePreviews {
    static let shared = TemplatePreviews()

    private var inFlight: [String: Task<URL?, Never>] = [:]

    private static var directory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TemplatePreviews", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func cachedURL(for t: ProjectTemplate) -> URL? {
        let url = directory.appendingPathComponent("\(t.id)-v2.mp4")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func video(for t: ProjectTemplate) async -> URL? {
        if let cached = Self.cachedURL(for: t) { return cached }
        if let task = inFlight[t.id] { return await task.value }
        let url = Self.directory.appendingPathComponent("\(t.id)-v2.mp4")
        let task = Task.detached(priority: .utility) { () -> URL? in
            do {
                try await Self.render(t, to: url)
                return url
            } catch {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
        }
        inFlight[t.id] = task
        let result = await task.value
        inFlight[t.id] = nil
        return result
    }

    // MARK: Artwork

    static func size(for aspect: CanvasAspect) -> CGSize {
        let r = CGFloat(aspect.ratio)
        if r < 1 { return CGSize(width: 360, height: (360 / r / 2).rounded() * 2) }
        return CGSize(width: (360 * r / 2).rounded() * 2, height: 360)
    }

    private static func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(hex: hex, alpha: alpha)
    }

    /// One scene per slot: palette gradient, decorative shapes and the category symbol.
    static func scene(_ t: ProjectTemplate, index: Int, size: CGSize) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            let a = t.colors[0]
            let b = t.colors.count > 1 ? t.colors[1] : a
            let flip = index % 2 == 1
            let colors = [color(flip ? b : a).cgColor, color(flip ? a : b).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                let angle = CGFloat(index) * 0.9
                let start = CGPoint(x: size.width * (0.5 - 0.5 * cos(angle)), y: size.height * (0.5 - 0.5 * sin(angle)))
                let end = CGPoint(x: size.width - start.x, y: size.height - start.y)
                c.drawLinearGradient(g, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            // Soft circles for depth.
            for k in 0..<4 {
                let d = min(size.width, size.height) * CGFloat(0.35 + 0.18 * Double((index + k) % 3))
                let x = size.width * CGFloat((Double(k) * 0.37 + Double(index) * 0.21).truncatingRemainder(dividingBy: 1))
                let y = size.height * CGFloat((Double(k) * 0.53 + Double(index) * 0.17).truncatingRemainder(dividingBy: 1))
                c.setFillColor(UIColor(white: 1, alpha: 0.08 + 0.04 * CGFloat(k % 2)).cgColor)
                c.fillEllipse(in: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d))
            }
            // Category symbol.
            let side = min(size.width, size.height) * 0.36
            let config = UIImage.SymbolConfiguration(pointSize: side, weight: .semibold)
            if let symbol = UIImage(systemName: t.category.icon, withConfiguration: config)?
                .withTintColor(UIColor(white: 1, alpha: 0.92), renderingMode: .alwaysOriginal) {
                let s = symbol.size
                let offset = CGFloat(index % 3 - 1) * size.width * 0.12
                symbol.draw(in: CGRect(x: (size.width - s.width) / 2 + offset, y: (size.height - s.height) / 2 - size.height * 0.04, width: s.width, height: s.height))
            }
        }
        return image.cgImage
    }

    static func titleImage(_ text: String, width: CGFloat) -> CIImage? {
        let fontSize = width * 0.085
        let font = UIFont(name: "Sora-Bold", size: fontSize) ?? UIFont.boldSystemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .kern: fontSize * 0.08,
        ]
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width * 0.9, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attrs,
            context: nil
        ).integral
        let pad = fontSize * 0.5
        let size = CGSize(width: bounds.width + pad * 2, height: bounds.height + pad * 1.2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(white: 0, alpha: 0.35).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: fontSize * 0.3).fill()
            (text as NSString).draw(
                with: CGRect(x: pad, y: pad * 0.6, width: bounds.width, height: bounds.height),
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
        }
        return img.cgImage.map { CIImage(cgImage: $0) }
    }

    /// Still frame for cards while the video renders.
    static func poster(_ t: ProjectTemplate) -> UIImage? {
        let size = size(for: t.aspect)
        guard let cg = scene(t, index: 0, size: size) else { return nil }
        let canvas = CGRect(origin: .zero, size: size)
        var img = Looks.apply(CIImage(cgImage: cg), filter: t.filter, adjust: nil)
        if let title = t.title, let titleImage = titleImage(title, width: size.width) {
            let e = titleImage.extent
            img = titleImage.transformed(by: CGAffineTransform(translationX: (size.width - e.width) / 2, y: size.height * 0.16)).composited(over: img)
        }
        guard let out = CIContext().createCGImage(img.cropped(to: canvas), from: canvas) else { return nil }
        return UIImage(cgImage: out)
    }

    // MARK: Video

    static func render(_ t: ProjectTemplate, to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        let size = size(for: t.aspect)
        let canvas = CGRect(origin: .zero, size: size)
        let factor = min(1, 6.5 / max(t.totalDuration, 0.1))
        let slots = t.slots.map { max(0.4, $0 * factor) }
        var starts: [Double] = []
        var acc = 0.0
        for s in slots {
            starts.append(acc)
            acc += s
        }
        let total = acc
        let scenes = slots.indices.compactMap { scene(t, index: $0, size: size) }
        guard scenes.count == slots.count else { throw NSError(domain: "dev.scyde.preview", code: 1) }
        let title = t.title.flatMap { titleImage($0, width: size.width) }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 900_000],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        guard writer.canAdd(input) else { throw NSError(domain: "dev.scyde.preview", code: 2) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "dev.scyde.preview", code: 3) }
        writer.startSession(atSourceTime: .zero)

        let context = CIContext(options: [.cacheIntermediates: false])
        let black = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: canvas)
        let fps = 24
        let frames = Int(total * Double(fps))
        for f in 0..<frames {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 3_000_000)
            }
            let now = Double(f) / Double(fps)
            var i = 0
            while i + 1 < starts.count && now >= starts[i + 1] { i += 1 }
            let local = now - starts[i]
            let d = slots[i]

            var img = CIImage(cgImage: scenes[i])
            let cx = size.width / 2
            let cy = size.height / 2
            if t.kenBurns {
                let s = 1 + 0.14 * CGFloat(local / d)
                img = img.transformed(by: CGAffineTransform(translationX: -cx, y: -cy)
                    .concatenating(CGAffineTransform(scaleX: s, y: s))
                    .concatenating(CGAffineTransform(translationX: cx, y: cy)))
            } else {
                let dx = -size.width * 0.06 * CGFloat(local / d)
                img = img.clampedToExtent().transformed(by: CGAffineTransform(translationX: dx, y: 0)).cropped(to: canvas)
            }
            img = Looks.apply(img, filter: t.filter, adjust: nil)

            if let kind = t.transition {
                var clip = Clip(kind: .video, name: "", start: starts[i], duration: d)
                if i > 0 { clip.transitionIn = ClipTransition(kind: kind, duration: min(0.6, d)) }
                let out: ClipTransition? = i + 1 < slots.count ? ClipTransition(kind: kind, duration: min(0.6, slots[i + 1])) : nil
                img = SXCompositor.transition(img, clip: clip, out: out, now: now, canvas: canvas)
            }

            if let title = title, now < 2.2 {
                let e = title.extent
                let alpha = now < 0.3 ? now / 0.3 : (now > 1.9 ? max(0, (2.2 - now) / 0.3) : 1)
                let rise = CGFloat(1 - min(1, now / 0.4)) * 12
                let placed = title.transformed(by: CGAffineTransform(translationX: (size.width - e.width) / 2, y: size.height * 0.16 - rise))
                img = SXCompositor.opacity(placed, alpha).composited(over: img)
            }
            img = img.cropped(to: canvas).composited(over: black)

            guard let pool = adaptor.pixelBufferPool else { throw NSError(domain: "dev.scyde.preview", code: 4) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
            guard let buffer = pb else { continue }
            context.render(img, to: buffer, bounds: canvas, colorSpace: CGColorSpaceCreateDeviceRGB())
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: CMTimeScale(fps)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? NSError(domain: "dev.scyde.preview", code: 5) }
    }
}

// MARK: - Looping muted video

struct LoopingVideo: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingVideoView {
        let view = LoopingVideoView()
        view.configure(url)
        return view
    }

    func updateUIView(_ uiView: LoopingVideoView, context: Context) {
        uiView.configure(url)
    }

    static func dismantleUIView(_ uiView: LoopingVideoView, coordinator: ()) {
        uiView.stop()
    }
}

final class LoopingVideoView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var current: URL?

    func configure(_ url: URL) {
        guard url != current else { return }
        current = url
        let item = AVPlayerItem(url: url)
        let p = AVQueuePlayer()
        p.isMuted = true
        p.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: p, templateItem: item)
        player = p
        playerLayer.player = p
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .clear
        p.play()
    }

    func stop() {
        player?.pause()
        looper = nil
        player = nil
        playerLayer.player = nil
        current = nil
    }
}

/// Poster that turns into a looping video once the preview is rendered.
struct TemplatePreviewView: View {
    let template: ProjectTemplate
    @State private var url: URL?
    @State private var poster: UIImage?

    var body: some View {
        ZStack {
            Color(UIColor(hex: template.colors[0]))
            if let poster = poster {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
            }
            if let url = url {
                LoopingVideo(url: url)
                    .transition(.opacity)
            }
        }
        .clipped()
        .task(id: template.id) {
            if poster == nil { poster = TemplatePreviews.poster(template) }
            let rendered = await TemplatePreviews.shared.video(for: template)
            withAnimation(.easeOut(duration: 0.25)) { url = rendered }
        }
    }
}
