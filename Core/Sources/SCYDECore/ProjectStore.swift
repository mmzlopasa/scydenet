import Foundation

/// Reads and writes projects as JSON files in one directory.
public final class ProjectStore: @unchecked Sendable {
    public let directory: URL
    private let fm = FileManager.default

    public init(directory: URL) {
        self.directory = directory
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).scyde.json")
    }

    private func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public func save(_ project: Project) throws {
        let data = try makeEncoder().encode(project)
        try data.write(to: url(for: project.id), options: .atomic)
    }

    public func load(id: UUID) throws -> Project {
        let data = try Data(contentsOf: url(for: id))
        return try makeDecoder().decode(Project.self, from: data)
    }

    /// Every readable project, newest edit first. Unreadable files are skipped.
    public func list() -> [Project] {
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = makeDecoder()
        var projects: [Project] = []
        for file in files where file.lastPathComponent.hasSuffix(".scyde.json") {
            if let data = try? Data(contentsOf: file), let p = try? decoder.decode(Project.self, from: data) {
                projects.append(p)
            }
        }
        return projects.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public func delete(id: UUID) throws {
        let u = url(for: id)
        if fm.fileExists(atPath: u.path) {
            try fm.removeItem(at: u)
        }
    }
}
