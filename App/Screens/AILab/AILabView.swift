import SwiftUI
import UIKit

struct AILabView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var library = MediaLibrary.shared

    private struct Feature: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        /// Footage category whose still illustrates the card.
        let footage: String
        let open: @MainActor (AppModel) -> Void
    }

    private let hero = Feature(id: "autocut", icon: "wand.and.stars", title: "AutoCut", detail: "Finds the best moments, drops silences and cuts to the beat.", footage: "beat") {
        $0.launchTool(.autoCut, needsMedia: true)
    }

    private let features: [Feature] = [
        Feature(id: "captions", icon: "captions.bubble.fill", title: "Auto captions", detail: "Speech to text, offline", footage: "vlog") { $0.launchTool(.captions, needsMedia: true) },
        Feature(id: "cutout", icon: "person.crop.rectangle.fill", title: "Remove background", detail: "Person cut-out with Vision", footage: "fashion") { $0.openPhotoEditor(tab: 3) },
        Feature(id: "enhance", icon: "sparkles", title: "Auto enhance", detail: "Exposure and colour in one tap", footage: "travel") { $0.openPhotoEditor(tab: 1) },
        Feature(id: "beats", icon: "metronome", title: "Beat sync", detail: "Markers on every beat", footage: "sports") { $0.launchTool(.sheet(.beats), needsMedia: true) },
        Feature(id: "cover", icon: "photo.fill.on.rectangle.fill", title: "Smart cover", detail: "Pick the sharpest frame", footage: "cinematic") { $0.launchTool(.sheet(.cover), needsMedia: true) },
        Feature(id: "voicefx", icon: "waveform", title: "Voice effects", detail: "Clean voice, robot, echo", footage: "night") { $0.openEditorTool("Voice FX") },
    ]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("AI Lab")
                            .font(.display(32, bold: true))
                            .foregroundColor(SX.C.ink)
                        Text("ON DEVICE")
                            .font(.mono(9.5, medium: true))
                            .tracking(1.1)
                            .foregroundColor(SX.C.ok)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(SX.C.ok.opacity(0.14)))
                            .overlay(Capsule().strokeBorder(SX.C.ok.opacity(0.4), lineWidth: 1))
                    }
                    Text("SCYDE's AI tools work offline. Your clips are never uploaded.")
                        .font(.ui(14))
                        .foregroundColor(SX.C.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 12)

                card(hero, height: 230, large: true)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(features) { f in
                        card(f, height: 200, large: false)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                SX.C.bg
                RadialGradient(colors: [SX.C.glowA, .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
        )
        .task { await library.load() }
    }

    private func card(_ f: Feature, height: CGFloat, large: Bool) -> some View {
        Button {
            f.open(app)
        } label: {
            ZStack(alignment: .bottomLeading) {
                FootageStill(category: f.footage, palette: ArtPalette.forTool(f.id))
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.15), location: 0),
                        .init(color: Color.black.opacity(0.0), location: 0.35),
                        .init(color: Color.black.opacity(0.82), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                ArtIcon(symbol: f.icon, palette: ArtPalette.forTool(f.id), size: large ? 50 : 40)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(f.title.loc)
                        .font(large ? .display(24, bold: true) : .ui(15.5, .semibold, fixed: true))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(f.detail.loc)
                        .font(.ui(large ? 13.5 : 11.5))
                        .foregroundColor(Color.white.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if large {
                        HStack(spacing: 6) {
                            Text("Try it")
                                .font(.ui(14, .semibold, fixed: true))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(UIColor(hex: 0x1B1530)))
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(Capsule().fill(SX.C.gold))
                        .padding(.top, 8)
                    }
                }
                .padding(14)
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: SX.R.l, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SX.R.l, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: SX.C.shadow, radius: 16, x: 0, y: 10)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel(f.title)
    }
}

/// A still from SCYDE's footage for a category, over a palette gradient while it loads.
struct FootageStill: View {
    let category: String
    let palette: ArtPalette
    var pick: Int = 0
    @ObservedObject private var library = MediaLibrary.shared
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(UIColor(hex: palette.top)), Color(UIColor(hex: palette.bottom))], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image = image {
                Color.clear
                    .overlay(Image(uiImage: image).resizable().scaledToFill())
                    .transition(.opacity)
            }
        }
        .clipped()
        .task(id: "\(category)-\(library.pack?.videos.count ?? 0)") {
            let videos = library.videos(for: category)
            guard !videos.isEmpty else { return }
            let img = await library.posterImage(for: videos[pick % videos.count])
            withAnimation(.easeOut(duration: 0.25)) { image = img }
        }
    }
}
