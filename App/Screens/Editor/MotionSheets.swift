import SwiftUI
import SCYDECore

// MARK: - Transform & keyframes

struct TransformSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var t = ClipTransform()

    private var clip: Clip? { model.selectedClip }

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SheetHeader(title: "Transform", subtitle: "Or drag, pinch and rotate on the preview.") { dismiss() }
                    if let c = clip {
                        slider("Position X", value: $t.x, range: -1...1, id: c.id)
                        slider("Position Y", value: $t.y, range: -1...1, id: c.id)
                        slider("Scale", value: $t.scale, range: 0.2...3, id: c.id)
                        slider("Rotation", value: $t.rotation, range: -180...180, id: c.id)
                        slider("Opacity", value: $t.opacity, range: 0...1, id: c.id)

                        HStack(spacing: 10) {
                            if model.keyframeAtPlayhead(c) {
                                Button {
                                    model.removeKeyframe(c.id)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "diamond.slash")
                                        Text("Remove keyframe")
                                    }
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            } else {
                                Button {
                                    model.addKeyframe(c.id)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.diamond")
                                        Text("Add keyframe")
                                    }
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                            Button {
                                model.resetTransform(c.id)
                                t = ClipTransform()
                            } label: {
                                Text("Reset")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        Text(keyframeHint(c))
                            .font(.ui(12.5))
                            .foregroundColor(SX.C.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Select a video or photo first.")
                            .font(.ui(14))
                            .foregroundColor(SX.C.muted)
                    }
                }
                .padding(20)
            }
        }
        .onAppear { sync() }
        .onChange(of: model.playhead) { _ in sync() }
    }

    private func sync() {
        if let c = clip { t = model.transformAtPlayhead(c) }
    }

    private func keyframeHint(_ c: Clip) -> String {
        let count = c.keyframes?.count ?? 0
        if count == 0 { return "Add a keyframe, move the playhead, change the values and add another: SCYDE animates between them.".loc }
        return (count == 1 ? "1 keyframe. Changes at the playhead create or update a keyframe." : "%d keyframes. Changes at the playhead create or update a keyframe.".locf(count)).loc
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.loc)
                    .font(.ui(14, .medium, fixed: true))
                    .foregroundColor(SX.C.ink)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.mono(11))
                    .foregroundColor(SX.C.muted)
            }
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    value.wrappedValue = newValue
                    model.liveTransform(id, t)
                }
            ), in: range, onEditingChanged: { editing in
                if !editing { model.applyTransform(id, t) }
            })
            .tint(SX.C.accent)
        }
    }
}

// MARK: - Transitions

struct TransitionSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var kind: TransitionKind?
    @State private var duration: Double = 0.6
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SheetHeader(title: "Transition", subtitle: "Plays across the cut into this clip.") { dismiss() }
                    LazyVGrid(columns: columns, spacing: 10) {
                        option(nil, icon: "nosign", title: "None")
                        ForEach(TransitionKind.allCases, id: \.self) { k in
                            option(k, icon: Self.icon(k), title: k.title)
                        }
                    }
                    if kind != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Duration")
                                    .font(.ui(14, .medium, fixed: true))
                                    .foregroundColor(SX.C.ink)
                                Spacer()
                                Text(String(format: "%.1fs", duration))
                                    .font(.mono(11))
                                    .foregroundColor(SX.C.muted)
                            }
                            Slider(value: $duration, in: 0.2...2, onEditingChanged: { editing in
                                if !editing { apply() }
                            })
                            .tint(SX.C.accent)
                        }
                    }
                    Button {
                        model.applyTransitionToAll(kind.map { Transition(kind: $0, duration: duration) })
                    } label: {
                        Text("Apply to every cut")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(20)
            }
        }
        .onAppear {
            kind = model.selectedClip?.transitionIn?.kind
            duration = model.selectedClip?.transitionIn?.duration ?? 0.6
        }
    }

    static func icon(_ k: TransitionKind) -> String {
        switch k {
        case .fade: return "circle.lefthalf.filled"
        case .flash: return "sun.max"
        case .zoom: return "plus.magnifyingglass"
        case .blur: return "drop"
        case .slide: return "arrow.left.and.right"
        case .spin: return "arrow.triangle.2.circlepath"
        }
    }

    private func apply() {
        guard let id = model.selection else { return }
        model.setTransition(id, kind.map { Transition(kind: $0, duration: duration) })
    }

    private func option(_ k: TransitionKind?, icon: String, title: String) -> some View {
        let selected = kind == k
        return Button {
            Haptics.selection()
            kind = k
            apply()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(selected ? SX.C.onAccent : SX.C.ink)
                    .frame(width: 54, height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                            .fill(selected ? AnyShapeStyle(SX.accentGradient) : AnyShapeStyle(SX.C.glass))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                            .strokeBorder(selected ? Color.clear : SX.C.line2, lineWidth: 1)
                    )
                Text(title.loc)
                    .font(.ui(11.5, .medium, fixed: true))
                    .foregroundColor(SX.C.body)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Volume & fades

struct VolumeSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var volume: Double = 1
    @State private var fadeIn: Double = 0
    @State private var fadeOut: Double = 0

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: "Volume", subtitle: "Level and fades for this clip.") { dismiss() }
                Text("\(Int((volume * 100).rounded()))%")
                    .font(.dot(36))
                    .foregroundColor(SX.C.ink)
                    .frame(maxWidth: .infinity)
                row("Volume", value: $volume, range: 0...2, format: "%.0f%%", scale: 100)
                row("Fade in", value: $fadeIn, range: 0...3, format: "%.1fs", scale: 1)
                row("Fade out", value: $fadeOut, range: 0...3, format: "%.1fs", scale: 1)
                Button {
                    volume = volume == 0 ? 1 : 0
                    commit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: volume == 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        Text(volume == 0 ? "Unmute" : "Mute")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onAppear {
            let c = model.selectedClip
            volume = c?.volume ?? 1
            fadeIn = c?.fadeIn ?? 0
            fadeOut = c?.fadeOut ?? 0
        }
    }

    private func commit() {
        guard let id = model.selection else { return }
        model.setAudio(id, volume: volume, fadeIn: fadeIn, fadeOut: fadeOut)
    }

    private func row(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, scale: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.loc)
                    .font(.ui(14, .medium, fixed: true))
                    .foregroundColor(SX.C.ink)
                Spacer()
                Text(String(format: format, value.wrappedValue * scale))
                    .font(.mono(11))
                    .foregroundColor(SX.C.muted)
            }
            Slider(value: value, in: range, onEditingChanged: { editing in
                if !editing { commit() }
            })
            .tint(SX.C.accent)
        }
    }
}

// MARK: - Chroma key

struct ChromaSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = false
    @State private var hue: Double = 120
    @State private var tolerance: Double = 0.22

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: "Chroma key", subtitle: "Remove a green or blue screen. Best on overlay clips.") { dismiss() }
                Toggle("Remove colour", isOn: Binding(get: { enabled }, set: { enabled = $0; commit() }))
                    .font(.ui(16, .medium))
                    .foregroundColor(SX.C.ink)
                    .tint(SX.C.accent)
                    .padding(16)
                    .sxCard(radius: SX.R.l)
                if enabled {
                    HStack(spacing: 10) {
                        swatch("Green", hue: 120, color: Color(red: 0.1, green: 0.8, blue: 0.3))
                        swatch("Blue", hue: 220, color: Color(red: 0.15, green: 0.4, blue: 0.95))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Strength")
                                .font(.ui(14, .medium, fixed: true))
                                .foregroundColor(SX.C.ink)
                            Spacer()
                            Text(String(format: "%.0f%%", tolerance * 200))
                                .font(.mono(11))
                                .foregroundColor(SX.C.muted)
                        }
                        Slider(value: $tolerance, in: 0.05...0.5, onEditingChanged: { editing in
                            if !editing { commit() }
                        })
                        .tint(SX.C.accent)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onAppear {
            let key = model.selectedClip?.chromaKey
            enabled = key != nil
            hue = key?.hue ?? 120
            tolerance = key?.tolerance ?? 0.22
        }
    }

    private func commit() {
        guard let id = model.selection else { return }
        model.setChroma(id, enabled ? ChromaKey(hue: hue, tolerance: tolerance) : nil)
    }

    private func swatch(_ title: String, hue value: Double, color: Color) -> some View {
        Button {
            hue = value
            commit()
        } label: {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 18, height: 18)
                Text(title.loc)
                    .font(.ui(15, .semibold, fixed: true))
                    .foregroundColor(SX.C.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: SX.R.m, style: .continuous).fill(SX.C.glass))
            .overlay(
                RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                    .strokeBorder(abs(hue - value) < 1 ? SX.C.accent : SX.C.line2, lineWidth: abs(hue - value) < 1 ? 2 : 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}
