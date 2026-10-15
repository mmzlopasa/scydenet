import SwiftUI
import UIKit

// MARK: - Card

struct SXCard: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(
                ZStack {
                    shape.fill(SX.C.cardBase)
                    shape.fill(SX.cardGradient)
                }
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [SX.C.highlight, SX.C.edge.opacity(0.35)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
            .shadow(color: SX.C.shadow, radius: 26, x: 0, y: 18)
    }
}

extension View {
    func sxCard(radius: CGFloat = SX.R.l) -> some View {
        modifier(SXCard(radius: radius))
    }
}

// MARK: - Buttons

/// Full-width pill CTA with the accent gradient, inset highlight and glow.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, height: height)
    }

    private struct PrimaryButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let height: CGFloat
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.ui(16, .semibold))
                .foregroundColor(SX.C.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Capsule().fill(SX.accentGradient))
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.0)], startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
                )
                .shadow(color: SX.C.accent.opacity(isEnabled ? 0.45 : 0), radius: 22, x: 0, y: 12)
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(SX.spring, value: configuration.isPressed)
        }
    }
}

/// Small accent pill (Export button).
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(14, .semibold, fixed: true))
            .foregroundColor(SX.C.onAccent)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Capsule().fill(SX.accentGradient))
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.0)], startPoint: .top, endPoint: .center),
                    lineWidth: 1
                )
            )
            .shadow(color: SX.C.accent.opacity(0.4), radius: 14, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(SX.spring, value: configuration.isPressed)
    }
}

/// Generic press feedback for custom buttons.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(SX.spring, value: configuration.isPressed)
    }
}

/// Round glass icon, used directly or as a Menu label.
struct GlassIcon: View {
    let systemName: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundColor(SX.C.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(SX.C.glass))
            .overlay(Circle().strokeBorder(SX.C.line2, lineWidth: 1))
            .contentShape(Circle())
    }
}

struct GlassIconButton: View {
    let systemName: String
    let label: String
    var size: CGFloat = 40
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassIcon(systemName: systemName, size: size)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}

// MARK: - Typography helpers

/// `scyde.` wordmark: Sora Bold with an accent dot.
struct Wordmark: View {
    var size: CGFloat = 26

    var body: some View {
        (Text("scyde").foregroundColor(SX.C.ink) + Text(".").foregroundColor(SX.C.accent))
            .font(.display(size, bold: true, fixed: true))
            .accessibilityLabel("SCYDE")
    }
}

/// Numbered section label: `01 · FORMAT ────`.
struct SectionLabel: View {
    let index: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(index)
                .font(.mono(11, medium: true))
                .foregroundColor(SX.C.accent)
            Text("·")
                .font(.mono(11))
                .foregroundColor(SX.C.muted)
            Text(title.uppercased())
                .font(.mono(11, medium: true))
                .tracking(1.4)
                .foregroundColor(SX.C.muted)
                .fixedSize()
            Rectangle()
                .fill(SX.C.line)
                .frame(height: 1)
            if let trailing = trailing {
                Text(trailing)
                    .font(.mono(11))
                    .foregroundColor(SX.C.muted)
                    .fixedSize()
            }
        }
    }
}

/// Eyebrow with the 2 px accent bar used across scyhost.com.
struct Eyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2)
                .fill(SX.C.accent)
                .frame(width: 2, height: 14)
            Text(text)
                .font(.ui(13, .medium))
                .foregroundColor(SX.C.body)
        }
    }
}

// MARK: - Chips

struct ChipRow<Item: Hashable>: View {
    let items: [Item]
    let selection: Item
    let title: (Item) -> String
    var caption: ((Item) -> String?)? = nil
    let onSelect: (Item) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let selected = item == selection
                Button {
                    Haptics.selection()
                    onSelect(item)
                } label: {
                    VStack(spacing: 3) {
                        Text(title(item))
                            .font(.ui(14, .semibold, fixed: true))
                        if let caption = caption, let text = caption(item) {
                            Text(text)
                                .font(.mono(9))
                                .opacity(0.75)
                        }
                    }
                    .foregroundColor(selected ? SX.C.onAccent : SX.C.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: caption == nil ? 42 : 52)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: SX.R.m, style: .continuous).fill(SX.C.glass)
                            if selected {
                                RoundedRectangle(cornerRadius: SX.R.m, style: .continuous).fill(SX.accentGradient)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                            .strokeBorder(selected ? Color.clear : SX.C.line2, lineWidth: 1)
                    )
                    .shadow(color: selected ? SX.C.accent.opacity(0.35) : .clear, radius: 12, x: 0, y: 6)
                }
                .buttonStyle(PressableStyle(scale: 0.96))
                .animation(SX.spring, value: selected)
            }
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.ui(13, .medium, fixed: true))
            .foregroundColor(SX.C.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(SX.C.surface3))
            .overlay(Capsule().strokeBorder(SX.C.line2, lineWidth: 1))
            .shadow(color: SX.C.shadow, radius: 18, x: 0, y: 10)
    }
}

// MARK: - Haptics

@MainActor
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
