import AVFoundation
import CoreVideo

/// A tiny one-second black clip, written once to Caches. Photos and empty spans
/// use it so the composition has real media for their whole duration.
enum BlankVideo {
    static func url() async -> URL? {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("scyde-blank-v1.mov")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        do {
            try await write(to: url)
            return url
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    private static func write(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        guard writer.canAdd(input) else { throw NSError(domain: "dev.scyde.blank", code: 1) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "dev.scyde.blank", code: 2) }
        writer.startSession(atSourceTime: .zero)

        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA, nil, &pb)
        guard let buffer = pb else { throw NSError(domain: "dev.scyde.blank", code: 3) }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 0, CVPixelBufferGetBytesPerRow(buffer) * 64)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        for f in 0..<30 {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? NSError(domain: "dev.scyde.blank", code: 4) }
    }
}
