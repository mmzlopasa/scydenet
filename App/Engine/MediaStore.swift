import Foundation

/// Imported media lives in `Documents/Media`. Clips store only the file name,
/// because the app container path changes every time the app is re-signed.
enum MediaStore {
    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Media", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for assetID: String) -> URL {
        directory.appendingPathComponent(assetID)
    }

    static func newAssetID(ext: String) -> String {
        UUID().uuidString + "." + ext
    }
}
