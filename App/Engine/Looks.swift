import CoreImage
import SCYDECore

struct LookPreset: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Filters and colour adjustments shared by the video compositor and the photo editor.
enum Looks {
    static let presets: [LookPreset] = [
        LookPreset(id: "original", name: "Original"),
        LookPreset(id: "vivid", name: "Vivid"),
        LookPreset(id: "warm", name: "Warm"),
        LookPreset(id: "cool", name: "Cool"),
        LookPreset(id: "mono", name: "Mono"),
        LookPreset(id: "noir", name: "Noir"),
        LookPreset(id: "fade", name: "Fade"),
        LookPreset(id: "chrome", name: "Chrome"),
        LookPreset(id: "instant", name: "Instant"),
        LookPreset(id: "retro", name: "Retro"),
        LookPreset(id: "tonal", name: "Tonal"),
        LookPreset(id: "process", name: "Process"),
        LookPreset(id: "teal", name: "Teal & orange"),
        LookPreset(id: "cinematic", name: "Cinematic"),
        LookPreset(id: "golden", name: "Golden hour"),
        LookPreset(id: "moody", name: "Moody"),
        LookPreset(id: "film", name: "Film"),
        LookPreset(id: "matte", name: "Matte"),
        LookPreset(id: "memories", name: "Memories"),
        LookPreset(id: "bleach", name: "Bleach"),
        LookPreset(id: "pastel", name: "Pastel"),
        LookPreset(id: "cyber", name: "Cyber"),
        LookPreset(id: "sunset", name: "Sunset"),
        LookPreset(id: "forest", name: "Forest"),
        LookPreset(id: "ice", name: "Ice"),
        LookPreset(id: "rose", name: "Rose"),
        LookPreset(id: "night", name: "Night"),
        LookPreset(id: "dramatic", name: "Dramatic"),
        LookPreset(id: "lomo", name: "Lomo"),
        LookPreset(id: "sepia", name: "Sepia"),
        LookPreset(id: "highbw", name: "Hard B&W"),
    ]

    static func apply(_ image: CIImage, filter: String?, adjust: Adjustments?) -> CIImage {
        var out = image
        if let f = filter, f != "original" { out = preset(out, f) }
        if let a = adjust, !a.isNeutral { out = adjustments(out, a) }
        return out
    }

    static func preset(_ image: CIImage, _ id: String) -> CIImage {
        switch id {
        case "vivid":
            return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.35, kCIInputContrastKey: 1.08])
        case "warm": return warmth(image, 0.6)
        case "cool": return warmth(image, -0.6)
        case "mono": return image.applyingFilter("CIPhotoEffectMono")
        case "noir": return image.applyingFilter("CIPhotoEffectNoir")
        case "fade": return image.applyingFilter("CIPhotoEffectFade")
        case "chrome": return image.applyingFilter("CIPhotoEffectChrome")
        case "instant": return image.applyingFilter("CIPhotoEffectInstant")
        case "retro": return image.applyingFilter("CIPhotoEffectTransfer")
        case "tonal": return image.applyingFilter("CIPhotoEffectTonal")
        case "process": return image.applyingFilter("CIPhotoEffectProcess")
        case "teal":
            return matrix(controls(image, sat: 1.15, contrast: 1.1), r: 1.08, g: 1.0, b: 0.9, bias: (0, 0.02, 0.07))
        case "cinematic":
            return curve(warmth(controls(image, sat: 0.85, contrast: 1.12), -0.25), lift: 0.05, highs: 0.96)
        case "golden":
            return warmth(controls(image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.15]), sat: 1.12, contrast: 1.04), 1.0)
        case "moody":
            return warmth(controls(image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -0.25]), sat: 0.7, contrast: 1.15), -0.35)
        case "film":
            return warmth(curve(controls(image, sat: 0.92, contrast: 1.05), lift: 0.07, highs: 0.95), 0.25)
        case "matte":
            return curve(controls(image, sat: 0.88, contrast: 0.95), lift: 0.12, highs: 0.92)
        case "memories":
            return matrix(curve(controls(image, sat: 0.8, contrast: 1.0), lift: 0.08, highs: 0.94), r: 1.06, g: 1.0, b: 0.9, bias: (0.02, 0.01, 0))
        case "bleach": return controls(image, sat: 0.45, contrast: 1.3)
        case "pastel":
            return curve(controls(image, sat: 0.7, contrast: 0.9, brightness: 0.05), lift: 0.1, highs: 1)
        case "cyber": return matrix(controls(image, sat: 1.2, contrast: 1.15), r: 1.1, g: 0.85, b: 1.25, bias: (0.02, 0, 0.04))
        case "sunset": return matrix(warmth(controls(image, sat: 1.15, contrast: 1.05), 0.9), r: 1.06, g: 0.95, b: 1.0, bias: (0, 0, 0.02))
        case "forest": return warmth(matrix(controls(image, sat: 1.1, contrast: 1.05), r: 0.96, g: 1.08, b: 0.96, bias: (0, 0, 0)), -0.15)
        case "ice": return warmth(controls(image, sat: 0.8, contrast: 1.05, brightness: 0.05), -1.0)
        case "rose": return curve(matrix(image, r: 1.08, g: 0.96, b: 1.02, bias: (0.02, 0, 0.01)), lift: 0.05, highs: 0.98)
        case "night":
            return matrix(controls(image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -0.45]), sat: 0.75, contrast: 1.1), r: 0.85, g: 0.95, b: 1.2, bias: (0, 0, 0.03))
        case "dramatic":
            return vignette(controls(image, sat: 1.2, contrast: 1.35), 1.2)
        case "lomo":
            return vignette(controls(image, sat: 1.35, contrast: 1.22), 1.8)
        case "sepia": return image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.9])
        case "highbw": return controls(image.applyingFilter("CIPhotoEffectNoir"), sat: 0, contrast: 1.45)
        default: return image
        }
    }

    static func adjustments(_ image: CIImage, _ a: Adjustments) -> CIImage {
        var out = image
        if abs(a.exposure) > 0.001 {
            out = out.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: a.exposure])
        }
        if abs(a.contrast - 1) > 0.001 || abs(a.saturation - 1) > 0.001 {
            out = out.applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: a.contrast,
                kCIInputSaturationKey: a.saturation,
            ])
        }
        if abs(a.warmth) > 0.001 {
            out = warmth(out, a.warmth)
        }
        let hi = a.highlights ?? 0, sh = a.shadows ?? 0, fd = a.fade ?? 0
        if abs(hi) > 0.005 || abs(sh) > 0.005 || fd > 0.005 {
            out = out.applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: CGFloat(fd * 0.16 + max(0, sh) * 0.02)),
                "inputPoint1": CIVector(x: 0.25, y: CGFloat(0.25 + sh * 0.1 + fd * 0.08)),
                "inputPoint2": CIVector(x: 0.5, y: CGFloat(0.5 + (hi + sh) * 0.03)),
                "inputPoint3": CIVector(x: 0.75, y: CGFloat(0.75 + hi * 0.12)),
                "inputPoint4": CIVector(x: 1, y: CGFloat(1 + min(0, hi) * 0.1)),
            ])
        }
        if let v = a.vibrance, abs(v) > 0.005 {
            out = out.applyingFilter("CIVibrance", parameters: ["inputAmount": v])
        }
        if let h = a.hue, abs(h) > 0.5 {
            out = out.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: h * .pi / 180])
        }
        if let sm = a.smooth, sm > 0.005 {
            // Soft-light blend of a blurred copy: evens out skin and noise, keeps edges readable.
            let r = max(out.extent.width, out.extent.height)
            let sigma = (r.isFinite ? Double(r) : 1000) * 0.004 * sm
            let soft = out.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: image.extent)
                .applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.04 * sm, kCIInputSharpnessKey: 0.3])
            out = SXCompositor.opacity(soft, min(0.85, 0.35 + sm * 0.5)).composited(over: out)
        }
        if let t = a.tint, abs(t) > 0.005 {
            out = matrix(out, r: 1 + CGFloat(t) * 0.06, g: 1 - CGFloat(t) * 0.1, b: 1 + CGFloat(t) * 0.06, bias: (0, 0, 0))
        }
        if let c = a.clarity, abs(c) > 0.005 {
            let r = max(out.extent.width, out.extent.height) * 0.015
            out = out.clampedToExtent()
                .applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: r.isFinite ? r : 20, kCIInputIntensityKey: c * 0.8])
                .cropped(to: image.extent)
        }
        if let sp = a.sharpness, sp > 0.005 {
            out = out.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: sp * 1.2])
        }
        if let v = a.vignette, abs(v) > 0.005 {
            out = vignette(out, v * 2)
        }
        if let g = a.grain, g > 0.005, image.extent.width.isFinite {
            out = Effects.grain(out, canvas: image.extent, t: 0, amount: CGFloat(g) * 0.6)
        }
        return out
    }

    static func controls(_ image: CIImage, sat: Double, contrast: Double, brightness: Double = 0) -> CIImage {
        image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: sat,
            kCIInputContrastKey: contrast,
            kCIInputBrightnessKey: brightness,
        ])
    }

    static func matrix(_ image: CIImage, r: CGFloat, g: CGFloat, b: CGFloat, bias: (CGFloat, CGFloat, CGFloat)) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: r, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: g, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: b, w: 0),
            "inputBiasVector": CIVector(x: bias.0, y: bias.1, z: bias.2, w: 0),
        ])
    }

    /// Lifted blacks and softened whites.
    static func curve(_ image: CIImage, lift: CGFloat, highs: CGFloat) -> CIImage {
        image.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0, y: lift),
            "inputPoint1": CIVector(x: 0.25, y: 0.25 + lift * 0.4),
            "inputPoint2": CIVector(x: 0.5, y: 0.5),
            "inputPoint3": CIVector(x: 0.75, y: 0.75 - (1 - highs) * 0.4),
            "inputPoint4": CIVector(x: 1, y: highs),
        ])
    }

    static func vignette(_ image: CIImage, _ intensity: Double) -> CIImage {
        image.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: intensity, kCIInputRadiusKey: 1.6])
    }

    /// Warm (+) or cool (-) by scaling red and blue.
    static func warmth(_ image: CIImage, _ amount: Double) -> CIImage {
        let k = CGFloat(0.12 * amount)
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1 + k, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1 - k, w: 0),
        ])
    }

    /// Simple auto enhance from the image's average colour.
    static func autoAdjust(for image: CIImage, context: CIContext) -> Adjustments {
        let extent = image.extent
        guard extent.width.isFinite, extent.width > 0,
              let avg = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey: image,
                  kCIInputExtentKey: CIVector(cgRect: extent),
              ])?.outputImage
        else { return Adjustments(contrast: 1.06, saturation: 1.12) }
        var px = [UInt8](repeating: 0, count: 4)
        context.render(
            avg,
            toBitmap: &px,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        let r = Double(px[0]) / 255, g = Double(px[1]) / 255, b = Double(px[2]) / 255
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let ev = max(-1, min(1, log2(0.48 / max(luma, 0.02)) * 0.7))
        let warm = max(-0.5, min(0.5, (b - r) * 0.8))
        return Adjustments(exposure: ev, contrast: 1.06, saturation: 1.12, warmth: warm)
    }
}
