// Builds rooms from manual templates (rectangle, L-shape) with doors and windows placed on chosen walls.
import Foundation

enum ManualShape: String, Codable, CaseIterable, Identifiable {
    case rectangle, lShape
    var id: String { rawValue }
}

struct ManualOpeningSpec: Identifiable, Hashable {
    var id = UUID()
    var kind: OpeningKind
    var wallIndex: Int
    var width: Double
    /// Center position along the wall, 0…1.
    var position: Double = 0.5

    var height: Double {
        switch kind {
        case .door: return 2.05
        case .window: return 1.4
        case .opening: return 2.1
        }
    }

    var sillHeight: Double { kind == .window ? 0.9 : 0 }

    static func defaultWidth(for kind: OpeningKind) -> Double {
        switch kind {
        case .door: return 0.85
        case .window: return 1.2
        case .opening: return 1.0
        }
    }
}

struct ManualRoomSpec: Hashable {
    var name = ""
    var type: RoomType = .living
    var shape: ManualShape = .rectangle
    /// Rectangle width (x) and length (y), meters.
    var width = 4.0
    var length = 3.5
    /// L-shape: full top width, full left height, bottom arm width, right arm height.
    var lTop = 5.0
    var lLeft = 4.5
    var lBottom = 2.8
    var lRight = 2.4
    var ceilingHeight = 2.6
    var openings: [ManualOpeningSpec] = []
}

enum ManualRoomFactory {
    static let minimumSide = 0.8

    /// Applies the L-shape constraints (arms shorter than the full sides) and minimum sizes.
    static func validated(_ spec: ManualRoomSpec) -> ManualRoomSpec {
        var s = spec
        s.width = max(minimumSide, s.width)
        s.length = max(minimumSide, s.length)
        s.lTop = max(minimumSide * 2, s.lTop)
        s.lLeft = max(minimumSide * 2, s.lLeft)
        s.lBottom = min(max(minimumSide, s.lBottom), s.lTop - minimumSide)
        s.lRight = min(max(minimumSide, s.lRight), s.lLeft - minimumSide)
        s.ceilingHeight = min(max(1.8, s.ceilingHeight), 6)
        let count = wallCount(for: s.shape)
        s.openings = s.openings.map { opening in
            var o = opening
            o.wallIndex = min(max(0, o.wallIndex), count - 1)
            o.width = min(max(0.4, o.width), 4)
            o.position = min(max(0, o.position), 1)
            return o
        }
        return s
    }

    static func wallCount(for shape: ManualShape) -> Int { shape == .rectangle ? 4 : 6 }

    /// Clockwise outline on screen (y down), starting at the top-left corner.
    static func outline(for spec: ManualRoomSpec) -> [Point2D] {
        let s = validated(spec)
        switch s.shape {
        case .rectangle:
            return [Point2D(x: 0, y: 0), Point2D(x: s.width, y: 0),
                    Point2D(x: s.width, y: s.length), Point2D(x: 0, y: s.length)]
        case .lShape:
            return [Point2D(x: 0, y: 0), Point2D(x: s.lTop, y: 0), Point2D(x: s.lTop, y: s.lRight),
                    Point2D(x: s.lBottom, y: s.lRight), Point2D(x: s.lBottom, y: s.lLeft), Point2D(x: 0, y: s.lLeft)]
        }
    }

    /// Length of each wall in outline order.
    static func wallLengths(for spec: ManualRoomSpec) -> [Double] {
        let points = outline(for: spec)
        return points.indices.map { points[$0].distance(to: points[($0 + 1) % points.count]) }
    }

    /// Opening center position clamped so the whole opening fits on its wall.
    static func clampedPosition(_ position: Double, width: Double, wallLength: Double) -> Double {
        guard wallLength > width else { return 0.5 }
        let margin = (width / 2 + 0.05) / wallLength
        return min(max(position, margin), 1 - margin)
    }

    static func makeRoom(_ spec: ManualRoomSpec, id: UUID = UUID()) -> RoomGeometry {
        let s = validated(spec)
        let points = outline(for: s)
        var walls: [Wall] = []
        for i in points.indices {
            walls.append(Wall(id: UUID(), start: points[i], end: points[(i + 1) % points.count],
                              height: s.ceilingHeight, thickness: 0.12, confidence: .high))
        }
        var openings: [Opening] = []
        for spec in s.openings where spec.wallIndex < walls.count {
            let wall = walls[spec.wallIndex]
            let width = min(spec.width, max(0.3, wall.length - 0.1))
            let position = clampedPosition(spec.position, width: width, wallLength: wall.length)
            openings.append(Opening(id: spec.id, kind: spec.kind, wallID: wall.id,
                                    center: wall.point(at: position * wall.length), width: width,
                                    height: min(spec.height, s.ceilingHeight - 0.05),
                                    sillHeight: spec.sillHeight, angle: wall.angle))
        }
        let name = s.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return RoomGeometry(id: id, name: name, type: s.type, walls: walls, openings: openings, objects: [],
                            floorPolygon: points, ceilingHeight: s.ceilingHeight, source: .manual, quality: nil)
    }
}
