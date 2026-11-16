// Converts RoomPlan's CapturedRoom into the app's RoomGeometry (device builds only; RoomPlan does not run in the Simulator).
import Foundation

#if canImport(RoomPlan) && !targetEnvironment(simulator)
import RoomPlan
import simd

enum CapturedRoomConverter {
    /// Converts a captured room, keeping world coordinates so merged rooms line up.
    static func convert(_ room: CapturedRoom, id: UUID = UUID(), name: String, type: RoomType) -> RoomGeometry {
        let floorY = floorLevel(of: room)

        var walls: [Wall] = room.walls.map { surface in
            let halfWidth = surface.dimensions.x / 2
            let a = worldPoint(surface.transform, SIMD3<Float>(-halfWidth, 0, 0))
            let b = worldPoint(surface.transform, SIMD3<Float>(halfWidth, 0, 0))
            return Wall(id: surface.identifier, start: topView(a), end: topView(b),
                        height: Double(surface.dimensions.y), thickness: 0.12,
                        confidence: confidence(surface.confidence))
        }
        walls = PlanGeometry.snapCorners(walls, tolerance: 0.15)

        var openings: [Opening] = []
        func appendOpenings(_ surfaces: [CapturedRoom.Surface], kind: OpeningKind) {
            for surface in surfaces {
                let t = surface.transform
                let centerY = Double(t.columns.3.y)
                let center = Point2D(x: Double(t.columns.3.x), y: Double(t.columns.3.z))
                let height = Double(surface.dimensions.y)
                var wallID: UUID?
                if let parent = surface.parentIdentifier, walls.contains(where: { $0.id == parent }) {
                    wallID = parent
                } else {
                    wallID = walls.min(by: { $0.distance(to: center) < $1.distance(to: center) })?.id
                }
                openings.append(Opening(id: surface.identifier, kind: kind, wallID: wallID, center: center,
                                        width: Double(surface.dimensions.x), height: height,
                                        sillHeight: max(0, (centerY - height / 2) - floorY),
                                        angle: atan2(Double(t.columns.0.z), Double(t.columns.0.x))))
            }
        }
        appendOpenings(room.doors, kind: .door)
        appendOpenings(room.windows, kind: .window)
        appendOpenings(room.openings, kind: .opening)

        let objects: [FurnitureItem] = room.objects.map { object in
            let t = object.transform
            return FurnitureItem(id: object.identifier, category: category(object.category),
                                 center: Point2D(x: Double(t.columns.3.x), y: Double(t.columns.3.z)),
                                 width: Double(object.dimensions.x), depth: Double(object.dimensions.z),
                                 height: Double(object.dimensions.y),
                                 angle: atan2(Double(t.columns.0.z), Double(t.columns.0.x)))
        }

        var polygon: [Point2D] = []
        if let floor = room.floors.first, !floor.polygonCorners.isEmpty {
            polygon = floor.polygonCorners.map { topView(worldPoint(floor.transform, $0)) }
        } else if let chained = PlanGeometry.chainWalls(walls) {
            polygon = chained
        } else {
            polygon = PlanGeometry.convexHull(walls.flatMap { [$0.start, $0.end] })
        }

        let ceiling = PlanGeometry.median(walls.map(\.height)) ?? 2.5
        return RoomGeometry(id: id, name: name, type: type, walls: walls, openings: openings, objects: objects,
                            floorPolygon: polygon, ceilingHeight: ceiling, source: .scanned,
                            quality: RoomGeometry.quality(for: walls))
    }

    /// Room type suggested by RoomPlan's section label (iOS 17).
    static func suggestedType(for room: CapturedRoom) -> RoomType? {
        guard let label = room.sections.first?.label else { return nil }
        switch label {
        case .bedroom: return .bedroom
        case .bathroom: return .bathroom
        case .kitchen: return .kitchen
        case .livingRoom: return .living
        case .diningRoom: return .dining
        default: return nil
        }
    }

    static func worldPoint(_ transform: simd_float4x4, _ local: SIMD3<Float>) -> SIMD3<Float> {
        let p = transform * SIMD4<Float>(local.x, local.y, local.z, 1)
        return SIMD3<Float>(p.x, p.y, p.z)
    }

    static func topView(_ p: SIMD3<Float>) -> Point2D {
        Point2D(x: Double(p.x), y: Double(p.z))
    }

    static func floorLevel(of room: CapturedRoom) -> Double {
        if let floor = room.floors.first { return Double(floor.transform.columns.3.y) }
        let bottoms = room.walls.map { Double($0.transform.columns.3.y) - Double($0.dimensions.y) / 2 }
        return bottoms.min() ?? 0
    }

    static func confidence(_ value: CapturedRoom.Confidence) -> Confidence {
        switch value {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        default: return .medium
        }
    }

    static func category(_ value: CapturedRoom.Object.Category) -> FurnitureCategory {
        switch value {
        case .storage: return .storage
        case .refrigerator: return .refrigerator
        case .stove: return .stove
        case .bed: return .bed
        case .sink: return .sink
        case .washerDryer: return .washerDryer
        case .toilet: return .toilet
        case .bathtub: return .bathtub
        case .oven: return .oven
        case .dishwasher: return .dishwasher
        case .table: return .table
        case .sofa: return .sofa
        case .chair: return .chair
        case .fireplace: return .fireplace
        case .television: return .television
        case .stairs: return .stairs
        default: return .other
        }
    }
}
#endif
