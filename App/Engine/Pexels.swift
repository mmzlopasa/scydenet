import Foundation
import Security

/// Free stock videos from Pexels (https://www.pexels.com/api/). Needs the user's own
/// free API key; videos are downloaded into the media folder and credited to the creator.
enum Pexels {
    struct Video: Decodable, Identifiable, Hashable {
        let id: Int
        let image: URL
        let duration: Int
        let url: URL?
        let user: User
        let video_files: [File]

        struct User: Decodable, Hashable {
            let name: String
        }

        struct File: Decodable, Hashable {
            let link: URL
            let quality: String?
            let width: Int?
            let height: Int?
            let file_type: String?
        }
    }

    private struct Response: Decodable {
        let videos: [Video]
    }

    enum Failure: LocalizedError {
        case noKey, badKey, network, noFile

        var errorDescription: String? {
            switch self {
            case .noKey: return "Add your free Pexels API key first.".loc
            case .badKey: return "Pexels did not accept that API key.".loc
            case .network: return "Could not reach Pexels. Check your connection.".loc
            case .noFile: return "This video has no downloadable file.".loc
            }
        }
    }

    enum Orientation: String {
        case portrait, landscape, square
    }

    // MARK: Requests

    static func search(_ query: String, orientation: Orientation, page: Int = 1) async throws -> [Video] {
        var components = URLComponents(string: "https://api.pexels.com/videos/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "orientation", value: orientation.rawValue),
            URLQueryItem(name: "per_page", value: "30"),
            URLQueryItem(name: "page", value: "\(page)"),
        ]
        return try await fetch(components.url!)
    }

    static func popular(page: Int = 1) async throws -> [Video] {
        var components = URLComponents(string: "https://api.pexels.com/videos/popular")!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "30"),
            URLQueryItem(name: "page", value: "\(page)"),
        ]
        return try await fetch(components.url!)
    }

    private static func fetch(_ url: URL) async throws -> [Video] {
        guard let key = APIKey.load(), !key.isEmpty else { throw Failure.noKey }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw Failure.network
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 401 || http.statusCode == 403 {
            throw Failure.badKey
        }
        return try JSONDecoder().decode(Response.self, from: data).videos
    }

    /// The best MP4 not larger than `maxSide` on its long edge.
    static func bestFile(_ video: Video, maxSide: Int = 1920) -> URL? {
        let mp4 = video.video_files.filter { ($0.file_type ?? "video/mp4") == "video/mp4" }
        let sized = mp4.filter { max($0.width ?? 0, $0.height ?? 0) <= maxSide }
        let pick = (sized.isEmpty ? mp4 : sized).max { max($0.width ?? 0, $0.height ?? 0) < max($1.width ?? 0, $1.height ?? 0) }
        return pick?.link
    }

    /// Downloads into the media folder and returns the new asset ID.
    static func download(_ video: Video) async throws -> String {
        guard let link = bestFile(video) else { throw Failure.noFile }
        let temp: URL
        do {
            (temp, _) = try await URLSession.shared.download(from: link)
        } catch {
            throw Failure.network
        }
        let id = MediaStore.newAssetID(ext: "mp4")
        try FileManager.default.moveItem(at: temp, to: MediaStore.url(for: id))
        return id
    }

    // MARK: Key storage (Keychain)

    enum APIKey {
        private static let service = "dev.scyde.pexels"

        static func load() -> String? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
                  let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }

        static func save(_ key: String) {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let base: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
            ]
            SecItemDelete(base as CFDictionary)
            guard !trimmed.isEmpty else { return }
            var add = base
            add[kSecValueData as String] = Data(trimmed.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
