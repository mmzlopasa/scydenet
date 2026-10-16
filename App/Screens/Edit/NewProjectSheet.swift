import SwiftUI
import SCYDECore

struct NewProjectSheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var aspect: CanvasAspect = .portrait9x16

    private let formats: [CanvasAspect] = [.portrait9x16, .landscape16x9, .square1x1, .portrait4x5]

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New video")
                            .font(.display(26))
                            .foregroundColor(SX.C.ink)
                        Text("Pick a format. You can import clips right after.")
                            .font(.ui(14))
                            .foregroundColor(SX.C.body)
                    }
                    Spacer()
                    GlassIconButton(systemName: "xmark", label: "Close", size: 36) { dismiss() }
                }
                SectionLabel(index: "01", title: "Format")
                HStack(spacing: 10) {
                    ForEach(formats, id: \.self) { option in
                        FormatCard(aspect: option, selected: option == aspect) {
                            Haptics.selection()
                            withAnimation(SX.spring) { aspect = option }
                        }
                    }
                }
                Spacer(minLength: 0)
                Button {
                    Haptics.medium()
                    app.defaultAspect = aspect
                    dismiss()
                    app.createProject(aspect: aspect)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Create project")
                        Text(aspect.label)
                            .font(.mono(13, medium: true))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(SX.C.onAccent.opacity(0.12)))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 16)
        }
        .onAppear { aspect = app.defaultAspect }
    }
}

struct FormatCard: View {
    let aspect: CanvasAspect
    let selected: Bool
    let action: () -> Void

    private var caption: String {
        switch aspect {
        case .portrait9x16: return "Vertical"
        case .landscape16x9: return "Wide"
        case .square1x1: return "Square"
        case .portrait4x5: return "Portrait"
        case .cinema21x9: return "Cinema"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    let r = CGFloat(aspect.ratio)
                    let box: CGFloat = 40
                    let w = r < 1 ? box * r : box
                    let h = r < 1 ? box : box / r
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(selected ? SX.C.accent.opacity(0.22) : SX.C.glass)
                        .frame(width: w, height: h)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(selected ? SX.C.accent : SX.C.line2, lineWidth: 1.5)
                        .frame(width: w, height: h)
                }
                .frame(height: 44)
                VStack(spacing: 2) {
                    Text(aspect.label)
                        .font(.mono(13, medium: true))
                        .foregroundColor(SX.C.ink)
                    Text(caption)
                        .font(.ui(11, fixed: true))
                        .foregroundColor(SX.C.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .sxCard(radius: SX.R.m)
            .overlay(
                RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                    .strokeBorder(selected ? SX.C.accent : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: selected ? SX.C.accent.opacity(0.28) : .clear, radius: 16, x: 0, y: 8)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .accessibilityLabel("\(caption) \(aspect.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
