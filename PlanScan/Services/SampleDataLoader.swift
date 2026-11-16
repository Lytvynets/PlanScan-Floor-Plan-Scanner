// Seeds the bundled "Sample apartment" (three rooms in shared coordinates) on first launch and on demand.
import Foundation

struct SampleProjectFile: Codable {
    var name: String
    var address: String?
    var notes: String?
    var rooms: [RoomGeometry]
}

@MainActor
enum SampleDataLoader {
    enum LoaderError: LocalizedError {
        case missingResource

        var errorDescription: String? {
            String(localized: "The sample project is missing from the app bundle.")
        }
    }

    /// Seeds the sample project once per install.
    static func seedIfNeeded(store: ProjectStore, settings: AppSettings) {
        guard !settings.sampleSeeded else { return }
        if store.sampleProject == nil {
            do {
                try seed(into: store)
            } catch {
                store.lastErrorMessage = error.localizedDescription
            }
        }
        settings.sampleSeeded = true
    }

    /// Returns the sample project, creating it again if the user deleted it.
    static func ensureSample(store: ProjectStore) throws -> Project {
        if let existing = store.sampleProject { return existing }
        return try seed(into: store)
    }

    /// Deletes and re-creates the sample project (debug menu).
    @discardableResult
    static func reseed(store: ProjectStore) throws -> Project {
        if let existing = store.sampleProject { store.delete(existing) }
        return try seed(into: store)
    }

    @discardableResult
    static func seed(into store: ProjectStore) throws -> Project {
        let file = try loadBundledSample()
        let project = store.createProject(named: String(localized: "Sample apartment"), isSample: true)
        for var room in file.rooms {
            room.id = UUID()
            room.name = room.type.displayName
            room.source = .sample
            try store.saveRoom(room, in: project)
        }
        return project
    }

    static func loadBundledSample() throws -> SampleProjectFile {
        guard let url = Bundle.main.url(forResource: "SampleProject", withExtension: "json") else {
            throw LoaderError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SampleProjectFile.self, from: data)
    }
}
