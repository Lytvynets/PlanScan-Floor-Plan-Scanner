// Derived room measurements: area, perimeter, height, volume, wall areas, opening counts and baseboard length.
import Foundation

struct RoomMetrics: Hashable {
    var floorArea: Double
    var perimeter: Double
    var ceilingHeight: Double
    var volume: Double
    var grossWallArea: Double
    var openingsArea: Double
    var netWallArea: Double
    var doorCount: Int
    var windowCount: Int
    var passageCount: Int
    /// Total width of doors and open passages (no baseboard runs across them).
    var doorWidthTotal: Double
    var baseboardLength: Double
    var wallCount: Int
    var objectCount: Int

    init(room: RoomGeometry) {
        let outline = room.outline
        floorArea = PlanGeometry.area(outline)
        let wallLengthSum = room.walls.reduce(0) { $0 + $1.length }
        perimeter = outline.count >= 3 ? PlanGeometry.perimeter(outline) : wallLengthSum
        let height = PlanGeometry.median(room.walls.map(\.height).filter { $0 > 0.1 }) ?? room.ceilingHeight
        ceilingHeight = height > 0.1 ? height : room.ceilingHeight
        volume = floorArea * ceilingHeight
        grossWallArea = room.walls.reduce(0) { $0 + $1.length * $1.height }
        let hosted = room.openings.filter { room.hostWall(for: $0) != nil }
        openingsArea = min(grossWallArea, hosted.reduce(0) { $0 + $1.width * $1.height })
        netWallArea = max(0, grossWallArea - openingsArea)
        doorCount = room.openings.filter { $0.kind == .door }.count
        windowCount = room.openings.filter { $0.kind == .window }.count
        passageCount = room.openings.filter { $0.kind == .opening }.count
        doorWidthTotal = room.openings.filter { $0.kind != .window }.reduce(0) { $0 + $1.width }
        baseboardLength = max(0, perimeter - doorWidthTotal)
        wallCount = room.walls.count
        objectCount = room.objects.count
    }

    private init(totalOf parts: [RoomMetrics]) {
        floorArea = parts.reduce(0) { $0 + $1.floorArea }
        perimeter = parts.reduce(0) { $0 + $1.perimeter }
        ceilingHeight = PlanGeometry.median(parts.map(\.ceilingHeight)) ?? 0
        volume = parts.reduce(0) { $0 + $1.volume }
        grossWallArea = parts.reduce(0) { $0 + $1.grossWallArea }
        openingsArea = parts.reduce(0) { $0 + $1.openingsArea }
        netWallArea = parts.reduce(0) { $0 + $1.netWallArea }
        doorCount = parts.reduce(0) { $0 + $1.doorCount }
        windowCount = parts.reduce(0) { $0 + $1.windowCount }
        passageCount = parts.reduce(0) { $0 + $1.passageCount }
        doorWidthTotal = parts.reduce(0) { $0 + $1.doorWidthTotal }
        baseboardLength = parts.reduce(0) { $0 + $1.baseboardLength }
        wallCount = parts.reduce(0) { $0 + $1.wallCount }
        objectCount = parts.reduce(0) { $0 + $1.objectCount }
    }

    /// Sum over several rooms (shared doors are counted once per room that lists them).
    static func total(of rooms: [RoomGeometry]) -> RoomMetrics {
        RoomMetrics(totalOf: rooms.map(RoomMetrics.init(room:)))
    }
}
