import PhotosUI
import SwiftUI
import SCYDECore

/// Timeline with a fixed centre playhead; content moves underneath it.
/// x(t) = centre + (t - playhead) * pxPerSecond
struct TimelinePanel: View {
    @ObservedObject var model: EditorViewModel
    @State private var panStart: Double?
    @State private var zoomStart: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let center = width / 2
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.clearSelection() }

                VStack(alignment: .leading, spacing: 8) {
                    TimeRuler(playhead: model.playhead, pps: model.pxPerSecond, center: center, markers: model.project.markers ?? [])
                        .frame(height: 26)
                    ForEach(model.visibleTracks) { track in
                        TrackLane(track: track, model: model, center: center, width: width)
                    }
                }
                .padding(.top, 6)

                PlayheadMarker()
                    .frame(width: 14)
                    .frame(maxHeight: .infinity)
                    .offset(x: center - 7)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(pan)
            .simultaneousGesture(zoom)
        }
        .background(
            SX.C.surface
                .overlay(Rectangle().fill(SX.C.line).frame(height: 1), alignment: .top)
        )
        .clipped()
    }

    private var pan: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if panStart == nil {
                    panStart = model.playhead
                    model.beginScrub()
                }
                let start = panStart ?? model.playhead
                model.scrub(to: start - Double(value.translation.width / model.pxPerSecond))
            }
            .onEnded { value in
                let start = panStart ?? model.playhead
                panStart = nil
                model.glide(to: start - Double(value.predictedEndTranslation.width / model.pxPerSecond))
            }
    }

    private var zoom: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if zoomStart == nil { zoomStart = model.pxPerSecond }
                model.zoom(to: (zoomStart ?? model.pxPerSecond) * scale)
            }
            .onEnded { _ in zoomStart = nil }
    }
}

// MARK: - Ruler

struct TimeRuler: View {
    let playhead: Double
    let pps: CGFloat
    let center: CGFloat
    var markers: [Double] = []

    static func step(for pps: CGFloat) -> Double {
        for s in [0.5, 1, 2, 5, 10, 15, 30, 60, 120] where CGFloat(s) * pps >= 64 {
            return s
        }
        return 300
    }

    var body: some View {
        Canvas { ctx, size in
            let step = TimeRuler.step(for: pps)
            let minor = step / 4
            let t0 = playhead - Double(center / pps)
            let t1 = playhead + Double((size.width - center) / pps)
            var t = max(0, (t0 / minor).rounded(.down) * minor)
            var guardCount = 0
            while t <= t1 && guardCount < 400 {
                let x = center + CGFloat(t - playhead) * pps
                let ratio = t / step
                let isMajor = abs(ratio - ratio.rounded()) < 0.001
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height - (isMajor ? 9 : 4)))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(isMajor ? SX.C.line2 : SX.C.line), lineWidth: 1)
                if isMajor {
                    let label = step < 1 ? String(format: "%.1fs", t) : Timecode.short(t)
                    ctx.draw(
                        Text(label).font(.mono(9.5)).foregroundColor(SX.C.muted),
                        at: CGPoint(x: x, y: 7),
                        anchor: .center
                    )
                }
                t += minor
                guardCount += 1
            }
            for m in markers where m >= t0 - 1 && m <= t1 + 1 {
                let x = center + CGFloat(m - playhead) * pps
                let dot = Path(ellipseIn: CGRect(x: x - 3, y: size.height - 7, width: 6, height: 6))
                ctx.fill(dot, with: .color(SX.C.gold))
            }
        }
    }
}

// MARK: - Playhead

private struct PlayheadMarker: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(SX.C.accent)
                .frame(width: 12, height: 16)
                .overlay(
                    Rectangle()
                        .fill(SX.C.onAccent.opacity(0.55))
                        .frame(width: 2, height: 7)
                )
            Rectangle()
                .fill(SX.C.accent)
                .frame(width: 2)
        }
        .shadow(color: SX.C.accent.opacity(0.7), radius: 6)
        .padding(.top, 2)
    }
}

// MARK: - Lanes

private struct TrackLane: View {
    let track: Track
    @ObservedObject var model: EditorViewModel
    let center: CGFloat
    let width: CGFloat

    var body: some View {
        let height = track.role.laneHeight
        let pps = model.pxPerSecond
        let originX = center - CGFloat(model.playhead) * pps
        ZStack(alignment: .topLeading) {
            // Lane background from timeline start to the right edge.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SX.C.lane)
                .frame(width: max(width - originX + 40, 0), height: height)
                .offset(x: originX)

            if track.role == .main && track.clips.isEmpty {
                AddMediaTile(model: model, height: height)
                    .offset(x: center + 10)
            }

            ForEach(track.clips) { clip in
                let x = center + CGFloat(clip.start - model.playhead) * pps
                let w = CGFloat(clip.duration) * pps
                if x + w > -60 && x < width + 60 {
                    ClipBlock(
                        clip: clip,
                        role: track.role,
                        width: w,
                        height: height,
                        selected: model.selection == clip.id,
                        model: model
                    )
                    .offset(x: x)
                }
            }

            if track.role == .main && track.clips.count > 1 {
                ForEach(1..<track.clips.count, id: \.self) { i in
                    let c = track.clips[i]
                    let prev = track.clips[i - 1]
                    let x = center + CGFloat(c.start - model.playhead) * pps
                    if abs(c.start - prev.end) < 0.05 && x > -20 && x < width + 20 && (c.kind == .video || c.kind == .photo) {
                        Button {
                            Haptics.selection()
                            model.selection = c.id
                            model.activeSheet = .transition
                        } label: {
                            Image(systemName: c.transitionIn == nil ? "plus" : "square.split.diagonal.2x2.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(c.transitionIn == nil ? SX.C.ink : SX.C.onAccent)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(c.transitionIn == nil ? AnyShapeStyle(SX.C.surface3) : AnyShapeStyle(SX.accentGradient))
                                )
                                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(SX.C.line2, lineWidth: 1))
                        }
                        .buttonStyle(PressableStyle())
                        .offset(x: x - 10, y: height / 2 - 10)
                        .accessibilityLabel("Transition")
                    }
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

private struct AddMediaTile: View {
    @ObservedObject var model: EditorViewModel
    let height: CGFloat

    var body: some View {
        PhotosPicker(
            selection: $model.pickerItems,
            maxSelectionCount: 20,
            matching: .any(of: [.videos, .images])
        ) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("Add media")
                    .font(.ui(13, .semibold, fixed: true))
            }
            .foregroundColor(SX.C.accent)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SX.C.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(SX.C.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        }
        .buttonStyle(PressableStyle())
    }
}
