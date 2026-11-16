// File storage in Application Support: per-room folders (plan.json, capture.json, model.usdz, thumb.png) and project folders.
import Foundation

struct FileStore {
    enum FileError: LocalizedError {
        case notFound

        var errorDescription: String? {
            String(localized: "The file could not be found.")
        }
    }

    static let planFile = "plan.json"
    static let captureFile = "capture.json"
    static let modelFile = "model.usdz"
    static let thumbnailFile = "thumb.png"
    static let mergedPlanFile = "merged.json"
    static let mergedModelFile = "merged.usdz"

    let root: URL

    var roomsDirectory: URL { root.appendingPathComponent("Rooms", isDirectory: true) }
    var projectsDirectory: URL { root.appendingPathComponent("Projects", isDirectory: true) }
    var exportsDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PlanScanExports", isDirectory: true)
    }

    /// Application Support/PlanScan (falls back to the temporary directory if unavailable).
    static func makeDefault() -> FileStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let store = FileStore(root: base.appendingPathComponent("PlanScan", isDirectory: true))
        try? store.ensureDirectory(store.roomsDirectory)
        try? store.ensureDirectory(store.projectsDirectory)
        return store
    }

    func roomFolder(_ folderName: String) -> URL {
        roomsDirectory.appendingPathComponent(folderName, isDirectory: true)
    }

    func projectFolder(_ id: UUID) -> URL {
        projectsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func write(_ data: Data, to url: URL) throws {
        try ensureDirectory(url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
    }

    func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try write(try encoder.encode(value), to: url)
    }

    func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        guard exists(url) else { throw FileError.notFound }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Moves a file into place, replacing any existing file.
    func moveItem(at source: URL, to destination: URL) throws {
        try ensureDirectory(destination.deletingLastPathComponent())
        if exists(destination) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    func copyItem(at source: URL, to destination: URL) throws {
        try ensureDirectory(destination.deletingLastPathComponent())
        if exists(destination) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    func removeItem(at url: URL) {
        guard exists(url) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func removeEverything() {
        removeItem(at: roomsDirectory)
        removeItem(at: projectsDirectory)
        removeItem(at: exportsDirectory)
        try? ensureDirectory(roomsDirectory)
        try? ensureDirectory(projectsDirectory)
    }

    /// A fresh URL in the temporary exports folder with the given file name.
    func exportURL(fileName: String) throws -> URL {
        let folder = exportsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try ensureDirectory(folder)
        return folder.appendingPathComponent(fileName)
    }
}
