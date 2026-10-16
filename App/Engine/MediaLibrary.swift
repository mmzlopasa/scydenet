import AVFoundation
import Foundation
import SCYDECore
import UIKit

/// SCYDE's footage and music pack: freely licensed Wikimedia Commons media, prepared by CI
/// and published on GitHub as the `template-media` release. Downloaded on demand and cached.
struct MediaPack: Codable, Equatable {
    struct Video: Codable, Identifiable, Hashable {
        let id: String
        let category: String
        let file: String
        let width: Int
        let height: Int
        let duration: Double
        let title: String
        let author: String
        let license: String
        let source: String
        /// Small JPEG still published next to the clip (newer packs).
        var poster: String? = nil
    }

    struct Track: Codable, Identifiable, Hashable {
        let id: String
        let genre: String
        let file: String
        let duration: Double
        let rawTitle: String
        /// Title without catalogue codes such as "(ISRC USUAN1100233)".
        var title: String {
            rawTitle.replacingOccurrences(of: #"\s*\(ISRC [^)]*\)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+by Kevin MacLeod$"#, with: "", options: .regularExpression)
        }

        private enum CodingKeys: String, CodingKey {
            case id, genre, file, duration, rawTitle = "title", author, license, source
        }

        let author: String
        let license: String
        let source: String
    }

    var version: Int
    var videos: [Video]
    var music: [Track]
}

@MainActor
final class MediaLibrary: ObservableObject {
    static let shared = MediaLibrary()
    nonisolated static let base = URL(string: "https://github.com/mmzlopasa/scydenet/releases/download/template-media/")!

    @Published private(set) var pack: MediaPack?
    @Published private(set) var failed = false
    private var loading: Task<Void, Never>?
    private var downloads: [String: Task<URL?, Never>] = [:]

    nonisolated static var directory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MediaPack", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    nonisolated private static var manifestURL: URL { directory.appendingPathComponent("manifest.json") }

    init() {
        if let data = try? Data(contentsOf: Self.manifestURL),
           let cached = try? JSONDecoder().decode(MediaPack.self, from: data) {
            pack = cached
        }
    }

    /// Loads the manifest (cached copy first, refreshed from the network at most every 12 hours).
    func load() async {
        if let running = loading { return await running.value }
        let task = Task { [weak self] in
            guard let self = self else { return }
            let attrs = try? FileManager.default.attributesOfItem(atPath: Self.manifestURL.path)
            let age = (attrs?[.modificationDate] as? Date).map { Date().timeIntervalSince($0) } ?? .infinity
            // Refresh hourly, and always when the cached pack has no footage yet.
            if let p = self.pack, !p.videos.isEmpty, age < 3600 { return }
            do {
                var request = URLRequest(url: Self.base.appendingPathComponent("manifest.json"))
                request.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let decoded = try JSONDecoder().decode(MediaPack.self, from: data)
                try? data.write(to: Self.manifestURL, options: .atomic)
                self.pack = decoded
                self.failed = false
            } catch {
                if self.pack == nil { self.failed = true }
            }
        }
        loading = task
        await task.value
        loading = nil
    }

    func videos(for category: String) -> [MediaPack.Video] {
        pack?.videos.filter { $0.category == category } ?? []
    }

    var genres: [String] {
        var seen: [String] = []
        for t in pack?.music ?? [] where !seen.contains(t.genre) { seen.append(t.genre) }
        return seen
    }

    nonisolated static func localURL(_ file: String) -> URL { directory.appendingPathComponent(file) }

    nonisolated static func isCached(_ file: String) -> Bool {
        FileManager.default.fileExists(atPath: localURL(file).path)
    }

    /// Downloads a pack file once; concurrent callers share the same download.
    func file(_ name: String) async -> URL? {
        let local = Self.localURL(name)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        if let running = downloads[name] { return await running.value }
        let remote = Self.base.appendingPathComponent(name)
        let task = Task.detached(priority: .utility) { () -> URL? in
            do {
                let (tmp, response) = try await URLSession.shared.download(from: remote)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
                try? FileManager.default.removeItem(at: local)
                try FileManager.default.moveItem(at: tmp, to: local)
                return local
            } catch {
                return nil
            }
        }
        downloads[name] = task
        let result = await task.value
        downloads[name] = nil
        return result
    }

    private let posterCache = NSCache<NSString, UIImage>()

    /// A still for a pack video: the published poster, or a frame of the downloaded clip.
    func posterImage(for video: MediaPack.Video) async -> UIImage? {
        if let hit = posterCache.object(forKey: video.id as NSString) { return hit }
        var image: UIImage?
        if let name = video.poster, let url = await file(name), let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
        if image == nil, let url = await file(video.file) {
            image = await Task.detached(priority: .utility) { () -> UIImage? in
                let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                gen.appliesPreferredTrackTransform = true
                gen.maximumSize = CGSize(width: 480, height: 480)
                guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.8, preferredTimescale: 600), actualTime: nil) else { return nil }
                return UIImage(cgImage: cg)
            }.value
        }
        if let image = image { posterCache.setObject(image, forKey: video.id as NSString) }
        return image
    }

    /// A few clips across categories, for showcases (stable order).
    func showcase(_ count: Int) -> [MediaPack.Video] {
        guard let videos = pack?.videos, !videos.isEmpty else { return [] }
        var byCategory: [String: [MediaPack.Video]] = [:]
        var order: [String] = []
        for v in videos {
            if byCategory[v.category] == nil { order.append(v.category) }
            byCategory[v.category, default: []].append(v)
        }
        var out: [MediaPack.Video] = []
        var round = 0
        while out.count < count && round < 4 {
            for c in order where out.count < count {
                if let list = byCategory[c], round < list.count { out.append(list[round]) }
            }
            round += 1
        }
        return out
    }

    /// Copies a pack file into the project media folder (stable name, copied once) and returns its asset ID.
    func importToMedia(_ name: String) async -> String? {
        let assetID = "pack-" + name
        let dest = MediaStore.url(for: assetID)
        if FileManager.default.fileExists(atPath: dest.path) { return assetID }
        guard let src = await file(name) else { return nil }
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            return assetID
        } catch {
            return FileManager.default.fileExists(atPath: dest.path) ? assetID : nil
        }
    }

    /// A clip on the main track for a pack video, scaled to fill a canvas of `aspect`.
    func clip(for video: MediaPack.Video, duration: Double, aspect: CanvasAspect) async -> Clip? {
        guard let assetID = await importToMedia(video.file) else { return nil }
        var clip = Clip(
            kind: .video,
            name: video.title,
            assetID: assetID,
            sourceDuration: video.duration,
            duration: min(duration, video.duration)
        )
        let fill = Self.fillScale(width: video.width, height: video.height, aspect: aspect)
        if fill > 1.01 { clip.transform = ClipTransform(scale: fill) }
        return clip
    }

    /// Scale that turns an aspect-fit picture into one that fills the canvas.
    nonisolated static func fillScale(width: Int, height: Int, aspect: CanvasAspect) -> Double {
        guard width > 0, height > 0 else { return 1 }
        let source = Double(width) / Double(height)
        let canvas = aspect.ratio
        return max(source / canvas, canvas / source)
    }

    /// Credit line shown wherever pack media is used.
    nonisolated static func credit(title: String, author: String, license: String) -> String {
        "\(title) · \(author) · \(license) · \(sourceName(license: license))"
    }

    /// Where a pack item comes from, read from its licence name.
    nonisolated static func sourceName(license: String) -> String {
        let l = license.lowercased()
        if l.contains("pixabay") { return "Pixabay" }
        if l.contains("pexels") { return "Pexels" }
        return "Wikimedia Commons"
    }

    /// Distinct sources of a set of pack videos, for credit lines.
    nonisolated static func sources(_ videos: [MediaPack.Video]) -> String {
        var seen: [String] = []
        for v in videos {
            let s = sourceName(license: v.license)
            if !seen.contains(s) { seen.append(s) }
        }
        return seen.joined(separator: " · ")
    }
}
