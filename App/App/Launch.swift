import Foundation

/// Launch arguments used by CI to capture screenshots, e.g.
/// `-scydeDemo YES -scydeTheme dark -scydeScreen editor -scydePlayhead 3.2 -scydeSelect 1`.
/// Values arrive through the UserDefaults argument domain and are never persisted.
enum Launch {
    private static var defaults: UserDefaults { .standard }

    /// Load fixture projects instead of the user's library. Never set in normal use.
    static var demo: Bool { defaults.bool(forKey: "scydeDemo") }
    static var theme: String? { defaults.string(forKey: "scydeTheme") }
    static var screen: String? { defaults.string(forKey: "scydeScreen") }
    static var tab: String? { defaults.string(forKey: "scydeTab") }

    static var playhead: Double? {
        defaults.object(forKey: "scydePlayhead") == nil ? nil : defaults.double(forKey: "scydePlayhead")
    }

    static var selectIndex: Int? {
        defaults.object(forKey: "scydeSelect") == nil ? nil : defaults.integer(forKey: "scydeSelect")
    }

    /// Generate real sample media (video + photo) and open it in the editor. CI only.
    static var sampleMedia: Bool { defaults.bool(forKey: "scydeSampleMedia") }

    /// Start playback as soon as the preview is ready. CI only.
    static var autoplay: Bool { defaults.bool(forKey: "scydeAutoplay") }

    /// Start an export as soon as the export sheet opens. CI only.
    static var autoExport: Bool { defaults.bool(forKey: "scydeAutoExport") }

    /// Open the look sheet on the Adjust tab. CI only.
    static var autoEnhance: Bool { defaults.bool(forKey: "scydeAutoEnhance") }

    /// Open a tool sheet in the editor: speed, text, look, voiceFX, cover. CI only.
    static var sheet: String? { defaults.string(forKey: "scydeSheet") }

    /// True when any automation flag is present (disables decorative animation for stable screenshots).
    static var isAutomation: Bool { screen != nil || tab != nil || demo || sampleMedia }
}
