// Codable floor plan data model shared by rendering, metrics, exports, persistence and the sample project.
import Foundation

/// A point in plan space, in meters. Top view: `x` = world X, `y` = world Z (Z grows toward the viewer, i.e. down on screen).
struct Point2D: Codable, Hashable {
    var x: Double
    var y: Double

    static let zero = Point2D(x: 0, y: 0)
}

enum Confidence: String, Codable, CaseIterable {
    case high, medium, low
}

/// A wall segment. Endpoints lie on the wall centerline.
struct Wall: Codable, Identifiable, Hashable {
    var id: UUID
    var start: Point2D
    var end: Point2D
    var height: Double
    var thickness: Double
    var confidence: Confidence
}

enum OpeningKind: String, Codable, CaseIterable {
    case door, window, opening
}

/// A door, window or open passage. `angle` (radians) is the direction of the opening's width axis in plan space.
struct Opening: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: OpeningKind
    var wallID: UUID?
    var center: Point2D
    var width: Double
    var height: Double
    var sillHeight: Double
    var angle: Double
}

enum FurnitureCategory: String, Codable, CaseIterable {
    case storage, refrigerator, stove, bed, sink, washerDryer, toilet, bathtub, oven, dishwasher,
         table, sofa, chair, fireplace, television, stairs, other
}

/// A furniture footprint. `width` runs along `angle` (radians), `depth` is perpendicular to it.
struct FurnitureItem: Codable, Identifiable, Hashable {
    var id: UUID
    var category: FurnitureCategory
    var center: Point2D
    var width: Double
    var depth: Double
    var height: Double
    var angle: Double
}

enum RoomType: String, Codable, CaseIterable {
    case living, bedroom, kitchen, bathroom, dining, office, hallway, other
}

enum RoomSource: String, Codable, CaseIterable {
    case scanned, manual, sample
}

/// One room. Coordinates are kept in world space so merged rooms line up.
struct RoomGeometry: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var type: RoomType
    var walls: [Wall]
    var openings: [Opening]
    var objects: [FurnitureItem]
    var floorPolygon: [Point2D]
    var ceilingHeight: Double
    var source: RoomSource
    var quality: Confidence?
}

/// A drawable plan: one room, or several rooms in shared coordinates.
struct FloorPlanModel: Codable, Hashable {
    var version: Int = 1
    var rooms: [RoomGeometry]
    var rotationDegrees: Double = 0

    init(rooms: [RoomGeometry], rotationDegrees: Double = 0) {
        self.rooms = rooms
        self.rotationDegrees = rotationDegrees
    }

    init(room: RoomGeometry) {
        self.init(rooms: [room])
    }

    var isEmpty: Bool { rooms.allSatisfy { $0.walls.isEmpty && $0.floorPolygon.isEmpty } }
}

extension RoomGeometry {
    /// Scan quality derived from the share of walls with high confidence (≥ 80% good, ≥ 50% fair, else low).
    static func quality(for walls: [Wall]) -> Confidence? {
        guard !walls.isEmpty else { return nil }
        let high = walls.filter { $0.confidence == .high }.count
        let share = Double(high) / Double(walls.count)
        if share >= 0.8 { return .high }
        if share >= 0.5 { return .medium }
        return .low
    }
}
