// Project and room persistence: SwiftData records plus geometry, captures, USDZ models and thumbnails on disk.
import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class ProjectStore {
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored let files: FileStore
    @ObservationIgnored private var geometryCache: [UUID: RoomGeometry] = [:]
    /// Bumped on every change so views that cache derived data can refresh.
    private(set) var revision = 0
    /// Last persistence error, shown by the UI in an alert.
    var lastErrorMessage: String?

    init(context: ModelContext, files: FileStore) {
        self.context = context
        self.files = files
    }

    // MARK: Queries

    func allProjects() -> [Project] {
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func allRooms() -> [RoomRecord] {
        let descriptor = FetchDescriptor<RoomRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func project(id: UUID) -> Project? { allProjects().first { $0.id == id } }
    func room(id: UUID) -> RoomRecord? { allRooms().first { $0.id == id } }

    /// Scanned and manual rooms (the sample does not count toward the Free limit).
    func savedRoomCount() -> Int { allRooms().filter { !$0.isSample }.count }

    var sampleProject: Project? { allProjects().first { $0.isSample } }

    /// The default project for new rooms: "My Home", otherwise the most recent own project, otherwise a new "My Home".
    func defaultProject() -> Project {
        let own = allProjects().filter { !$0.isSample }
        if let home = own.first(where: { $0.name == AppConfig.defaultProjectName }) { return home }
        if let recent = own.first { return recent }
        return createProject(named: AppConfig.defaultProjectName)
    }

    // MARK: Geometry & files

    func geometry(for room: RoomRecord) -> RoomGeometry? {
        if let cached = geometryCache[room.id] { return cached }
        let url = files.roomFolder(room.folderName).appendingPathComponent(FileStore.planFile)
        guard let geometry = try? files.readJSON(RoomGeometry.self, from: url) else { return nil }
        geometryCache[room.id] = geometry
        return geometry
    }

    func plan(for room: RoomRecord) -> FloorPlanModel? {
        geometry(for: room).map { FloorPlanModel(room: $0) }
    }

    /// Combined plan for rooms that share coordinates (whole-home scans and the sample), when there are 2+ rooms.
    func wholeFloorPlan(for project: Project) -> FloorPlanModel? {
        let rooms = project.sortedRooms
        var shared: [RoomGeometry] = []
        if let mergedFile = project.mergedPlanFile {
            let url = files.projectFolder(project.id).appendingPathComponent(mergedFile)
            if let merged = try? files.readJSON(FloorPlanModel.self, from: url) {
                let mergedIDs = Set(merged.rooms.map(\.id))
                shared = rooms.filter { mergedIDs.contains($0.id) }.compactMap { geometry(for: $0) }
            }
        } else if project.isSample {
            shared = rooms.filter(\.isSample).compactMap { geometry(for: $0) }
        }
        return shared.count >= 2 ? FloorPlanModel(rooms: shared) : nil
    }

    /// Plan shown on a project card: the whole floor, otherwise the first room.
    func displayPlan(for project: Project) -> FloorPlanModel? {
        if let whole = wholeFloorPlan(for: project) { return whole }
        return project.sortedRooms.first.flatMap { plan(for: $0) }
    }

    func usdzURL(for room: RoomRecord) -> URL? {
        guard room.hasUSDZ else { return nil }
        let url = files.roomFolder(room.folderName).appendingPathComponent(FileStore.modelFile)
        return files.exists(url) ? url : nil
    }

    func thumbnailURL(for room: RoomRecord) -> URL? {
        let url = files.roomFolder(room.folderName).appendingPathComponent(FileStore.thumbnailFile)
        return files.exists(url) ? url : nil
    }

    func mergedUSDZURL(for project: Project) -> URL? {
        guard project.hasMergedUSDZ else { return nil }
        let url = files.projectFolder(project.id).appendingPathComponent(FileStore.mergedModelFile)
        return files.exists(url) ? url : nil
    }

    // MARK: Mutations

    @discardableResult
    func createProject(named name: String, isSample: Bool = false) -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = Project(name: trimmed.isEmpty ? AppConfig.defaultProjectName : trimmed, isSample: isSample)
        context.insert(project)
        save()
        return project
    }

    /// Persists a room: plan.json, optional capture.json and model.usdz, a thumbnail and the SwiftData record.
    @discardableResult
    func saveRoom(_ geometry: RoomGeometry, in project: Project, captureData: Data? = nil, usdzSource: URL? = nil) throws -> RoomRecord {
        let folderName = geometry.id.uuidString
        let folder = files.roomFolder(folderName)
        try files.writeJSON(geometry, to: folder.appendingPathComponent(FileStore.planFile))
        var hasCapture = false
        if let captureData {
            try files.write(captureData, to: folder.appendingPathComponent(FileStore.captureFile))
            hasCapture = true
        }
        var hasModel = false
        if let usdzSource, files.exists(usdzSource) {
            do {
                try files.copyItem(at: usdzSource, to: folder.appendingPathComponent(FileStore.modelFile))
                hasModel = true
            } catch {
                hasModel = false
            }
        }
        writeThumbnail(for: geometry, in: folder)
        let record = RoomRecord(id: geometry.id, name: geometry.name, type: geometry.type, source: geometry.source,
                                metrics: RoomMetrics(room: geometry), folderName: folderName, hasUSDZ: hasModel,
                                hasRawCapture: hasCapture, quality: geometry.quality)
        context.insert(record)
        record.project = project
        project.updatedAt = Date()
        geometryCache[geometry.id] = geometry
        try context.save()
        revision += 1
        return record
    }

    /// Saves the merged plan (and model) of a whole-home scan for a project.
    func saveMergedPlan(_ plan: FloorPlanModel, mergedUSDZ: URL?, for project: Project) throws {
        let folder = files.projectFolder(project.id)
        try files.writeJSON(plan, to: folder.appendingPathComponent(FileStore.mergedPlanFile))
        project.mergedPlanFile = FileStore.mergedPlanFile
        if let mergedUSDZ, files.exists(mergedUSDZ) {
            try files.copyItem(at: mergedUSDZ, to: folder.appendingPathComponent(FileStore.mergedModelFile))
            project.hasMergedUSDZ = true
        }
        project.updatedAt = Date()
        try context.save()
        revision += 1
    }

    func updateGeometry(_ geometry: RoomGeometry, for room: RoomRecord) {
        let folder = files.roomFolder(room.folderName)
        do {
            try files.writeJSON(geometry, to: folder.appendingPathComponent(FileStore.planFile))
            geometryCache[room.id] = geometry
            writeThumbnail(for: geometry, in: folder)
            let metrics = RoomMetrics(room: geometry)
            room.area = metrics.floorArea
            room.perimeter = metrics.perimeter
            room.ceilingHeight = metrics.ceilingHeight
            room.project?.updatedAt = Date()
            save()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func rename(_ project: Project, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        project.name = trimmed
        project.updatedAt = Date()
        save()
    }

    func rename(_ room: RoomRecord, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var geometry = geometry(for: room) else { return }
        room.name = trimmed
        geometry.name = trimmed
        updateGeometry(geometry, for: room)
    }

    func setType(_ type: RoomType, for room: RoomRecord) {
        guard var geometry = geometry(for: room) else { return }
        room.type = type
        geometry.type = type
        updateGeometry(geometry, for: room)
    }

    func delete(_ room: RoomRecord) {
        files.removeItem(at: files.roomFolder(room.folderName))
        geometryCache[room.id] = nil
        room.project?.updatedAt = Date()
        context.delete(room)
        save()
    }

    func delete(_ project: Project) {
        for room in project.rooms {
            files.removeItem(at: files.roomFolder(room.folderName))
            geometryCache[room.id] = nil
        }
        files.removeItem(at: files.projectFolder(project.id))
        context.delete(project)
        save()
    }

    func deleteAllData() {
        for project in allProjects() { context.delete(project) }
        save()
        for room in allRooms() { context.delete(room) }
        files.removeEverything()
        geometryCache.removeAll()
        save()
    }

    // MARK: Calculator report entries

    func reportSnapshots(for room: RoomRecord) -> [CalculatorSnapshot] {
        guard let data = room.reportCalculatorsData else { return [] }
        return (try? JSONDecoder().decode([CalculatorSnapshot].self, from: data)) ?? []
    }

    func isInReport(_ kind: CalculatorKind, room: RoomRecord) -> Bool {
        reportSnapshots(for: room).contains { $0.kind == kind }
    }

    /// Adds or replaces (`snapshot` non-nil) or removes the report entry of a calculator kind.
    func setReportSnapshot(_ snapshot: CalculatorSnapshot?, kind: CalculatorKind, for room: RoomRecord) {
        var entries = reportSnapshots(for: room).filter { $0.kind != kind }
        if let snapshot { entries.append(snapshot) }
        entries.sort { (CalculatorKind.allCases.firstIndex(of: $0.kind) ?? 0) < (CalculatorKind.allCases.firstIndex(of: $1.kind) ?? 0) }
        room.reportCalculatorsData = entries.isEmpty ? nil : (try? JSONEncoder().encode(entries))
        save()
    }

    // MARK: Helpers

    func save() {
        do {
            try context.save()
            revision += 1
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func writeThumbnail(for geometry: RoomGeometry, in folder: URL) {
        let image = PlanImageRenderer.thumbnail(for: FloorPlanModel(room: geometry), size: CGSize(width: 240, height: 180))
        if let data = image.pngData() {
            try? files.write(data, to: folder.appendingPathComponent(FileStore.thumbnailFile))
        }
    }
}
