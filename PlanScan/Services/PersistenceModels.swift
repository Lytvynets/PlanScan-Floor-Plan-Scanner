// SwiftData models: projects and room records (geometry and files live on disk, see FileStore).
import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \RoomRecord.project)
    var rooms: [RoomRecord] = []
    /// File name of the merged plan (`merged.json`) when rooms were scanned in one whole-home session.
    var mergedPlanFile: String?
    var hasMergedUSDZ: Bool
    var isSample: Bool

    init(id: UUID = UUID(), name: String, address: String = "", notes: String = "", isSample: Bool = false) {
        self.id = id
        self.name = name
        self.address = address
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.mergedPlanFile = nil
        self.hasMergedUSDZ = false
        self.isSample = isSample
    }

    var sortedRooms: [RoomRecord] {
        rooms.sorted { $0.createdAt < $1.createdAt }
    }

    var totalArea: Double {
        rooms.reduce(0) { $0 + $1.area }
    }
}

@Model
final class RoomRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var sourceRaw: String
    var createdAt: Date
    var area: Double
    var perimeter: Double
    var ceilingHeight: Double
    /// Folder under Application Support/PlanScan/Rooms holding plan.json, capture.json, model.usdz, thumb.png.
    var folderName: String
    var hasUSDZ: Bool
    var hasRawCapture: Bool
    /// JSON-encoded `[CalculatorSnapshot]` the user added to the report.
    var reportCalculatorsData: Data?
    var qualityRaw: String?
    var project: Project?

    init(id: UUID, name: String, type: RoomType, source: RoomSource, metrics: RoomMetrics, folderName: String,
         hasUSDZ: Bool, hasRawCapture: Bool, quality: Confidence?) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.sourceRaw = source.rawValue
        self.createdAt = Date()
        self.area = metrics.floorArea
        self.perimeter = metrics.perimeter
        self.ceilingHeight = metrics.ceilingHeight
        self.folderName = folderName
        self.hasUSDZ = hasUSDZ
        self.hasRawCapture = hasRawCapture
        self.reportCalculatorsData = nil
        self.qualityRaw = quality?.rawValue
        self.project = nil
    }

    var type: RoomType {
        get { RoomType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var source: RoomSource { RoomSource(rawValue: sourceRaw) ?? .manual }
    var quality: Confidence? { qualityRaw.flatMap(Confidence.init(rawValue:)) }
    var isSample: Bool { source == .sample }
}
