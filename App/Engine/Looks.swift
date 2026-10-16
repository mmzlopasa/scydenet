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
        return out
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
