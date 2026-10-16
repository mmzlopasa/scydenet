import SwiftUI
import UIKit
import SCYDECore

/// Small building blocks shared by the editor's tool sheets.
enum SheetKit {
    static let palette: [UInt32] = [
        0xFFFFFF, 0x000000, 0xFFD76A, 0xE9B84A, 0xFF9F43, 0xFF5A6E,
        0xFF9AA8, 0xFF7AC8, 0xC4BBFF, 0x5A49E6, 0x6EC6FF, 0x2E86DE,
        0x8EF0C8, 0x0C8A60, 0xF5F2FF, 0x1B1530,
    ]

    static let gradients: [(UInt32, UInt32)] = [
        (0x241E63, 0x0D0F14), (0x5A49E6, 0xFFD76A), (0xFF5A6E, 0xFFD76A),
        (0x0C8A60, 0x6EC6FF), (0x1B1530, 0xFF7AC8), (0xF5F2FF, 0xC4BBFF),
    ]
}

struct SXSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: String = "%.2f"
    var scale: Double = 1
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.loc)
                    .font(.ui(14, .medium, fixed: true))
                    .foregroundColor(SX.C.ink)
                Spacer()
                Text(String(format: format, value * scale))
                    .font(.mono(11))
                    .foregroundColor(SX.C.muted)
            }
            Slider(value: $value, in: range, onEditingChanged: { editing in
                if !editing { onCommit() }
            })
            .tint(SX.C.accent)
        }
    }
}

/// Square icon + caption tile used in grids of options.
struct OptionTile: View {
    let icon: String
    let title: String
    let selected: Bool
    var size: CGFloat = 54
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(selected ? SX.C.onAccent : SX.C.ink)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                            .fill(selected ? AnyShapeStyle(SX.accentGradient) : AnyShapeStyle(SX.C.glass))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                            .strokeBorder(selected ? Color.clear : SX.C.line2, lineWidth: 1)
                    )
                Text(title.loc)
                    .font(.ui(11, .medium, fixed: true))
                    .foregroundColor(selected ? SX.C.ink : SX.C.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title.loc)
    }
}

/// Text-only choice pill.
struct WordChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title.loc)
                .font(.ui(13, .semibold, fixed: true))
                .foregroundColor(selected ? SX.C.onAccent : SX.C.ink)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? AnyShapeStyle(SX.accentGradient) : AnyShapeStyle(SX.C.glass))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Color.clear : SX.C.line2, lineWidth: 1)
                )
        }
        .buttonStyle(PressableStyle())
    }
}

struct ColorSwatches: View {
    let selection: UInt32?
    let onPick: (UInt32) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SheetKit.palette, id: \.self) { hex in
                    Button {
                        Haptics.selection()
                        onPick(hex)
                    } label: {
                        Circle()
                            .fill(Color(UIColor(hex: hex)))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(SX.C.line2, lineWidth: 1))
                            .overlay(
                                Circle()
                                    .strokeBorder(SX.C.accent, lineWidth: 2.5)
                                    .padding(-4)
                                    .opacity(selection == hex ? 1 : 0)
                            )
                            .padding(4)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct SubLabel: View {
    let text: String

    var body: some View {
        Text(text.loc.uppercased())
            .font(.mono(10.5, medium: true))
            .foregroundColor(SX.C.muted)
            .padding(.top, 4)
    }
}

/// Header + scrolling body used by most tool sheets.
struct ToolSheetScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    SheetHeader(title: title, subtitle: subtitle, onClose: onClose)
                    content()
                }
                .padding(20)
            }
        }
    }
}

extension TextAnimation {
    var title: String {
        switch self {
        case .none: return "None"
        case .fade: return "Fade"
        case .pop: return "Pop"
        case .slideUp: return "Slide up"
        case .slideDown: return "Slide down"
        case .slideLeft: return "Slide left"
        case .slideRight: return "Slide right"
        case .zoom: return "Zoom"
        case .typewriter: return "Typewriter"
        case .bounce: return "Bounce"
        case .blur: return "Blur"
        case .spin: return "Spin"
        case .drop: return "Drop"
        }
    }
}

extension TextLoop {
    var title: String {
        switch self {
        case .none: return "None"
        case .pulse: return "Pulse"
        case .wiggle: return "Wiggle"
        case .float: return "Float"
        case .blink: return "Blink"
        case .shake: return "Shake"
        case .heartbeat: return "Heartbeat"
        }
    }
}
