import AVFoundation
import CoreImage
import NaturalLanguage
import UIKit

/// Writes a reversed copy of part of a video (no audio).
enum VideoReverser {
    enum Failure: LocalizedError {
        case noVideo, tooLong, writeFailed

        var errorDescription: String? {
            switch self {
            case .noVideo: return "That clip has no video to reverse.".loc
            case .tooLong: return "Reverse works on clips up to 60 seconds. Split the clip first.".loc
            case .writeFailed: return "Could not write the reversed video.".loc
            }
        }
    }

    /// Reverses `range` (source seconds) of the file and returns the new asset id and its length.
    static func reverse(
        assetID: String,
        range: ClosedRange<Double>,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> (assetID: String, duration: Double) {
        try await Task.detached(priority: .userInitiated) {
            try await run(assetID: assetID, range: range, progress: progress)
        }.value
    }

    private static func run(
        assetID: String,
        range: ClosedRange<Double>,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> (assetID: String, duration: Double) {
        let length = range.upperBound - range.lowerBound
        guard length > 0.05 else { throw Failure.noVideo }
        guard length <= 60.5 else { throw Failure.tooLong }
        let asset = AVURLAsset(url: MediaStore.url(for: assetID))
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw Failure.noVideo }
        let natural = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let fps = max(Double(try await track.load(.nominalFrameRate)), 24)
        let frameDuration = 1 / fps

        let outID = MediaStore.newAssetID(ext: "mov")
        let outURL = MediaStore.url(for: outID)
        let writer = try AVAssetWriter(outputURL: outURL, fileType: .mov)
        let width = Int(natural.width.rounded())
        let height = Int(natural.height.rounded())
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: max(4_000_000, width * height * 6)],
        ])
        input.transform = transform
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        guard writer.canAdd(input) else { throw Failure.writeFailed }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? Failure.writeFailed }
        writer.startSession(atSourceTime: .zero)

        // Read short segments from the end towards the start and append each one backwards.
        let segment = 0.25
        var segEnd = range.upperBound
        var written = 0
        var lastOut = -1.0
        while segEnd > range.lowerBound + 0.001 {
            try Task.checkCancellation()
            let segStart = max(range.lowerBound, segEnd - segment)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ])
            output.alwaysCopiesSampleData = true
            reader.timeRange = CMTimeRange(
                start: CMTime(seconds: segStart, preferredTimescale: 600),
                end: CMTime(seconds: segEnd, preferredTimescale: 600)
            )
            guard reader.canAdd(output) else { throw Failure.writeFailed }
            reader.add(output)
            guard reader.startReading() else { throw reader.error ?? Failure.writeFailed }
            var frames: [(CVPixelBuffer, Double)] = []
            while let sample = output.copyNextSampleBuffer() {
                let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                guard pts >= segStart - 0.0005, pts < segEnd - 0.0005,
                      let pb = CMSampleBufferGetImageBuffer(sample) else { continue }
                frames.append((pb, pts))
            }
            reader.cancelReading()
            for (pb, pts) in frames.sorted(by: { $0.1 > $1.1 }) {
                var outT = range.upperBound - pts - frameDuration
                if outT <= lastOut { outT = lastOut + 0.001 }
                outT = max(0, outT)
                while !input.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 3_000_000)
                }
                if adaptor.append(pb, withPresentationTime: CMTime(seconds: outT, preferredTimescale: 6000)) {
                    lastOut = outT
                    written += 1
                }
            }
            segEnd = segStart
            progress(min(1, (range.upperBound - segEnd) / length))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed, written > 0 else {
            try? FileManager.default.removeItem(at: outURL)
            throw writer.error ?? Failure.writeFailed
        }
        return (outID, length)
    }
}

/// Still frames from video files.
enum FrameGrabber {
    /// Writes the frame at `seconds` (source time) as a JPEG in the media folder.
    static func still(assetID: String, at seconds: Double) async -> String? {
        let asset = AVURLAsset(url: MediaStore.url(for: assetID))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
        guard let result = try? await generator.image(at: CMTime(seconds: max(0, seconds), preferredTimescale: 600)) else { return nil }
        guard let data = UIImage(cgImage: result.image).jpegData(compressionQuality: 0.92) else { return nil }
        let id = MediaStore.newAssetID(ext: "jpg")
        do {
            try data.write(to: MediaStore.url(for: id), options: .atomic)
            return id
        } catch {
            return nil
        }
    }
}

/// Finds beats (onsets) in an audio file.
enum BeatDetector {
    /// Beat times in source seconds inside `range`.
    static func beats(url: URL, range: ClosedRange<Double>, sensitivity: Double = 0.5) async -> [Double] {
        await Task.detached(priority: .userInitiated) {
            await read(url: url, range: range, sensitivity: sensitivity)
        }.value
    }

    private static func read(url: URL, range: ClosedRange<Double>, sensitivity: Double) async -> [Double] {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let reader = try? AVAssetReader(asset: asset) else { return [] }
        let sampleRate = 11_025.0
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: sampleRate,
        ])
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: range.lowerBound, preferredTimescale: 600),
            end: CMTime(seconds: range.upperBound, preferredTimescale: 600)
        )
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        guard reader.startReading() else { return [] }

        // Energy per hop, then onset strength = positive change in log energy.
        let hop = 256
        let hopSeconds = Double(hop) / sampleRate
        var energies: [Float] = []
        var acc: Float = 0
        var n = 0
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            guard length >= 4 else { continue }
            var samples = [Float](repeating: 0, count: length / 4)
            let status = samples.withUnsafeMutableBytes { raw -> OSStatus in
                guard let base = raw.baseAddress else { return -1 }
                return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: (length / 4) * 4, destination: base)
            }
            guard status == noErr else { continue }
            for v in samples {
                acc += v * v
                n += 1
                if n == hop {
                    energies.append(log(1e-6 + acc / Float(n)))
                    acc = 0
                    n = 0
                }
            }
        }
        guard energies.count > 8 else { return [] }
        var flux = [Float](repeating: 0, count: energies.count)
        for i in 1..<energies.count {
            flux[i] = max(0, energies[i] - energies[i - 1])
        }
        // Adaptive threshold: local mean over ~0.5 s plus a margin.
        let half = max(2, Int(0.25 / hopSeconds))
        let minGap = max(1, Int(0.22 / hopSeconds))
        let margin = Float(0.35 + (1 - sensitivity) * 1.2)
        var result: [Double] = []
        var last = -minGap
        for i in 1..<(flux.count - 1) {
            let a = max(0, i - half)
            let b = min(flux.count - 1, i + half)
            var sum: Float = 0
            for j in a...b { sum += flux[j] }
            let mean = sum / Float(b - a + 1)
            if flux[i] > mean + margin * 0.5, flux[i] >= flux[i - 1], flux[i] >= flux[i + 1], i - last >= minGap {
                result.append(range.lowerBound + Double(i) * hopSeconds)
                last = i
            }
        }
        return result
    }
}

/// Languages offered for text-to-speech.
enum SpeechVoices {
    struct Voice: Identifiable, Hashable {
        let id: String
        let name: String
    }

    static let all: [Voice] = [
        Voice(id: "auto", name: "Auto"),
        Voice(id: "hr-HR", name: "Hrvatski"),
        Voice(id: "en-US", name: "English (US)"),
        Voice(id: "en-GB", name: "English (UK)"),
        Voice(id: "de-DE", name: "Deutsch"),
        Voice(id: "it-IT", name: "Italiano"),
        Voice(id: "es-ES", name: "Español"),
        Voice(id: "fr-FR", name: "Français"),
        Voice(id: "sr-RS", name: "Srpski"),
        Voice(id: "sl-SI", name: "Slovenščina"),
    ]

}

/// Text-to-speech rendered to an audio file.
@MainActor
final class SpeechRenderer: NSObject {
    enum Failure: LocalizedError {
        case empty, failed
        var errorDescription: String? {
            switch self {
            case .empty: return "Type some text to read aloud.".loc
            case .failed: return "This iPhone could not synthesise that voice.".loc
            }
        }
    }

    private var synthesizer: AVSpeechSynthesizer?

    static func detectLanguage(_ text: String) -> String {
        let r = NLLanguageRecognizer()
        r.processString(text)
        switch r.dominantLanguage?.rawValue ?? "en" {
        case "hr", "bs": return "hr-HR"
        case "sr": return "sr-RS"
        case "sl": return "sl-SI"
        case "de": return "de-DE"
        case "it": return "it-IT"
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        default: return "en-US"
        }
    }

    /// Renders speech to a CAF file in the media folder. Returns the asset id and duration.
    func render(_ text: String, language: String, rate: Double, pitch: Double) async throws -> (assetID: String, duration: Double) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.empty }
        let lang = language == "auto" ? Self.detectLanguage(trimmed) : language
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: lang) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = Float(AVSpeechUtteranceDefaultSpeechRate) * Float(rate)
        utterance.pitchMultiplier = Float(pitch)

        let id = MediaStore.newAssetID(ext: "caf")
        let url = MediaStore.url(for: id)
        let synth = AVSpeechSynthesizer()
        synthesizer = synth
        let box = SpeechFileBox(url: url)
        let once = ResumeOnce()
        let estimate = Double(trimmed.count) * 0.12 / max(rate, 0.3) + 12
        let ok: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            once.set(cont)
            synth.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    once.resume(box.close())
                    return
                }
                box.append(pcm)
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(estimate * 1_000_000_000))
                once.resume(box.close())
            }
        }
        synthesizer = nil
        guard ok else {
            try? FileManager.default.removeItem(at: url)
            throw Failure.failed
        }
        let asset = AVURLAsset(url: url)
        let seconds = (try? await asset.load(.duration))?.seconds ?? 0
        guard seconds.isFinite, seconds > 0.1 else {
            try? FileManager.default.removeItem(at: url)
            throw Failure.failed
        }
        return (id, seconds)
    }
}

/// Resumes a continuation at most once, from any thread.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var cont: CheckedContinuation<Bool, Never>?

    func set(_ c: CheckedContinuation<Bool, Never>) {
        lock.lock(); cont = c; lock.unlock()
    }

    func resume(_ value: Bool) {
        lock.lock()
        let c = cont
        cont = nil
        lock.unlock()
        c?.resume(returning: value)
    }
}

/// Collects PCM buffers into a file.
private final class SpeechFileBox: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var frames: AVAudioFramePosition = 0
    private var closed = false

    init(url: URL) { self.url = url }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        if file == nil {
            file = try? AVAudioFile(forWriting: url, settings: buffer.format.settings, commonFormat: buffer.format.commonFormat, interleaved: buffer.format.isInterleaved)
        }
        do {
            try file?.write(from: buffer)
            frames += AVAudioFramePosition(buffer.frameLength)
        } catch {}
    }

    func close() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let ok = !closed && file != nil && frames > 0
        closed = true
        file = nil
        return ok
    }
}
