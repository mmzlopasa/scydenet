import SwiftUI
import UIKit
import SCYDECore

struct ProjectCard: View {
    let project: Project
    let action: () -> Void

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ProjectThumb(project: project)
                    .frame(height: 176)
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.name)
                        .font(.ui(15, .semibold))
                        .foregroundColor(SX.C.ink)
                        .lineLimit(1)
                    Text("\(Timecode.short(project.duration)) · \(project.aspect.label) · \(Self.relative.localizedString(for: project.modifiedAt, relativeTo: Date()))")
                        .font(.mono(10.5))
                        .foregroundColor(SX.C.muted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
            .sxCard(radius: SX.R.l)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel("\(project.name), \(Timecode.short(project.duration))")
    }
}

/// Aspect-shaped preview with a stable colour pair and a mini timeline of the main track.
struct ProjectThumb: View {
    let project: Project

    private static let palettes: [(UInt32, UInt32)] = [
        (0xC4BBFF, 0x5A49E6),
        (0xFFE7A0, 0xE9B84A),
        (0x8EF0C8, 0x2B6F7A),
        (0xFFB4C0, 0x7A3A6A),
        (0xA9C8FF, 0x3D4FB8),
    ]

    private var palette: (UInt32, UInt32) {
        let seed = Int(project.id.uuid.0) + Int(project.id.uuid.15)
        return Self.palettes[seed % Self.palettes.count]
    }

    var body: some View {
        GeometryReader { geo in
            let r = CGFloat(project.aspect.ratio)
            let maxW = max(geo.size.width - 28, 10)
            let maxH = max(geo.size.height - 24, 10)
            let w = min(maxW, maxH * r)
            let h = w / r
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [Color(UIColor(hex: palette.0)), Color(UIColor(hex: palette.1))],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color.white.opacity(0.35), Color.clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: max(w, h)
                )
                MiniTimeline(project: project)
                    .frame(height: 8)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)
            .position(x: geo.size.width / 2, y: geo.size.height / 2 + 4)
        }
        .background(
            RoundedRectangle(cornerRadius: SX.R.m, style: .continuous)
                .fill(SX.C.lane)
                .padding(6)
        )
    }
}

private struct MiniTimeline: View {
    let project: Project

    var body: some View {
        Canvas { ctx, size in
            let total = max(project.duration, 0.001)
            let clips = project.tracks.first(where: { $0.role == .main })?.clips ?? []
            if clips.isEmpty {
                let path = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2)
                ctx.fill(path, with: .color(Color.white.opacity(0.25)))
                return
            }
            for clip in clips {
                let x = CGFloat(clip.start / total) * size.width
                let w = max(CGFloat(clip.duration / total) * size.width - 1.5, 1)
                let rect = CGRect(x: x, y: 0, width: w, height: size.height)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color.white.opacity(0.75)))
            }
        }
    }
}
