import AVFoundation
import CoreImage
import UIKit
import SCYDECore

/// CI only (`-scydeSelfTest YES`): runs the media tools on generated footage and
/// reports measurable results in the diagnostics overlay.
@MainActor
enum SelfTest {
    static func run() async -> String {
        var lines: [String] = []
        lines.append(await stabilizer())
        lines.append(await reverser())
        lines.append(await speech())
        return lines.joined(separator: "\n")
    }

    // MARK: Stabiliser: footage shaken by a known horizontal jitter.

    private static func stabilizer() async -> String {
        let width = 640, height = 360, frames = 60
        var jitter: [Double] = []
        var seed: UInt64 = 42
        for _ in 0..<frames {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            jitter.append(Double(Int(seed >> 33) % 41) - 20)
        }
        guard let id = try? await write(width: width, height: height, frames: frames, draw: { ctx, i in
            let dx = CGFloat(jitter[i])
            ctx.setFillColor(UIColor(white: 0.1, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            // A textured scene so registration has something to lock on to.
            for gx in 0..<16 {
                for gy in 0..<9 {
                    let hue = CGFloat((gx * 7 + gy * 13) % 20) / 20
                    ctx.setFillColor(UIColor(hue: hue, saturation: 0.7, brightness: 0.9, alpha: 1).cgColor)
                    ctx.fill(CGRect(x: CGFloat(gx * 48) + dx - 40, y: CGFloat(gy * 44) + 4, width: 30 + CGFloat(gy * 2), height: 26))
                }
            }
        }) else { return "stabilise: could not write test video" }
        do {
            let stab = try await Stabilizer.analyse(assetID: id, range: 0...2, strength: 1)
            // Expected correction: the opposite of the jitter around its local mean.
            var num = 0.0, da = 0.0, db = 0.0
            let n = min(stab.dx.count, 30)
            let step = Double(frames) / Double(max(n, 1))
            var expected: [Double] = []
            var got: [Double] = []
            for k in 0..<n {
                let f = min(frames - 1, Int(Double(k) * step))
                expected.append(-jitter[f])
                got.append(Double(stab.dx[k]) * Double(width))
            }
            let me = expected.reduce(0, +) / Double(max(n, 1))
            let mg = got.reduce(0, +) / Double(max(n, 1))
            for k in 0..<n {
                num += (expected[k] - me) * (got[k] - mg)
                da += pow(expected[k] - me, 2)
                db += pow(got[k] - mg, 2)
            }
            let corr = num / max(sqrt(da * db), 1e-9)
            return String(format: "stabilise: samples %d corr %.2f zoom %.2f %@", stab.dx.count, corr, stab.zoom, corr > 0.5 ? "OK" : "CHECK")
        } catch {
            return "stabilise: \(error.localizedDescription)"
        }
    }

    // MARK: Reverse: a bar that grows left to right should shrink after reversing.

    private static func reverser() async -> String {
        let width = 320, height = 180, frames = 45
        guard let id = try? await write(width: width, height: height, frames: frames, draw: { ctx, i in
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(width) * CGFloat(i + 1) / CGFloat(frames), height: CGFloat(height)))
        }) else { return "reverse: could not write test video" }
        do {
            let r = try await VideoReverser.reverse(assetID: id, range: 0...1.5) { _ in }
            let early = await brightness(r.assetID, at: 0.1)
            let late = await brightness(r.assetID, at: 1.35)
            return String(format: "reverse: %.2fs early %.2f late %.2f %@", r.duration, early, late, early > late ? "OK" : "CHECK")
        } catch {
            return "reverse: \(error.localizedDescription)"
        }
    }

    private static func speech() async -> String {
        do {
            let r = try await SpeechRenderer().render("Dobar dan, ovo je SCYDE.", language: "hr-HR", rate: 1, pitch: 1)
            return String(format: "speech: %.2fs OK", r.duration)
        } catch {
            return "speech: \(error.localizedDescription)"
        }
    }

    // MARK: Helpers

    private static func brightness(_ assetID: String, at t: Double) async -> Double {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: MediaStore.url(for: assetID)))
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        guard let img = try? await g.image(at: CMTime(seconds: t, preferredTimescale: 600)).image else { return -1 }
        let ci = CIImage(cgImage: img)
        guard let avg = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ci, kCIInputExtentKey: CIVector(cgRect: ci.extent)])?.outputImage else { return -1 }
        var px = [UInt8](repeating: 0, count: 4)
        CIContext().render(avg, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return Double(px[0]) / 255
    }

    private static func write(width: Int, height: Int, frames: Int, draw: (CGContext, Int) -> Void) async throws -> String {
        let id = MediaStore.newAssetID(ext: "mov")
        let writer = try AVAssetWriter(outputURL: MediaStore.url(for: id), fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "selftest", code: 1) }
        writer.startSession(atSourceTime: .zero)
        for i in 0..<frames {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 3_000_000) }
            var pb: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            ] as CFDictionary, &pb)
            guard let buffer = pb else { continue }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let ctx = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) {
                draw(ctx, i)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? NSError(domain: "selftest", code: 2) }
        return id
    }
}
