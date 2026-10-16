import SwiftUI
import SCYDECore

struct ClipBlock: View {
    let clip: Clip
    let role: Track.Role
    let width: CGFloat
    let height: CGFloat
    let selected: Bool
    @ObservedObject var model: EditorViewModel
    @State private var dragOrigin: Double?

    private var colors: (Color, Color) {
        switch clip.kind {
        case .video: return (SX.C.clipVideo, SX.C.clipVideo2)
        case .photo: return (SX.C.clipPhoto, SX.C.clipPhoto2)
        case .audio: return (SX.C.clipAudio, SX.C.clipAudio2)
        case .text: return (SX.C.clipText, SX.C.clipText2)
        }
    }

    private var hasFilmstrip: Bool {
        clip.assetID != nil && (clip.kind == .video || clip.kind == .photo)
    }

    private var foreground: Color {
        if hasFilmstrip { return .white }
        switch clip.kind {
        case .audio: return SX.C.onClipDark
        case .text: return SX.C.onClip
        case .video, .photo: return SX.C.onClip
        }
    }

    private var icon: String {
        switch clip.kind {
        case .video: return "video.fill"
        case .photo: return "photo.fill"
        case .audio: return "waveform"
        case .text: return "textformat"
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        let blockWidth = max(width - 2, 4)
        ZStack(alignment: .topLeading) {
            if let assetID = clip.assetID, hasFilmstrip {
                Filmstrip(clip: clip, assetID: assetID, width: blockWidth, height: height)
                LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0)], startPoint: .top, endPoint: .center)
                LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
            } else {
                shape.fill(LinearGradient(colors: [colors.0, colors.1], startPoint: .top, endPoint: .bottom))
                LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0)], startPoint: .top, endPoint: .center)
                    .clipShape(shape)
            }
            if clip.kind == .audio {
                if let assetID = clip.assetID {
                    WaveformView(clip: clip, assetID: assetID)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 5)
                } else {
                    WaveDecoration()
                        .fill(SX.C.onClipDark.opacity(0.18))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                }
            }
            if blockWidth > 34 {
                label
            }
        }
        .frame(width: blockWidth, height: height)
        .overlay(alignment: .bottomLeading) {
            if let frames = clip.keyframes, !frames.isEmpty {
                ZStack(alignment: .bottomLeading) {
                    ForEach(frames.indices, id: \.self) { i in
                        Rectangle()
                            .fill(SX.C.gold)
                            .frame(width: 7, height: 7)
                            .rotationEffect(.degrees(45))
                            .overlay(Rectangle().stroke(Color.black.opacity(0.4), lineWidth: 1).rotationEffect(.degrees(45)))
                            .offset(x: CGFloat(frames[i].time / max(clip.duration, 0.01)) * blockWidth - 3.5, y: -3)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if clip.transitionIn != nil || clip.chromaKey != nil || (clip.fadeIn ?? 0) > 0 || (clip.fadeOut ?? 0) > 0 {
                HStack(spacing: 3) {
                    if clip.chromaKey != nil { Image(systemName: "drop.halffull") }
                    if (clip.fadeIn ?? 0) > 0 || (clip.fadeOut ?? 0) > 0 { Image(systemName: "waveform.path.ecg") }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(foreground)
                .padding(5)
            }
        }
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(selected ? SX.C.selection : Color.white.opacity(0.14), lineWidth: selected ? 2 : 1)
        )
        .overlay(handles, alignment: .center)
        .shadow(color: selected ? SX.C.accent.opacity(0.55) : Color.black.opacity(0.18), radius: selected ? 12 : 3, x: 0, y: selected ? 0 : 2)
        .zIndex(selected ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture { model.select(clip.id) }
        .gesture(moveGesture, including: selected ? .all : .subviews)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(clip.name), \(Timecode.duration(clip.duration))")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .bold))
                Text(clip.name)
                    .font(.ui(11, .semibold, fixed: true))
                    .lineLimit(1)
                if clip.volume == 0 {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            Spacer(minLength: 0)
            if height >= 40 {
                Text(Timecode.duration(clip.duration))
                    .font(.mono(9.5, medium: true))
                    .opacity(0.75)
            }
        }
        .foregroundColor(foreground)
        .padding(.horizontal, selected ? 22 : 8)
        .padding(.vertical, height >= 40 ? 7 : 0)
        .frame(maxHeight: .infinity, alignment: height >= 40 ? .topLeading : .leading)
    }

    @ViewBuilder
    private var handles: some View {
        if selected {
            HStack(spacing: 0) {
                TrimHandle(edge: .leading)
                    .gesture(trimGesture(.leading))
                Spacer(minLength: 0)
                TrimHandle(edge: .trailing)
                    .gesture(trimGesture(.trailing))
            }
            .padding(.horizontal, -2)
            .transition(.opacity)
        }
    }

    private func trimGesture(_ edge: TrimEdge) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = edge == .leading ? clip.start : clip.end
                    model.beginEdit()
                }
                let origin = dragOrigin ?? 0
                model.updateTrim(clip.id, edge: edge, to: origin + Double(value.translation.width / model.pxPerSecond))
            }
            .onEnded { _ in
                dragOrigin = nil
                model.endEdit("Trim")
            }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = clip.start
                    model.beginEdit()
                }
                let origin = dragOrigin ?? 0
                model.updateMove(clip.id, to: origin + Double(value.translation.width / model.pxPerSecond))
            }
            .onEnded { _ in
                dragOrigin = nil
                model.endEdit("Move")
            }
    }
}

private struct TrimHandle: View {
    let edge: TrimEdge

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(SX.C.selection)
                .frame(width: 12)
            Image(systemName: edge == .leading ? "chevron.compact.left" : "chevron.compact.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(SX.C.bg)
        }
        .frame(width: 22)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel(edge == .leading ? "Trim start" : "Trim end")
    }
}

/// Decorative waveform shape for audio clips (real waveforms arrive in Phase 9).
private struct WaveDecoration: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bars = max(Int(rect.width / 4), 1)
        for i in 0..<bars {
            let x = rect.minX + CGFloat(i) * 4
            let phase = Double(i) * 0.55
            let amp = 0.35 + 0.65 * abs(sin(phase) * cos(phase * 0.37))
            let h = rect.height * CGFloat(amp)
            p.addRoundedRect(
                in: CGRect(x: x, y: rect.midY - h / 2, width: 2, height: h),
                cornerSize: CGSize(width: 1, height: 1)
            )
        }
        return p
    }
}


/// Real audio levels for the visible source range of a clip.
private struct WaveformView: View {
    let clip: Clip
    let assetID: String
    @State private var levels: [Float] = []

    var body: some View {
        Canvas { ctx, size in
            guard !levels.isEmpty else { return }
            let bars = max(Int(size.width / 3), 1)
            let perSecond = 40.0
            let span = clip.duration * clip.speed
            for j in 0..<bars {
                let t = clip.sourceIn + span * Double(j) / Double(bars)
                let index = min(levels.count - 1, max(0, Int(t * perSecond)))
                let h = max(2, CGFloat(levels[index]) * size.height)
                let rect = CGRect(x: CGFloat(j) * 3, y: (size.height - h) / 2, width: 2, height: h)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(SX.C.onClipDark.opacity(0.35)))
            }
        }
        .task(id: assetID) {
            levels = await WaveformCache.shared.levels(for: assetID)
        }
    }
}
