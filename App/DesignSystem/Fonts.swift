import SwiftUI

/// Weights available in the bundled Geist UI font.
enum SXWeight {
    case regular, medium, semibold

    var geistName: String {
        switch self {
        case .regular: return "Geist-Regular"
        case .medium: return "Geist-Medium"
        case .semibold: return "Geist-SemiBold"
        }
    }
}

extension Font {
    /// Sora, used for headings and the wordmark.
    static func display(_ size: CGFloat, bold: Bool = false, fixed: Bool = false) -> Font {
        sxMake(bold ? "Sora-Bold" : "Sora-SemiBold", size, fixed)
    }

    /// Geist, used for interface text.
    static func ui(_ size: CGFloat, _ weight: SXWeight = .regular, fixed: Bool = false) -> Font {
        sxMake(weight.geistName, size, fixed)
    }

    /// Geist Mono, used for numbers, labels and metadata.
    static func mono(_ size: CGFloat, medium: Bool = false, fixed: Bool = true) -> Font {
        sxMake(medium ? "GeistMono-Medium" : "GeistMono-Regular", size, fixed)
    }

    /// Doto, the dot-matrix face used for the timecode readout.
    static func dot(_ size: CGFloat) -> Font {
        .custom("Doto-Bold", fixedSize: size)
    }

    private static func sxMake(_ name: String, _ size: CGFloat, _ fixed: Bool) -> Font {
        fixed ? .custom(name, fixedSize: size) : .custom(name, size: size)
    }
}
