import AVFoundation
import SwiftUI
import UIKit
import SCYDECore

/// Music from SCYDE's library plus synthesised sound effects.
struct MusicSheet: View {
    @ObservedObject var model: EditorViewModel
    @ObservedObject private var library = MediaLibrary.shared
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var genre: String?
    @State private var playing: String?
    @State private var player: AVPlayer?
    @State private var loading = true

    var body: some View {
        ToolSheetScaffold(title: "Music", subtitle: "Free music and sound effects for your edit.", onClose: { stop(); dismiss() }) {
            Picker("", selection: $tab) {
                Text("Music").tag(0)
                Text("Sound effects").tag(1)
            }
            .pickerStyle(.segmented)
            if tab == 0 { music } else { effects }
        }
        .task {
            await library.load()
            loading = false
            if genre == nil { genre = library.genres.first }
        }
        .onDisappear { stop() }
    }

    // MARK: Music

    @ViewBuilder
    private var music: some View {
        if loading && library.pack == nil {
            ShimmerRows(count: 5)
        } else if library.pack == nil {
            Text("The music library needs an internet connection the first time.")
                .font(.ui(14))
                .foregroundColor(SX.C.muted)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(library.genres, id: \.self) { g in
                        FilterChip(title: g, selected: genre == g) { genre = g }
                    }
                }
            }
            VStack(spacing: 10) {
                ForEach(tracks) { track in
                    trackRow(track)
                }
            }
            Text("Tracks come from Wikimedia Commons (public domain, CC0 or CC BY). For CC BY tracks, credit the artist when you publish; the clip name keeps the credit.")
                .font(.ui(11.5))
                .foregroundColor(SX.C.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tracks: [MediaPack.Track] {
        (library.pack?.music ?? []).filter { genre == nil || $0.genre == genre }
    }

    private func trackRow(_ track: MediaPack.Track) -> some View {
        HStack(spacing: 12) {
            Button {
                toggle(track)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: Self.gradient(for: track.genre), startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: playing == track.id ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(PressableStyle())
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.ui(14.5, .semibold, fixed: true))
                    .foregroundColor(SX.C.ink)
                    .lineLimit(1)
                Text("\(track.author) · \(Timecode.short(track.duration)) · \(track.license)")
                    .font(.mono(10.5))
                    .foregroundColor(SX.C.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                stop()
                dismiss()
                Task { await model.addPackTrack(track) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(SX.C.onAccent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(SX.accentGradient))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Add \(track.title)")
        }
        .padding(10)
        .sxCard(radius: SX.R.l)
    }

    static func gradient(for genre: String) -> [Color] {
        let pairs: [String: (UInt32, UInt32)] = [
            "Upbeat": (0xFFD76A, 0xFF7A59), "Cinematic": (0x241E63, 0xC4BBFF), "Electronic": (0x5A49E6, 0x6EC6FF),
            "Chill": (0x8EF0C8, 0x2E86DE), "Rock": (0xFF5A6E, 0x1B1530), "Piano": (0xF5F2FF, 0x8F8BBA),
            "Funk": (0xFF9F43, 0xFF7AC8), "Classical": (0xE9B84A, 0x7A3A6A),
        ]
        let p = pairs[genre] ?? (0x5A49E6, 0xFFD76A)
        return [Color(UIColor(hex: p.0)), Color(UIColor(hex: p.1))]
    }

    private func toggle(_ track: MediaPack.Track) {
        if playing == track.id {
            stop()
            return
        }
        stop()
        playing = track.id
        Task {
            guard let url = await library.file(track.file), playing == track.id else { return }
            let p = AVPlayer(url: url)
            player = p
            p.play()
        }
    }

    private func stop() {
        player?.pause()
        player = nil
        playing = nil
    }

    // MARK: Sound effects

    private var effects: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
            ForEach(SoundEffects.all) { e in
                Button {
                    model.addSoundEffect(e)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        ArtIcon(symbol: e.icon, palette: ArtPalette.forName(e.id), size: 54)
                        Text(e.name.loc)
                            .font(.ui(11, .medium, fixed: true))
                            .foregroundColor(SX.C.body)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

/// Placeholder rows that shimmer while content loads.
struct ShimmerRows: View {
    let count: Int
    @State private var phase: CGFloat = -1

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: SX.R.l, style: .continuous)
                    .fill(SX.C.glass)
                    .frame(height: 72)
                    .overlay(
                        LinearGradient(colors: [.clear, Color.white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                            .offset(x: phase * 300)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: SX.R.l, style: .continuous))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
        }
    }
}

/// SCYDE's footage library (no key needed), shown inside the stock sheet.
struct LibraryBrowser: View {
    @ObservedObject var model: EditorViewModel
    @ObservedObject private var library = MediaLibrary.shared
    let onAdded: () -> Void
    @State private var category = TemplateCategory.cars
    @State private var loading = true
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TemplateCategory.allCases) { c in
                        FilterChip(title: "\(c.emoji) \(c.title.loc)", selected: category == c) { category = c }
                    }
                }
            }
            if loading && library.pack == nil {
                ShimmerRows(count: 3)
            } else if library.pack == nil {
                Text("The library needs an internet connection the first time.")
                    .font(.ui(14))
                    .foregroundColor(SX.C.muted)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(library.videos(for: category.rawValue)) { v in
                            Button {
                                onAdded()
                                Task { await model.addPackVideo(v) }
                            } label: {
                                PackVideoTile(video: v)
                                    .frame(height: 210)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    Text("Clips from Pixabay, Pexels and Wikimedia Commons, free to use in your videos. The clip name keeps the author.")
                        .font(.ui(11.5))
                        .foregroundColor(SX.C.muted)
                        .padding(.vertical, 10)
                }
            }
        }
        .task {
            await library.load()
            loading = false
        }
    }
}

/// A looping preview of a library clip with its credit.
struct PackVideoTile: View {
    let video: MediaPack.Video
    @State private var url: URL?
    @State private var poster: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SX.C.surface3
            if let poster = poster {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
            }
            if let url = url {
                LoopingVideo(url: url)
                    .transition(.opacity)
            } else if poster == nil {
                ProgressView().tint(SX.C.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            LinearGradient(colors: [.clear, Color.black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 1) {
                Text(video.title)
                    .font(.ui(11, .semibold, fixed: true))
                    .lineLimit(1)
                Text("\(video.author) · \(video.license)")
                    .font(.mono(9))
                    .lineLimit(1)
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .padding(8)
        }
        .clipped()
        .task(id: video.id) {
            poster = await MediaLibrary.shared.posterImage(for: video)
            let file = await MediaLibrary.shared.file(video.file)
            withAnimation(.easeOut(duration: 0.25)) { url = file }
        }
    }
}
