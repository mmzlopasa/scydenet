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

    static var playhead: Double? {
        defaults.object(forKey: "scydePlayhead") == nil ? nil : defaults.double(forKey: "scydePlayhead")
    }

    static var selectIndex: Int? {
        defaults.object(forKey: "scydeSelect") == nil ? nil : defaults.integer(forKey: "scydeSelect")
    }

    /// True when any automation flag is present (disables decorative animation for stable screenshots).
    static var isAutomation: Bool { screen != nil || demo }
}
