import AVFoundation
import Foundation

/// Sound effects synthesised on the device (no recorded samples, so nothing to license).
enum SoundEffects {
    struct Effect: Identifiable, Hashable {
        let id: String
        let name: String
        let icon: String
        let length: Double
    }

    static let all: [Effect] = [
        Effect(id: "whoosh", name: "Whoosh", icon: "wind", length: 0.7),
        Effect(id: "swipe", name: "Swipe", icon: "hand.draw", length: 0.35),
        Effect(id: "riser", name: "Riser", icon: "arrow.up.right", length: 2.0),
        Effect(id: "drop", name: "Bass drop", icon: "arrow.down.to.line", length: 1.4),
        Effect(id: "impact", name: "Impact", icon: "burst", length: 1.0),
        Effect(id: "pop", name: "Pop", icon: "circle.fill", length: 0.18),
        Effect(id: "click", name: "Click", icon: "cursorarrow.click", length: 0.06),
        Effect(id: "ding", name: "Ding", icon: "bell", length: 1.2),
        Effect(id: "chime", name: "Chime", icon: "music.note", length: 1.6),
        Effect(id: "shutter", name: "Camera", icon: "camera", length: 0.25),
        Effect(id: "typing", name: "Typing", icon: "keyboard", length: 1.5),
        Effect(id: "heartbeat", name: "Heartbeat", icon: "heart", length: 1.6),
        Effect(id: "glitch", name: "Glitch", icon: "waveform.path.ecg", length: 0.6),
        Effect(id: "boing", name: "Boing", icon: "arrow.up.and.down", length: 0.6),
        Effect(id: "success", name: "Success", icon: "checkmark.seal", length: 0.9),
        Effect(id: "error", name: "Error", icon: "xmark.octagon", length: 0.5),
    ]

    private static let rate = 44_100.0

    /// Writes the effect into the media folder once and returns its asset ID.
    static func asset(_ effect: Effect) throws -> String {
        let assetID = "sfx-\(effect.id).caf"
        let url = MediaStore.url(for: assetID)
        if FileManager.default.fileExists(atPath: url.path) { return assetID }
        let samples = synth(effect)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw NSError(domain: "dev.scyde.sfx", code: 1)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let ch = buffer.floatChannelData?[0] {
            for i in 0..<samples.count { ch[i] = samples[i] }
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return assetID
    }

    // MARK: Synthesis

    private static func synth(_ e: Effect) -> [Float] {
        let n = Int(e.length * rate)
        var out = [Float](repeating: 0, count: n)
        var seed: UInt32 = 0x9E37_79B9
        func noise() -> Float {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return Float(seed >> 8) / Float(1 << 24) * 2 - 1
        }
        var phase = 0.0
        var lp: Float = 0
        func tone(_ f: Double) -> Float {
            phase += 2 * .pi * f / rate
            return Float(sin(phase))
        }
        for i in 0..<n {
            let t = Double(i) / rate
            let u = t / e.length
            var v: Float = 0
            switch e.id {
            case "whoosh", "swipe":
                // Noise through a sweeping low-pass with a hump envelope.
                let cutoff = Float(0.02 + 0.25 * sin(.pi * u))
                lp += cutoff * (noise() - lp)
                v = lp * Float(sin(.pi * u)) * 1.6
            case "riser":
                lp += Float(0.01 + 0.3 * u) * (noise() - lp)
                v = (lp * 0.6 + tone(200 + 1400 * u * u) * 0.25) * Float(u)
            case "drop":
                v = tone(140 * pow(0.25, u)) * Float(exp(-2.2 * u)) * 0.9
            case "impact":
                lp += 0.08 * (noise() - lp)
                v = (tone(55) * 0.8 + lp * 1.2) * Float(exp(-5 * u))
            case "pop":
                v = tone(900 * exp(-8 * u) + 200) * Float(exp(-18 * u))
            case "click":
                v = noise() * Float(exp(-60 * u))
            case "ding":
                v = (tone(1320) * 0.6 + Float(sin(2 * .pi * 2640 * t)) * 0.2) * Float(exp(-4 * u))
            case "chime":
                let notes = [1046.5, 1318.5, 1568.0]
                let k = min(Int(u * 3), 2)
                let local = u * 3 - Double(k)
                v = Float(sin(2 * .pi * notes[k] * t)) * Float(exp(-3 * local)) * 0.6
            case "shutter":
                v = noise() * Float(u < 0.3 ? exp(-30 * u) : exp(-30 * (u - 0.55)) * (u > 0.55 ? 1 : 0)) * 0.9
            case "typing":
                let beat = (t * 9).truncatingRemainder(dividingBy: 1)
                v = noise() * Float(exp(-70 * beat)) * 0.7
            case "heartbeat":
                let b = t.truncatingRemainder(dividingBy: 0.8)
                let env = exp(-pow((b - 0.05) / 0.03, 2)) + 0.7 * exp(-pow((b - 0.28) / 0.03, 2))
                v = tone(55) * Float(env)
            case "glitch":
                let step = Int(t * 40) % 4
                v = (step == 0 ? noise() : tone(Double(300 + step * 400))) * 0.5 * Float(1 - u)
            case "boing":
                v = tone(220 + 180 * sin(2 * .pi * 9 * t) * exp(-3 * u)) * Float(exp(-3 * u))
            case "success":
                let f = u < 0.4 ? 784.0 : 1046.5
                v = Float(sin(2 * .pi * f * t)) * Float(exp(-3 * (u < 0.4 ? u : u - 0.4))) * 0.5
            case "error":
                let f = u < 0.5 ? 220.0 : 180.0
                v = (Float(sin(2 * .pi * f * t)) > 0 ? 0.3 : -0.3) * Float(1 - u)
            default:
                v = 0
            }
            out[i] = max(-1, min(1, v))
        }
        // Short fade at both ends so effects never click.
        let fade = min(n / 4, Int(0.004 * rate))
        for i in 0..<fade {
            let g = Float(i) / Float(max(fade, 1))
            out[i] *= g
            out[n - 1 - i] *= g
        }
        return out
    }
}
