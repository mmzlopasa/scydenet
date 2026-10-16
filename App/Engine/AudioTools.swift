import AVFoundation
import Speech
import SCYDECore

// MARK: - Silence detection (AutoCut)

enum AudioAnalysis {
    /// Silent spans (source seconds) inside `range` that last at least `minLength`.
    static func silences(
        url: URL,
        range: ClosedRange<Double>,
        threshold: Float = 0.018,
        minLength: Double = 0.6
    ) async -> [ClosedRange<Double>] {
        await Task.detached(priority: .userInitiated) {
            await read(url: url, range: range, threshold: threshold, minLength: minLength)
        }.value
    }

    private static func read(url: URL, range: ClosedRange<Double>, threshold: Float, minLength: Double) async -> [ClosedRange<Double>] {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let reader = try? AVAssetReader(asset: asset) else { return [] }
        let sampleRate = 16_000.0
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

        let step = 0.05
        let window = Int(sampleRate * step)
        var acc: Float = 0
        var n = 0
        var index = 0
        var silentStart: Double?
        var result: [ClosedRange<Double>] = []

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
                if n == window {
                    let rms = (acc / Float(n)).squareRoot()
                    let t = range.lowerBound + Double(index) * step
                    if rms < threshold {
                        if silentStart == nil { silentStart = t }
                    } else if let s = silentStart {
                        if t - s >= minLength { result.append(s...t) }
                        silentStart = nil
                    }
                    acc = 0
                    n = 0
                    index += 1
                }
            }
        }
        if let s = silentStart {
            let end = min(range.upperBound, range.lowerBound + Double(index) * step)
            if end - s >= minLength { result.append(s...end) }
        }
        return result
    }
}

// MARK: - On-device captions

enum Captioner {
    struct Line {
        let text: String
        let start: Double
        let duration: Double
    }

    enum Failure: LocalizedError {
        case denied, unavailable, noSpeech

        var errorDescription: String? {
            switch self {
            case .denied: return "Allow speech recognition for SCYDE in Settings to create captions."
            case .unavailable: return "On-device speech recognition is not available for this language on this iPhone."
            case .noSpeech: return "No speech was found in this project."
            }
        }
    }

    private final class Once: @unchecked Sendable {
        var done = false
    }

    static func authorize() async -> Bool {
        await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                c.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribes an audio file on device and groups words into short caption lines.
    static func transcribe(url: URL) async throws -> [Line] {
        guard await authorize() else { throw Failure.denied }
        let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let r = recognizer, r.isAvailable, r.supportsOnDeviceRecognition else { throw Failure.unavailable }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        let once = Once()
        let result: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { cont in
            r.recognitionTask(with: request) { result, error in
                if once.done { return }
                if let error = error {
                    once.done = true
                    cont.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    once.done = true
                    cont.resume(returning: result)
                }
            }
        }

        var lines: [Line] = []
        var words: [String] = []
        var lineStart = 0.0
        var lineEnd = 0.0
        for segment in result.bestTranscription.segments {
            let start = segment.timestamp
            let end = segment.timestamp + segment.duration
            let gap = start - lineEnd
            if !words.isEmpty && (words.count >= 5 || end - lineStart > 2.6 || gap > 0.8) {
                lines.append(Line(text: words.joined(separator: " "), start: lineStart, duration: max(lineEnd - lineStart, 0.4)))
                words = []
            }
            if words.isEmpty { lineStart = start }
            words.append(segment.substring)
            lineEnd = end
        }
        if !words.isEmpty {
            lines.append(Line(text: words.joined(separator: " "), start: lineStart, duration: max(lineEnd - lineStart, 0.4)))
        }
        guard !lines.isEmpty else { throw Failure.noSpeech }
        return lines
    }
}

// MARK: - Voice effects (offline AVAudioEngine render)

enum VoicePreset: String, CaseIterable, Identifiable {
    case chipmunk, deep, robot, echo, hall, radio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chipmunk: return "High"
        case .deep: return "Deep"
        case .robot: return "Robot"
        case .echo: return "Echo"
        case .hall: return "Hall"
        case .radio: return "Radio"
        }
    }

    var icon: String {
        switch self {
        case .chipmunk: return "arrow.up.circle"
        case .deep: return "arrow.down.circle"
        case .robot: return "cpu"
        case .echo: return "dot.radiowaves.left.and.right"
        case .hall: return "building.columns"
        case .radio: return "radio"
        }
    }

    var tail: Double {
        switch self {
        case .echo, .hall: return 1.5
        default: return 0
        }
    }
}

enum VoiceFX {
    enum Failure: LocalizedError {
        case render
        var errorDescription: String? { "The voice effect could not be rendered." }
    }

    /// Renders `input` through the preset into a new media file and returns its asset ID.
    static func render(input: URL, preset: VoicePreset) async throws -> (assetID: String, duration: Double) {
        try await Task.detached(priority: .userInitiated) {
            try renderSync(input: input, preset: preset)
        }.value
    }

    private static func renderSync(input: URL, preset: VoicePreset) throws -> (assetID: String, duration: Double) {
        let file = try AVAudioFile(forReading: input)
        let format = file.processingFormat
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        var chain: [AVAudioNode] = []
        switch preset {
        case .chipmunk:
            let p = AVAudioUnitTimePitch()
            p.pitch = 700
            chain = [p]
        case .deep:
            let p = AVAudioUnitTimePitch()
            p.pitch = -500
            chain = [p]
        case .robot:
            let d = AVAudioUnitDistortion()
            d.loadFactoryPreset(.speechAlienChatter)
            d.wetDryMix = 60
            chain = [d]
        case .echo:
            let d = AVAudioUnitDelay()
            d.delayTime = 0.25
            d.feedback = 35
            d.wetDryMix = 35
            chain = [d]
        case .hall:
            let r = AVAudioUnitReverb()
            r.loadFactoryPreset(.largeHall)
            r.wetDryMix = 40
            chain = [r]
        case .radio:
            let d = AVAudioUnitDistortion()
            d.loadFactoryPreset(.speechRadioTower)
            d.wetDryMix = 70
            chain = [d]
        }
        chain.forEach { engine.attach($0) }
        var last: AVAudioNode = player
        for node in chain {
            engine.connect(last, to: node, format: format)
            last = node
        }
        engine.connect(last, to: engine.mainMixerNode, format: format)

        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try engine.start()
        player.scheduleFile(file, at: nil)
        player.play()

        let assetID = MediaStore.newAssetID(ext: "caf")
        let outURL = MediaStore.url(for: assetID)
        let out = try AVAudioFile(forWriting: outURL, settings: engine.manualRenderingFormat.settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            throw Failure.render
        }
        let total = file.length + AVAudioFramePosition(format.sampleRate * preset.tail)
        while engine.manualRenderingSampleTime < total {
            let remaining = total - engine.manualRenderingSampleTime
            let frames = AVAudioFrameCount(min(Int64(buffer.frameCapacity), remaining))
            let status = try engine.renderOffline(frames, to: buffer)
            switch status {
            case .success:
                try out.write(from: buffer)
            case .error:
                throw Failure.render
            default:
                break
            }
        }
        player.stop()
        engine.stop()
        return (assetID, Double(total) / format.sampleRate)
    }
}

// MARK: - Voice-over recorder

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var level: Float = 0

    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?
    private var assetID: String?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                c.resume(returning: granted)
            }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        let id = MediaStore.newAssetID(ext: "m4a")
        let r = try AVAudioRecorder(url: MediaStore.url(for: id), settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ])
        r.isMeteringEnabled = true
        guard r.record() else { throw VoiceFX.Failure.render }
        recorder = r
        assetID = id
        isRecording = true
        elapsed = 0
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self = self, let r = self.recorder else { return }
                r.updateMeters()
                self.elapsed = r.currentTime
                let db = r.averagePower(forChannel: 0)
                self.level = max(0, min(1, (db + 50) / 50))
            }
        }
    }

    /// Stops and returns the new asset ID and its length.
    func stop() -> (assetID: String, duration: Double)? {
        meterTask?.cancel()
        meterTask = nil
        let length = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        guard let id = assetID, length > 0.2 else { return nil }
        assetID = nil
        return (id, length)
    }
}
