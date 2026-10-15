import PhotosUI
import SwiftUI

/// Bottom tool row. Only tools that work are shown; new ones appear as phases land.
struct ToolDock: View {
    @ObservedObject var model: EditorViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                PhotosPicker(
                    selection: $model.pickerItems,
                    maxSelectionCount: 20,
                    matching: .any(of: [.videos, .images])
                ) {
                    ToolItem(icon: "plus", title: "Import", enabled: true, prominent: true)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Import media")

                divider

                ToolButton(icon: "scissors", title: "Split", enabled: model.canSplit) {
                    model.split()
                }
                ToolButton(icon: "plus.square.on.square", title: "Duplicate", enabled: model.selection != nil) {
                    model.duplicateSelected()
                }
                ToolButton(
                    icon: model.selectedIsMuted ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    title: model.selectedIsMuted ? "Unmute" : "Mute",
                    enabled: model.canMute
                ) {
                    model.toggleMute()
                }
                ToolButton(icon: "trash", title: "Delete", enabled: model.selection != nil, destructive: true) {
                    model.deleteSelected()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(
            SX.C.surface
                .overlay(Rectangle().fill(SX.C.line).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(SX.C.line2)
            .frame(width: 1, height: 34)
            .padding(.horizontal, 6)
    }
}

private struct ToolButton: View {
    let icon: String
    let title: String
    let enabled: Bool
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolItem(icon: icon, title: title, enabled: enabled, destructive: destructive)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

private struct ToolItem: View {
    let icon: String
    let title: String
    let enabled: Bool
    var prominent: Bool = false
    var destructive: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if prominent {
                    RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                        .fill(SX.accentGradient)
                        .shadow(color: SX.C.accent.opacity(0.35), radius: 10, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                        .fill(SX.C.glass)
                    RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                        .strokeBorder(SX.C.line2, lineWidth: 1)
                }
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(prominent ? SX.C.onAccent : (destructive ? SX.C.err : SX.C.ink))
            }
            .frame(width: 46, height: 46)
            Text(title)
                .font(.ui(11, .medium, fixed: true))
                .foregroundColor(SX.C.body)
                .lineLimit(1)
        }
        .frame(width: 64)
        .opacity(enabled ? 1 : 0.35)
        .animation(SX.spring, value: enabled)
    }
}
