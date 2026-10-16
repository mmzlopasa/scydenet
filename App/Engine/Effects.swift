import CoreImage
import UIKit
import SCYDECore

struct EffectInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let group: String
}

extension CIImage {
    /// Applies a Core Image filter by name, returning the input unchanged if the filter
    /// does not exist on this OS (so one missing filter can never blank a frame).
    func sx(_ name: String, _ params: [String: Any] = [:]) -> CIImage {
        guard let f = CIFilter(name: name) else { return self }
        if f.inputKeys.contains(kCIInputImageKey) {
            f.setValue(self, forKey: kCIInputImageKey)
        }
        for (k, v) in params where f.inputKeys.contains(k) { f.setValue(v, forKey: k) }
        return f.outputImage ?? self
    }
}

/// Visual effects applied per clip by the compositor. `t` is seconds since the clip started.
enum Effects {
    static let all: [EffectInfo] = [
        EffectInfo(id: "glitch", name: "Glitch", icon: "waveform.path.ecg", group: "Motion"),
        EffectInfo(id: "shake", name: "Shake", icon: "iphone.radiowaves.left.and.right", group: "Motion"),
        EffectInfo(id: "pulse", name: "Pulse", icon: "dot.radiowaves.left.and.right", group: "Motion"),
        EffectInfo(id: "strobe", name: "Strobe", icon: "light.max", group: "Motion"),
        EffectInfo(id: "zoomblur", name: "Zoom blur", icon: "scope", group: "Motion"),
        EffectInfo(id: "twirl", name: "Twirl", icon: "tornado", group: "Motion"),
        EffectInfo(id: "rainbow", name: "Rainbow", icon: "rainbow", group: "Motion"),
        EffectInfo(id: "vhs", name: "VHS", icon: "film", group: "Retro"),
        EffectInfo(id: "oldfilm", name: "Old film", icon: "film.stack", group: "Retro"),
        EffectInfo(id: "crt", name: "CRT", icon: "tv", group: "Retro"),
        EffectInfo(id: "grain", name: "Grain", icon: "circle.dotted", group: "Retro"),
        EffectInfo(id: "halftone", name: "Halftone", icon: "circle.grid.3x3.fill", group: "Retro"),
        EffectInfo(id: "pixelate", name: "Pixelate", icon: "square.grid.4x3.fill", group: "Retro"),
        EffectInfo(id: "posterize", name: "Posterize", icon: "paintpalette", group: "Retro"),
        EffectInfo(id: "glow", name: "Glow", icon: "sun.max", group: "Light"),
        EffectInfo(id: "dreamy", name: "Dreamy", icon: "cloud", group: "Light"),
        EffectInfo(id: "leak", name: "Light leak", icon: "sun.haze", group: "Light"),
        EffectInfo(id: "vignette", name: "Vignette", icon: "circle.dashed", group: "Light"),
        EffectInfo(id: "letterbox", name: "Cinema bars", icon: "rectangle.ratio.16.to.9", group: "Light"),
        EffectInfo(id: "blur", name: "Blur", icon: "drop", group: "Light"),
        EffectInfo(id: "mirror", name: "Mirror", icon: "square.split.2x1", group: "Frame"),
        EffectInfo(id: "split4", name: "Split 4", icon: "square.grid.2x2", group: "Frame"),
        EffectInfo(id: "split3", name: "Split 3", icon: "rectangle.split.3x1", group: "Frame"),
        EffectInfo(id: "kaleido", name: "Kaleido", icon: "hexagon", group: "Frame"),
        EffectInfo(id: "bulge", name: "Bulge", icon: "circle.circle", group: "Frame"),
        EffectInfo(id: "comic", name: "Comic", icon: "bubble.left.and.exclamationmark.bubble.right", group: "Art"),
        EffectInfo(id: "sketch", name: "Sketch", icon: "pencil.and.outline", group: "Art"),
        EffectInfo(id: "neon", name: "Neon edges", icon: "scribble.variable", group: "Art"),
        EffectInfo(id: "duotone", name: "Duotone", icon: "circle.lefthalf.filled", group: "Art"),
        EffectInfo(id: "thermal", name: "Thermal", icon: "thermometer.sun", group: "Art"),
        EffectInfo(id: "xray", name: "X-ray", icon: "rays", group: "Art"),
        EffectInfo(id: "invert", name: "Invert", icon: "circle.righthalf.filled", group: "Art"),
        EffectInfo(id: "pushin", name: "Push in", icon: "arrow.up.left.and.arrow.down.right", group: "Motion"),
        EffectInfo(id: "pushout", name: "Pull out", icon: "arrow.down.right.and.arrow.up.left", group: "Motion"),
        EffectInfo(id: "slowspin", name: "Slow spin", icon: "arrow.triangle.2.circlepath", group: "Motion"),
        EffectInfo(id: "flicker", name: "Flicker", icon: "lightbulb", group: "Motion"),
        EffectInfo(id: "chromatic", name: "Chromatic", icon: "circle.hexagongrid", group: "Retro"),
        EffectInfo(id: "filmburn", name: "Film burn", icon: "flame", group: "Retro"),
        EffectInfo(id: "lensflare", name: "Lens flare", icon: "sun.max.circle", group: "Light"),
        EffectInfo(id: "sparkle", name: "Sparkle", icon: "sparkles", group: "Light"),
        EffectInfo(id: "fisheye", name: "Fisheye", icon: "eye", group: "Frame"),
        EffectInfo(id: "vortex", name: "Vortex", icon: "hurricane", group: "Frame"),
        EffectInfo(id: "snow", name: "Snow", icon: "snowflake", group: "Particles"),
        EffectInfo(id: "rain", name: "Rain", icon: "cloud.rain", group: "Particles"),
        EffectInfo(id: "confetti", name: "Confetti", icon: "party.popper", group: "Particles"),
        EffectInfo(id: "hearts", name: "Hearts", icon: "heart", group: "Particles"),
        EffectInfo(id: "bubbles", name: "Bubbles", icon: "bubbles.and.sparkles", group: "Particles"),
        EffectInfo(id: "stars", name: "Stars", icon: "star", group: "Particles"),
        EffectInfo(id: "infrared", name: "Infrared", icon: "flame.circle", group: "Art"),
        EffectInfo(id: "cartoon", name: "Cartoon", icon: "paintbrush.pointed", group: "Art"),
    ]

    static let groups = ["Motion", "Retro", "Light", "Particles", "Frame", "Art"]

    static func info(_ id: String) -> EffectInfo? { all.first { $0.id == id } }

    static func apply(_ image: CIImage, _ effect: VideoEffect, canvas: CGRect, t: Double) -> CIImage {
        let k = CGFloat(max(0, min(1, effect.intensity)))
        let w = canvas.width
        let h = canvas.height
        let c = CIVector(x: canvas.midX, y: canvas.midY)
        switch effect.kind {
        case "glitch":
            let burst = sin(t * 37) > 0.55 || sin(t * 11.3) > 0.9
            let dx = w * 0.012 * k * (burst ? 2.6 : 0.7)
            var out = rgbSplit(image, dx: dx)
            if burst {
                let band = CGRect(x: canvas.minX, y: canvas.minY + h * CGFloat((sin(t * 5.1) + 1) / 2) * 0.8, width: w, height: h * 0.08)
                let slice = out.cropped(to: band).transformed(by: CGAffineTransform(translationX: w * 0.05 * k * CGFloat(sin(t * 23)), y: 0))
                out = slice.composited(over: out)
            }
            return out
        case "shake":
            let a = w * 0.025 * k
            let dx = a * CGFloat(sin(t * 47) * 0.6 + sin(t * 23) * 0.4)
            let dy = a * CGFloat(cos(t * 41) * 0.6 + cos(t * 17) * 0.4)
            return zoom(image, 1 + 0.06 * k, canvas).transformed(by: CGAffineTransform(translationX: dx, y: dy))
        case "pulse":
            let s = 1 + 0.08 * k * CGFloat(abs(sin(t * .pi * 2)))
            return zoom(image, s, canvas)
        case "strobe":
            let on = Int(t * 8) % 2 == 0
            guard on else { return image }
            return CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 0.55 * k)).cropped(to: canvas).composited(over: image)
        case "zoomblur":
            return image.clampedToExtent().sx("CIZoomBlur", [kCIInputCenterKey: c, "inputAmount": 6 + 30 * k]).cropped(to: canvas)
        case "twirl":
            return image.clampedToExtent().sx("CITwirlDistortion", [
                kCIInputCenterKey: c,
                kCIInputRadiusKey: min(w, h) * 0.6,
                kCIInputAngleKey: CGFloat(sin(t * 1.5)) * 3 * k,
            ]).cropped(to: canvas)
        case "rainbow":
            return image.sx("CIHueAdjust", [kCIInputAngleKey: CGFloat(t) * (1 + 3 * k)])
        case "vhs":
            var out = rgbSplit(image, dx: w * 0.004 * (0.5 + k))
            out = out.sx("CIColorControls", [kCIInputSaturationKey: 1.25, kCIInputContrastKey: 1.08])
            out = scanlines(out, canvas: canvas, opacity: 0.18 * k, spacing: max(2, h / 240))
            out = grain(out, canvas: canvas, t: t, amount: 0.25 * k)
            let jitter = sin(t * 61) > 0.97 ? w * 0.01 : 0
            return out.transformed(by: CGAffineTransform(translationX: jitter, y: 0))
        case "oldfilm":
            var out = image.sx("CISepiaTone", [kCIInputIntensityKey: 0.6 + 0.4 * k])
            let flicker = 1 + 0.06 * k * CGFloat(sin(t * 29) * sin(t * 13))
            out = out.sx("CIColorControls", [kCIInputBrightnessKey: flicker - 1])
            out = grain(out, canvas: canvas, t: t, amount: 0.45 * k)
            return vignette(out, canvas: canvas, amount: 0.8 + k)
        case "crt":
            var out = image.clampedToExtent().sx("CIBumpDistortion", [
                kCIInputCenterKey: c, kCIInputRadiusKey: max(w, h) * 0.9, kCIInputScaleKey: 0.12 * k,
            ]).cropped(to: canvas)
            out = scanlines(out, canvas: canvas, opacity: 0.28 * k, spacing: max(3, h / 200))
            return vignette(out, canvas: canvas, amount: 1 + k)
        case "grain":
            return grain(image, canvas: canvas, t: t, amount: 0.6 * k)
        case "halftone":
            return image.sx("CIDotScreen", [kCIInputCenterKey: c, kCIInputWidthKey: 4 + 14 * k, kCIInputSharpnessKey: 0.7])
        case "pixelate":
            return image.clampedToExtent().sx("CIPixellate", [kCIInputCenterKey: c, kCIInputScaleKey: max(4, w * 0.06 * k)]).cropped(to: canvas)
        case "posterize":
            return image.sx("CIColorPosterize", ["inputLevels": 12 - 9 * k])
        case "glow":
            return image.clampedToExtent().sx("CIBloom", [kCIInputRadiusKey: 8 + w * 0.03 * k, kCIInputIntensityKey: 0.4 + 0.8 * k]).cropped(to: canvas)
        case "dreamy":
            let soft = image.clampedToExtent().applyingGaussianBlur(sigma: Double(w) * 0.012).cropped(to: canvas)
            let bright = soft.sx("CIColorControls", [kCIInputBrightnessKey: 0.08, kCIInputSaturationKey: 1.15])
            return SXCompositor.opacity(bright, Double(0.35 + 0.4 * k)).composited(over: image)
                .sx("CIBloom", [kCIInputRadiusKey: w * 0.02, kCIInputIntensityKey: 0.5 * k]).cropped(to: canvas)
        case "leak":
            let x = canvas.minX + w * CGFloat(0.5 + 0.45 * sin(t * 0.7))
            let y = canvas.minY + h * CGFloat(0.65 + 0.25 * cos(t * 0.5))
            let g = CIImage.empty().sx("CIRadialGradient", [
                kCIInputCenterKey: CIVector(x: x, y: y),
                "inputRadius0": 0,
                "inputRadius1": max(w, h) * 0.7,
                "inputColor0": CIColor(red: 1, green: 0.55, blue: 0.2, alpha: 0.85 * k),
                "inputColor1": CIColor(red: 1, green: 0.2, blue: 0.4, alpha: 0),
            ]).cropped(to: canvas)
            return g.sx("CIScreenBlendMode", [kCIInputBackgroundImageKey: image])
        case "vignette":
            return vignette(image, canvas: canvas, amount: 0.5 + 1.5 * k)
        case "letterbox":
            let bar = h * (0.06 + 0.1 * k)
            let black = CIImage(color: .black)
            let top = black.cropped(to: CGRect(x: canvas.minX, y: canvas.maxY - bar, width: w, height: bar))
            let bottom = black.cropped(to: CGRect(x: canvas.minX, y: canvas.minY, width: w, height: bar))
            return top.composited(over: bottom.composited(over: image))
        case "blur":
            return image.clampedToExtent().applyingGaussianBlur(sigma: Double(k) * Double(w) * 0.03).cropped(to: canvas)
        case "mirror":
            let left = image.cropped(to: CGRect(x: canvas.minX, y: canvas.minY, width: w / 2, height: h))
            let flipped = left.transformed(by: CGAffineTransform(scaleX: -1, y: 1).concatenating(CGAffineTransform(translationX: canvas.minX * 2 + w, y: 0)))
            return flipped.composited(over: left)
        case "split4":
            return grid(image, canvas: canvas, cols: 2, rows: 2)
        case "split3":
            return w < h ? grid(image, canvas: canvas, cols: 1, rows: 3) : grid(image, canvas: canvas, cols: 3, rows: 1)
        case "kaleido":
            return image.clampedToExtent().sx("CIKaleidoscope", [kCIInputCenterKey: c, "inputCount": 6, kCIInputAngleKey: CGFloat(t) * 0.4 * k]).cropped(to: canvas)
        case "bulge":
            let s = 0.5 * k * CGFloat(0.7 + 0.3 * sin(t * 3))
            return image.clampedToExtent().sx("CIBumpDistortion", [kCIInputCenterKey: c, kCIInputRadiusKey: min(w, h) * 0.45, kCIInputScaleKey: s]).cropped(to: canvas)
        case "comic":
            return mix(image.sx("CIComicEffect"), over: image, k)
        case "sketch":
            let edges = image.sx("CIPhotoEffectMono").sx("CIEdges", [kCIInputIntensityKey: 4 + 6 * k]).sx("CIColorInvert")
            return mix(edges, over: image, 0.5 + 0.5 * k).cropped(to: canvas)
        case "neon":
            let edges = image.sx("CIEdges", [kCIInputIntensityKey: 6 + 10 * k])
                .sx("CIHueAdjust", [kCIInputAngleKey: CGFloat(t)])
                .sx("CIBloom", [kCIInputRadiusKey: w * 0.01, kCIInputIntensityKey: 1])
            let dark = image.sx("CIColorControls", [kCIInputBrightnessKey: -0.35 * k])
            return edges.sx("CIAdditionCompositing", [kCIInputBackgroundImageKey: dark]).cropped(to: canvas)
        case "duotone":
            let d = image.sx("CIFalseColor", [
                "inputColor0": CIColor(red: 0.106, green: 0.082, blue: 0.188),
                "inputColor1": CIColor(red: 1, green: 0.843, blue: 0.416),
            ])
            return mix(d, over: image, k)
        case "thermal":
            return mix(image.sx("CIThermal"), over: image, k)
        case "xray":
            return mix(image.sx("CIXRay"), over: image, k)
        case "invert":
            return mix(image.sx("CIColorInvert"), over: image, k)
        case "pushin":
            return zoom(image, 1 + 0.25 * k * CGFloat(min(t / 4, 1)), canvas)
        case "pushout":
            return zoom(image, 1 + 0.25 * k * CGFloat(max(0, 1 - t / 4)), canvas)
        case "slowspin":
            let a = CGFloat(t) * 0.25 * k
            let z = 1 + 0.35 * k
            return image.transformed(by: CGAffineTransform(translationX: -canvas.midX, y: -canvas.midY)
                .concatenating(CGAffineTransform(scaleX: z, y: z))
                .concatenating(CGAffineTransform(rotationAngle: a))
                .concatenating(CGAffineTransform(translationX: canvas.midX, y: canvas.midY))).cropped(to: canvas)
        case "flicker":
            let v = sin(t * 47) * sin(t * 23)
            return image.sx("CIColorControls", [kCIInputBrightnessKey: CGFloat(v) * 0.18 * k])
        case "chromatic":
            return rgbSplit(image, dx: w * 0.008 * k)
        case "filmburn":
            let x = canvas.minX + w * CGFloat(0.2 + 0.6 * (sin(t * 0.9) + 1) / 2)
            let burn = CIImage.empty().sx("CIRadialGradient", [
                kCIInputCenterKey: CIVector(x: x, y: canvas.maxY - h * 0.15),
                "inputRadius0": 0,
                "inputRadius1": max(w, h) * 0.55,
                "inputColor0": CIColor(red: 1, green: 0.45, blue: 0.05, alpha: 0.95 * k),
                "inputColor1": CIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0),
            ]).cropped(to: canvas)
            let flick = 1 + 0.08 * CGFloat(sin(t * 31))
            return burn.sx("CIScreenBlendMode", [kCIInputBackgroundImageKey: image.sx("CIColorControls", [kCIInputBrightnessKey: flick - 1])])
        case "lensflare":
            let fx = canvas.minX + w * CGFloat(0.75 + 0.08 * sin(t * 0.6))
            let fy = canvas.minY + h * 0.78
            var flare = CIImage.empty().sx("CIRadialGradient", [
                kCIInputCenterKey: CIVector(x: fx, y: fy), "inputRadius0": 0, "inputRadius1": w * 0.35,
                "inputColor0": CIColor(red: 1, green: 0.95, blue: 0.8, alpha: 0.9 * k),
                "inputColor1": CIColor(red: 1, green: 0.6, blue: 0.2, alpha: 0),
            ]).cropped(to: canvas)
            // Ghost rings along the line through the centre.
            for i in 1...3 {
                let u = CGFloat(i) * 0.45
                let gx = fx + (canvas.midX - fx) * u * 2, gy = fy + (canvas.midY - fy) * u * 2
                let ring = CIImage.empty().sx("CIRadialGradient", [
                    kCIInputCenterKey: CIVector(x: gx, y: gy), "inputRadius0": w * 0.02 * CGFloat(i), "inputRadius1": w * 0.05 * CGFloat(i),
                    "inputColor0": CIColor(red: 0.6, green: 0.8, blue: 1, alpha: 0.25 * k),
                    "inputColor1": CIColor(red: 0.6, green: 0.8, blue: 1, alpha: 0),
                ]).cropped(to: canvas)
                flare = ring.sx("CIAdditionCompositing", [kCIInputBackgroundImageKey: flare])
            }
            return flare.sx("CIScreenBlendMode", [kCIInputBackgroundImageKey: image]).cropped(to: canvas)
        case "sparkle":
            let glow = image.sx("CIColorControls", [kCIInputBrightnessKey: -0.55, kCIInputContrastKey: 3])
                .clampedToExtent().sx("CIBloom", [kCIInputRadiusKey: w * 0.02, kCIInputIntensityKey: 1.5 * k]).cropped(to: canvas)
            let stars = Particles.layer(.stars, canvas: canvas, t: t, amount: k)
            return stars.composited(over: glow.sx("CIScreenBlendMode", [kCIInputBackgroundImageKey: image]))
        case "fisheye":
            return image.clampedToExtent().sx("CIBumpDistortion", [kCIInputCenterKey: c, kCIInputRadiusKey: max(w, h) * 0.7, kCIInputScaleKey: 0.6 * k]).cropped(to: canvas)
        case "vortex":
            return image.clampedToExtent().sx("CIVortexDistortion", [kCIInputCenterKey: c, kCIInputRadiusKey: min(w, h) * 0.5, kCIInputAngleKey: CGFloat(sin(t * 1.2)) * 200 * k]).cropped(to: canvas)
        case "snow":
            return Particles.layer(.snow, canvas: canvas, t: t, amount: k).composited(over: image)
        case "rain":
            return Particles.layer(.rain, canvas: canvas, t: t, amount: k).composited(over: image.sx("CIColorControls", [kCIInputBrightnessKey: -0.08 * k, kCIInputSaturationKey: 1 - 0.3 * k]))
        case "confetti":
            return Particles.layer(.confetti, canvas: canvas, t: t, amount: k).composited(over: image)
        case "hearts":
            return Particles.layer(.hearts, canvas: canvas, t: t, amount: k).composited(over: image)
        case "bubbles":
            return Particles.layer(.bubbles, canvas: canvas, t: t, amount: k).composited(over: image)
        case "stars":
            return Particles.layer(.stars, canvas: canvas, t: t, amount: k).composited(over: image)
        case "infrared":
            let ir = image.sx("CIFalseColor", [
                "inputColor0": CIColor(red: 0.15, green: 0.0, blue: 0.25),
                "inputColor1": CIColor(red: 1, green: 0.55, blue: 0.75),
            ])
            return mix(ir, over: image, k)
        case "cartoon":
            let flat = image.sx("CIColorPosterize", ["inputLevels": 6]).sx("CIColorControls", [kCIInputSaturationKey: 1.4])
            let lines = image.sx("CIPhotoEffectMono").sx("CIEdges", [kCIInputIntensityKey: 5]).sx("CIColorInvert")
            let toon = flat.sx("CIMultiplyBlendMode", [kCIInputBackgroundImageKey: lines]).cropped(to: canvas)
            return mix(toon, over: image, k)
        default:
            return image
        }
    }

    // MARK: Building blocks

    static func zoom(_ image: CIImage, _ s: CGFloat, _ canvas: CGRect) -> CIImage {
        image.transformed(by: CGAffineTransform(translationX: -canvas.midX, y: -canvas.midY)
            .concatenating(CGAffineTransform(scaleX: s, y: s))
            .concatenating(CGAffineTransform(translationX: canvas.midX, y: canvas.midY)))
    }

    static func mix(_ top: CIImage, over base: CIImage, _ amount: CGFloat) -> CIImage {
        if amount >= 0.999 { return top }
        return SXCompositor.opacity(top, Double(amount)).composited(over: base)
    }

    static func rgbSplit(_ image: CIImage, dx: CGFloat) -> CIImage {
        // Each copy keeps one colour channel and the original alpha; the per-component
        // maximum of the three puts the colour back together without overflowing alpha.
        func channel(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CIImage {
            image.sx("CIColorMatrix", [
                "inputRVector": CIVector(x: r, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: g, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: b, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            ])
        }
        let red = channel(1, 0, 0).transformed(by: CGAffineTransform(translationX: dx, y: 0))
        let green = channel(0, 1, 0)
        let blue = channel(0, 0, 1).transformed(by: CGAffineTransform(translationX: -dx, y: 0))
        let rg = red.sx("CIMaximumCompositing", [kCIInputBackgroundImageKey: green])
        return blue.sx("CIMaximumCompositing", [kCIInputBackgroundImageKey: rg]).cropped(to: image.extent)
    }

    static func scanlines(_ image: CIImage, canvas: CGRect, opacity: CGFloat, spacing: CGFloat) -> CIImage {
        let stripes = CIImage.empty().sx("CIStripesGenerator", [
            "inputColor0": CIColor(red: 0, green: 0, blue: 0, alpha: opacity),
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
            kCIInputWidthKey: spacing,
            "inputSharpness": 0.5,
        ])
        // Generated stripes are vertical; turn them horizontal.
        let rotated = stripes.transformed(by: CGAffineTransform(rotationAngle: .pi / 2)).cropped(to: canvas)
        return rotated.composited(over: image)
    }

    static func grain(_ image: CIImage, canvas: CGRect, t: Double, amount: CGFloat) -> CIImage {
        guard amount > 0.001 else { return image }
        let shift = CGFloat(Int(t * 24) % 97) * 37
        let noise = CIImage.empty().sx("CIRandomGenerator")
            .transformed(by: CGAffineTransform(translationX: shift, y: shift * 0.7))
            .sx("CIColorMatrix", [
                "inputRVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: amount),
            ])
            .cropped(to: canvas)
        return noise.sx("CISoftLightBlendMode", [kCIInputBackgroundImageKey: image]).cropped(to: image.extent)
    }

    static func vignette(_ image: CIImage, canvas: CGRect, amount: CGFloat) -> CIImage {
        image.sx("CIVignetteEffect", [
            kCIInputCenterKey: CIVector(x: canvas.midX, y: canvas.midY),
            kCIInputRadiusKey: max(canvas.width, canvas.height) * 0.62,
            kCIInputIntensityKey: amount,
            "inputFalloff": 0.6,
        ])
    }

    static func grid(_ image: CIImage, canvas: CGRect, cols: Int, rows: Int) -> CIImage {
        let cw = canvas.width / CGFloat(cols)
        let ch = canvas.height / CGFloat(rows)
        let s = max(cw / canvas.width, ch / canvas.height)
        var out = CIImage(color: .black).cropped(to: canvas)
        for r in 0..<rows {
            for col in 0..<cols {
                let cell = CGRect(x: canvas.minX + CGFloat(col) * cw, y: canvas.minY + CGFloat(r) * ch, width: cw, height: ch)
                let scaled = image.transformed(by: CGAffineTransform(translationX: -canvas.midX, y: -canvas.midY)
                    .concatenating(CGAffineTransform(scaleX: s, y: s))
                    .concatenating(CGAffineTransform(translationX: cell.midX, y: cell.midY)))
                out = scaled.cropped(to: cell).composited(over: out)
            }
        }
        return out
    }
}

/// Shape masks for clips, built in canvas coordinates.
enum Masks {
    private static let lock = NSLock()
    private static var shapes: [String: CIImage] = [:]

    static func apply(_ image: CIImage, _ mask: ClipMask, canvas: CGRect, offset: ClipTransform) -> CIImage {
        guard let m = matte(mask, canvas: canvas, offset: offset) else { return image }
        return image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: m,
        ])
    }

    /// White where the clip shows, black where it is hidden.
    static func matte(_ mask: ClipMask, canvas: CGRect, offset: ClipTransform) -> CIImage? {
        let short = min(canvas.width, canvas.height)
        let cx = canvas.midX + CGFloat(mask.x + offset.x) * canvas.width
        let cy = canvas.midY - CGFloat(mask.y + offset.y) * canvas.height
        let angle = CGFloat(-mask.rotation * .pi / 180)
        let feather = CGFloat(max(0, min(1, mask.feather)))
        let black = CIImage(color: .black).cropped(to: canvas)
        var out: CIImage

        switch mask.shape {
        case .linear, .mirror:
            // Built horizontally around the origin, then rotated and moved.
            let soft = max(1, feather * short * 0.5)
            let half = max(2, CGFloat(mask.size) * short * 0.5)
            func edge(_ from: CGFloat, _ to: CGFloat) -> CIImage {
                CIImage.empty().sx("CILinearGradient", [
                    "inputPoint0": CIVector(x: 0, y: from),
                    "inputPoint1": CIVector(x: 0, y: to),
                    "inputColor0": CIColor(red: 1, green: 1, blue: 1),
                    "inputColor1": CIColor(red: 0, green: 0, blue: 0),
                ])
            }
            var g: CIImage
            if mask.shape == .linear {
                // Visible below the line (screen space), i.e. negative y in CI space.
                g = edge(-soft / 2, soft / 2)
            } else {
                let top = edge(half - soft, half)
                let bottom = edge(-half + soft, -half)
                g = top.sx("CIMinimumCompositing", [kCIInputBackgroundImageKey: bottom])
            }
            let big = max(canvas.width, canvas.height) * 3
            g = g.cropped(to: CGRect(x: -big, y: -big, width: big * 2, height: big * 2))
            out = g.transformed(by: CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: cx, y: cy)))
                .cropped(to: canvas)
        default:
            let w = CGFloat(mask.size) * short * CGFloat(max(0.1, mask.shape == .circle || mask.shape == .rectangle ? mask.aspect : 1))
            let h = CGFloat(mask.size) * short
            guard let shape = shapeImage(mask.shape) else { return nil }
            let e = shape.extent
            var placed = shape.transformed(by: CGAffineTransform(translationX: -e.midX, y: -e.midY)
                .concatenating(CGAffineTransform(scaleX: w / e.width, y: h / e.height))
                .concatenating(CGAffineTransform(rotationAngle: angle))
                .concatenating(CGAffineTransform(translationX: cx, y: cy)))
            placed = placed.composited(over: black)
            if feather > 0.001 {
                placed = placed.clampedToExtent().applyingGaussianBlur(sigma: Double(feather * min(w, h) * 0.12)).cropped(to: canvas)
            }
            out = placed.cropped(to: canvas)
        }
        out = out.composited(over: black)
        if mask.invert { out = out.sx("CIColorInvert") }
        return out
    }

    /// A white shape on transparent, 512 px, cached.
    private static func shapeImage(_ shape: MaskShape) -> CIImage? {
        let key = shape.rawValue
        lock.lock()
        if let hit = shapes[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        let size = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let r = CGRect(origin: .zero, size: size)
        let path: UIBezierPath
        switch shape {
        case .circle: path = UIBezierPath(ovalIn: r)
        case .rectangle: path = UIBezierPath(roundedRect: r, cornerRadius: 24)
        case .heart: path = heart(in: r)
        case .star: path = star(in: r)
        default: path = UIBezierPath(rect: r)
        }
        let img = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            path.fill()
        }
        guard let cg = img.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        lock.lock()
        shapes[key] = ci
        lock.unlock()
        return ci
    }

    private static func heart(in r: CGRect) -> UIBezierPath {
        let p = UIBezierPath()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.95))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.32), controlPoint1: CGPoint(x: w * 0.2, y: h * 0.75), controlPoint2: CGPoint(x: 0, y: h * 0.55))
        p.addArc(withCenter: CGPoint(x: w * 0.25, y: h * 0.3), radius: w * 0.25, startAngle: .pi, endAngle: 0, clockwise: true)
        p.addArc(withCenter: CGPoint(x: w * 0.75, y: h * 0.3), radius: w * 0.25, startAngle: .pi, endAngle: 0, clockwise: true)
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.95), controlPoint1: CGPoint(x: w, y: h * 0.55), controlPoint2: CGPoint(x: w * 0.8, y: h * 0.75))
        p.close()
        return p
    }

    private static func star(in r: CGRect) -> UIBezierPath {
        let p = UIBezierPath()
        let c = CGPoint(x: r.midX, y: r.midY + r.height * 0.04)
        let outer = r.width * 0.5
        let inner = outer * 0.42
        for i in 0..<10 {
            let a = CGFloat(i) * .pi / 5 - .pi / 2
            let rad = i % 2 == 0 ? outer : inner
            let pt = CGPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.close()
        return p
    }
}

/// Blend modes for overlay clips.
enum Blends {
    static func filterName(_ mode: LayerBlend) -> String? {
        switch mode {
        case .normal: return nil
        case .multiply: return "CIMultiplyBlendMode"
        case .screen: return "CIScreenBlendMode"
        case .overlay: return "CIOverlayBlendMode"
        case .softLight: return "CISoftLightBlendMode"
        case .hardLight: return "CIHardLightBlendMode"
        case .darken: return "CIDarkenBlendMode"
        case .lighten: return "CILightenBlendMode"
        case .colorDodge: return "CIColorDodgeBlendMode"
        case .colorBurn: return "CIColorBurnBlendMode"
        case .difference: return "CIDifferenceBlendMode"
        case .exclusion: return "CIExclusionBlendMode"
        case .add: return "CIAdditionCompositing"
        case .hue: return "CIHueBlendMode"
        case .color: return "CIColorBlendMode"
        case .luminosity: return "CILuminosityBlendMode"
        }
    }

    static func title(_ mode: LayerBlend) -> String {
        switch mode {
        case .normal: return "Normal"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        case .overlay: return "Overlay"
        case .softLight: return "Soft light"
        case .hardLight: return "Hard light"
        case .darken: return "Darken"
        case .lighten: return "Lighten"
        case .colorDodge: return "Color dodge"
        case .colorBurn: return "Color burn"
        case .difference: return "Difference"
        case .exclusion: return "Exclusion"
        case .add: return "Add"
        case .hue: return "Hue"
        case .color: return "Color"
        case .luminosity: return "Luminosity"
        }
    }

    static func apply(_ top: CIImage, over base: CIImage, _ mode: LayerBlend) -> CIImage {
        guard let name = filterName(mode) else { return top.composited(over: base) }
        // Blend only where the overlay is, keep the base elsewhere.
        let blended = top.sx(name, [kCIInputBackgroundImageKey: base]).cropped(to: top.extent.intersection(base.extent))
        return blended.composited(over: base)
    }
}


/// Falling or rising particles drawn with Core Graphics, deterministic for a given time.
enum Particles {
    enum Kind { case snow, rain, confetti, hearts, bubbles, stars }

    private static func hash(_ n: Int, _ salt: Int) -> Double {
        var x = UInt64(truncatingIfNeeded: n &* 73_856_093 ^ salt &* 19_349_663)
        x = (x ^ (x >> 33)) &* 0xff51afd7ed558ccd
        x = (x ^ (x >> 33)) &* 0xc4ceb9fe1a85ec53
        x ^= x >> 33
        return Double(x % 10_000) / 10_000
    }

    static func layer(_ kind: Kind, canvas: CGRect, t: Double, amount: CGFloat) -> CIImage {
        // Drawn at half resolution; particles are soft enough not to need more.
        let scale: CGFloat = 0.5
        let size = CGSize(width: max(2, canvas.width * scale), height: max(2, canvas.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let count: Int
        switch kind {
        case .rain: count = Int(140 * amount) + 20
        case .snow: count = Int(110 * amount) + 15
        case .stars: count = Int(40 * amount) + 8
        default: count = Int(55 * amount) + 10
        }
        let w = Double(size.width), h = Double(size.height)
        let palette: [UIColor] = [UIColor(hex: 0xFFD76A), UIColor(hex: 0xC4BBFF), UIColor(hex: 0x8EF0C8), UIColor(hex: 0xFF9AA8), UIColor(hex: 0x6EC6FF), .white]
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let g = ctx.cgContext
            for n in 0..<count {
                let r1 = hash(n, 1), r2 = hash(n, 2), r3 = hash(n, 3)
                switch kind {
                case .snow:
                    let speed = 0.06 + r3 * 0.1
                    let y = (r2 + t * speed).truncatingRemainder(dividingBy: 1)
                    let x = r1 + 0.02 * sin(t * 1.5 + r3 * 6)
                    let d = 2 + r3 * 5
                    g.setFillColor(UIColor(white: 1, alpha: 0.55 + 0.4 * r3).cgColor)
                    g.fillEllipse(in: CGRect(x: x.truncatingRemainder(dividingBy: 1) * w, y: y * h, width: d, height: d))
                case .rain:
                    let y = (r2 + t * (0.9 + r3 * 0.6)).truncatingRemainder(dividingBy: 1)
                    let x = r1 * w
                    let len = 8 + r3 * 14
                    g.setStrokeColor(UIColor(white: 0.85, alpha: 0.25 + 0.3 * r3).cgColor)
                    g.setLineWidth(1)
                    g.move(to: CGPoint(x: x, y: y * h))
                    g.addLine(to: CGPoint(x: x - len * 0.15, y: y * h + len))
                    g.strokePath()
                case .confetti:
                    let y = (r2 + t * (0.12 + r3 * 0.12)).truncatingRemainder(dividingBy: 1)
                    let x = (r1 + 0.03 * sin(t * 2 + r3 * 9)).truncatingRemainder(dividingBy: 1)
                    g.saveGState()
                    g.translateBy(x: x * w, y: y * h)
                    g.rotate(by: CGFloat(t * (2 + r3 * 4) + r1 * 6))
                    g.setFillColor(palette[n % palette.count].cgColor)
                    g.fill(CGRect(x: -3, y: -1.5, width: 6, height: 3 * (0.4 + abs(sin(t * 5 + r2 * 7)))))
                    g.restoreGState()
                case .hearts, .bubbles:
                    // Rising from the bottom.
                    let y = 1 - (r2 + t * (0.08 + r3 * 0.1)).truncatingRemainder(dividingBy: 1)
                    let x = (r1 + 0.03 * sin(t * 1.3 + r3 * 7)).truncatingRemainder(dividingBy: 1)
                    let d = (kind == .hearts ? 10 : 6) + r3 * 14
                    let rect = CGRect(x: x * w - d / 2, y: y * h - d / 2, width: d, height: d)
                    if kind == .hearts {
                        let p = UIBezierPath()
                        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
                        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + d * 0.3), controlPoint1: CGPoint(x: rect.minX + d * 0.2, y: rect.minY + d * 0.75), controlPoint2: CGPoint(x: rect.minX, y: rect.minY + d * 0.55))
                        p.addArc(withCenter: CGPoint(x: rect.minX + d * 0.25, y: rect.minY + d * 0.3), radius: d * 0.25, startAngle: .pi, endAngle: 0, clockwise: true)
                        p.addArc(withCenter: CGPoint(x: rect.minX + d * 0.75, y: rect.minY + d * 0.3), radius: d * 0.25, startAngle: .pi, endAngle: 0, clockwise: true)
                        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), controlPoint1: CGPoint(x: rect.maxX, y: rect.minY + d * 0.55), controlPoint2: CGPoint(x: rect.maxX - d * 0.2, y: rect.minY + d * 0.75))
                        UIColor(hex: n % 3 == 0 ? 0xFF9AA8 : 0xFF5A6E, alpha: 0.85).setFill()
                        p.fill()
                    } else {
                        g.setStrokeColor(UIColor(white: 1, alpha: 0.7).cgColor)
                        g.setLineWidth(1.2)
                        g.strokeEllipse(in: rect)
                        g.setFillColor(UIColor(white: 1, alpha: 0.12).cgColor)
                        g.fillEllipse(in: rect)
                    }
                case .stars:
                    let twinkle = 0.5 + 0.5 * sin(t * (2 + r3 * 4) + r1 * 20)
                    let d = (3 + r3 * 7) * twinkle
                    let cx = r1 * w, cy = r2 * h
                    g.setFillColor(UIColor(white: 1, alpha: 0.9 * twinkle).cgColor)
                    let p = UIBezierPath()
                    p.move(to: CGPoint(x: cx, y: cy - d))
                    p.addLine(to: CGPoint(x: cx + d * 0.22, y: cy - d * 0.22))
                    p.addLine(to: CGPoint(x: cx + d, y: cy))
                    p.addLine(to: CGPoint(x: cx + d * 0.22, y: cy + d * 0.22))
                    p.addLine(to: CGPoint(x: cx, y: cy + d))
                    p.addLine(to: CGPoint(x: cx - d * 0.22, y: cy + d * 0.22))
                    p.addLine(to: CGPoint(x: cx - d, y: cy))
                    p.addLine(to: CGPoint(x: cx - d * 0.22, y: cy - d * 0.22))
                    p.close()
                    p.fill()
                }
            }
        }
        guard let cg = img.cgImage else { return CIImage.empty() }
        return CIImage(cgImage: cg)
            .transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)
                .concatenating(CGAffineTransform(translationX: canvas.minX, y: canvas.minY)))
            .cropped(to: canvas)
    }
}
