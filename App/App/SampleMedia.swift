import AVFoundation
import CoreGraphics
import UIKit
import SCYDECore

/// CI only (`-scydeSampleMedia YES`): writes real video and photo files so the
/// composition, compositor and player are exercised in the simulator.
enum SampleMedia {
    @MainActor
    static func makeProject() async -> Project {
        var project = Project(name: "Sample media", aspect: .portrait9x16)
        if let a = try? await writeVideo(width: 720, height: 1280, seconds: 3, from: 0x5A49E6, to: 0xFFD76A) {
            project.addClip(Clip(kind: .video, name: "Portrait", assetID: a, sourceDuration: 3, duration: 3), role: .main)
        }
        if let photo = writePhoto() {
            project.addClip(Clip(kind: .photo, name: "Photo", assetID: photo, duration: 2), role: .main)
        }
        if let b = try? await writeVideo(width: 1280, height: 720, seconds: 3, from: 0x0C8A60, to: 0xC4BBFF) {
            project.addClip(Clip(kind: .video, name: "Landscape", assetID: b, sourceDuration: 3, duration: 3), role: .main)
        }
        // Exercise motion, transitions and text in CI screenshots.
        let mains = project.tracks.first(where: { $0.role == .main })?.clips ?? []
        if let first = mains.first {
            project.setKeyframe(first.id, at: 0, transform: ClipTransform(scale: 1))
            project.setKeyframe(first.id, at: 3, transform: ClipTransform(y: -0.05, scale: 1.25, rotation: 4))
        }
        if mains.count > 1 {
            project.updateClip(mains[1].id) { $0.transitionIn = Transition(kind: .zoom, duration: 0.8) }
        }
        if mains.count > 2 {
            project.updateClip(mains[2].id) { $0.transitionIn = Transition(kind: .slide, duration: 0.8) }
        }
        project.addClip(Clip(kind: .text, name: "Caption", duration: 2.4, text: "Made with SCYDE"), role: .text, at: 0.4)
        return project
    }

    private static func cg(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    static func writeVideo(width: Int, height: Int, seconds: Double, from: UInt32, to: UInt32) async throws -> String {
        let id = MediaStore.newAssetID(ext: "mov")
        let url = MediaStore.url(for: id)
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        guard writer.canAdd(input) else { throw NSError(domain: "dev.scyde.sample", code: 1) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "dev.scyde.sample", code: 2) }
        writer.startSession(atSourceTime: .zero)

        let fps = 30
        let frames = Int(seconds * Double(fps))
        for f in 0..<frames {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            let progress = Double(f) / Double(max(frames - 1, 1))
            guard let buffer = frame(width: width, height: height, progress: progress, from: from, to: to) else { continue }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: CMTimeScale(fps)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? NSError(domain: "dev.scyde.sample", code: 3) }
        return id
    }

    private static func frame(width: Int, height: Int, progress: Double, from: UInt32, to: UInt32) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pb)
        guard let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        let w = CGFloat(width)
        let h = CGFloat(height)
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [cg(from), cg(to)] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: w, y: h), options: [])
        }
        // A disc that travels left to right so motion is visible.
        let r = min(w, h) * 0.16
        let x = w * (0.2 + 0.6 * CGFloat(progress))
        ctx.setFillColor(cg(0xFFFFFF, 0.92))
        ctx.fillEllipse(in: CGRect(x: x - r, y: h / 2 - r, width: r * 2, height: r * 2))
        // Progress bar along the bottom edge.
        let bar = h * 0.05
        ctx.setFillColor(cg(0x0D0F14, 0.6))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: bar))
        ctx.setFillColor(cg(0xFFFFFF))
        ctx.fill(CGRect(x: 0, y: 0, width: w * CGFloat(progress), height: bar))
        return buffer
    }

    @MainActor
    private static func writePhoto() -> String? {
        let size = CGSize(width: 1200, height: 900)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let c = context.cgContext
            c.setFillColor(cg(0x14161D))
            c.fill(CGRect(origin: .zero, size: size))
            let colors: [UInt32] = [0xFFD76A, 0xC4BBFF, 0x8EF0C8, 0xFF9AA8]
            for (i, hex) in colors.enumerated() {
                c.setFillColor(cg(hex))
                let d: CGFloat = 220
                c.fillEllipse(in: CGRect(x: 120 + CGFloat(i) * 250, y: (size.height - d) / 2, width: d, height: d))
            }
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let id = MediaStore.newAssetID(ext: "jpg")
        do {
            try data.write(to: MediaStore.url(for: id), options: .atomic)
            return id
        } catch {
            return nil
        }
    }
}
