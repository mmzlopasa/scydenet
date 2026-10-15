import AVFoundation
import CoreTransferable
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import SCYDECore

/// A movie copied from the photo library into the app's media folder.
struct ImportedMovie: Transferable {
    let assetID: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension.lowercased()
            let id = MediaStore.newAssetID(ext: ext)
            try FileManager.default.copyItem(at: received.file, to: MediaStore.url(for: id))
            return ImportedMovie(assetID: id)
        }
    }
}

enum MediaImporter {
    /// Turns one picker item into a clip. Returns nil when the item cannot be read.
    static func clip(from item: PhotosPickerItem) async -> Clip? {
        let isMovie = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if isMovie {
            guard let movie = try? await item.loadTransferable(type: ImportedMovie.self) else { return nil }
            let asset = AVURLAsset(url: MediaStore.url(for: movie.assetID))
            guard let time = try? await asset.load(.duration) else { return nil }
            let seconds = time.seconds
            guard seconds.isFinite, seconds > Project.minClipDuration else { return nil }
            return Clip(kind: .video, name: "Video", assetID: movie.assetID, sourceDuration: seconds, duration: seconds)
        } else {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.92) else { return nil }
            let id = MediaStore.newAssetID(ext: "jpg")
            do {
                try jpeg.write(to: MediaStore.url(for: id), options: .atomic)
            } catch {
                return nil
            }
            return Clip(kind: .photo, name: "Photo", assetID: id, duration: 4)
        }
    }
}
