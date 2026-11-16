// Resolves rooms into drawable walls and openings: host walls, solid wall pieces and multi-room de-duplication.
import Foundation

/// A span along a wall, in meters measured from `wall.start`.
struct WallInterval: Hashable {
    var start: Double
    var end: Double
    var length: Double { end - start }
}

extension RoomGeometry {
    /// The wall that hosts an opening: the explicit `wallID`, otherwise the nearest wall within `tolerance`.
    func hostWall(for opening: Opening, tolerance: Double = 0.45) -> Wall? {
        if let id = opening.wallID, let wall = walls.first(where: { $0.id == id }) { return wall }
        var best: Wall?
        var bestDistance = tolerance
        for wall in walls {
            let d = wall.distance(to: opening.center)
            if d <= bestDistance {
                bestDistance = d
                best = wall
            }
        }
        return best
    }

    func openings(on wall: Wall) -> [Opening] {
        openings.filter { hostWall(for: $0)?.id == wall.id }
    }

    var centroid: Point2D {
        if floorPolygon.count >= 3 { return PlanGeometry.centroid(floorPolygon) }
        return PlanGeometry.average(walls.flatMap { [$0.start, $0.end] })
    }

    /// Floor outline: the stored polygon, otherwise chained walls, otherwise the convex hull of wall endpoints.
    var outline: [Point2D] {
        if floorPolygon.count >= 3 { return floorPolygon }
        if let chained = PlanGeometry.chainWalls(walls) { return chained }
        return PlanGeometry.convexHull(walls.flatMap { [$0.start, $0.end] })
    }

    var labelAnchor: Point2D { PlanGeometry.labelAnchor(for: outline) }

    /// Unit normal of `wall` that points away from this room's interior.
    func outwardNormal(of wall: Wall) -> Point2D {
        let n = wall.normal
        let polygon = outline
        if polygon.count >= 3 {
            let probe = min(0.25, max(0.05, wall.length * 0.2))
            let plusInside = PlanGeometry.contains(wall.midpoint + n * probe, in: polygon)
            let minusInside = PlanGeometry.contains(wall.midpoint - n * probe, in: polygon)
            if plusInside && !minusInside { return -n }
            if minusInside && !plusInside { return n }
        }
        return (wall.midpoint - centroid).dot(n) >= 0 ? n : -n
    }
}

extension Opening {
    /// Interval occupied along `wall`, clamped to the wall length.
    func interval(on wall: Wall) -> WallInterval? {
        let length = wall.length
        guard length > 0.01 else { return nil }
        let t = wall.distanceAlong(center)
        let s = max(0, t - width / 2)
        let e = min(length, t + width / 2)
        return e - s > 0.01 ? WallInterval(start: s, end: e) : nil
    }
}

/// Walls and openings of a plan, with duplicates removed so shared walls and doors are drawn once.
struct ResolvedPlan {
    struct WallEntry {
        let wall: Wall
        let roomIndex: Int
        let outwardNormal: Point2D
        var openings: [Opening]
    }

    struct OpeningEntry {
        let opening: Opening
        let roomIndex: Int
        let hostWall: Wall?
        /// Unit normal pointing into the owning room (door leaves swing this way).
        let inwardNormal: Point2D
    }

    let rooms: [RoomGeometry]
    private(set) var walls: [WallEntry] = []
    private(set) var openings: [OpeningEntry] = []

    init(_ plan: FloorPlanModel, wallTolerance: Double = 0.05, openingTolerance: Double = 0.15) {
        rooms = plan.rooms
        var duplicateOf: [UUID: Int] = [:]

        for (roomIndex, room) in plan.rooms.enumerated() {
            for wall in room.walls where wall.length > 0.01 {
                if let existing = walls.firstIndex(where: { Self.sameSegment($0.wall, wall, tolerance: wallTolerance) }) {
                    duplicateOf[wall.id] = existing
                } else {
                    walls.append(WallEntry(wall: wall, roomIndex: roomIndex,
                                           outwardNormal: room.outwardNormal(of: wall), openings: []))
                }
            }
        }

        for (roomIndex, room) in plan.rooms.enumerated() {
            for opening in room.openings {
                let isDuplicate = openings.contains { entry in
                    entry.opening.kind == opening.kind &&
                        entry.opening.center.distance(to: opening.center) <= openingTolerance
                }
                let host = room.hostWall(for: opening)
                if let host {
                    let wallIndex = duplicateOf[host.id] ?? walls.firstIndex(where: { $0.wall.id == host.id })
                    if let wallIndex, !isDuplicate {
                        walls[wallIndex].openings.append(opening)
                    }
                }
                guard !isDuplicate else { continue }
                let inward: Point2D
                if let host {
                    inward = -room.outwardNormal(of: host)
                } else {
                    let axis = Point2D.unit(angle: opening.angle).perpendicular
                    inward = (room.centroid - opening.center).dot(axis) >= 0 ? axis : -axis
                }
                openings.append(OpeningEntry(opening: opening, roomIndex: roomIndex, hostWall: host, inwardNormal: inward))
            }
        }
    }

    /// Solid pieces of a wall after cutting out every opening hosted on it.
    func solidIntervals(of entry: WallEntry) -> [WallInterval] {
        let length = entry.wall.length
        let cuts = entry.openings.compactMap { $0.interval(on: entry.wall) }.sorted { $0.start < $1.start }
        var result: [WallInterval] = []
        var cursor = 0.0
        for cut in cuts {
            if cut.start > cursor + 0.005 { result.append(WallInterval(start: cursor, end: cut.start)) }
            cursor = max(cursor, cut.end)
        }
        if length > cursor + 0.005 { result.append(WallInterval(start: cursor, end: length)) }
        return result
    }

    /// True when the point lies inside any room other than `excluding`.
    func isInsideOtherRoom(_ point: Point2D, excluding roomIndex: Int) -> Bool {
        for (index, room) in rooms.enumerated() where index != roomIndex {
            if PlanGeometry.contains(point, in: room.outline) { return true }
        }
        return false
    }

    static func sameSegment(_ a: Wall, _ b: Wall, tolerance: Double) -> Bool {
        (a.start.isClose(to: b.start, tolerance: tolerance) && a.end.isClose(to: b.end, tolerance: tolerance)) ||
            (a.start.isClose(to: b.end, tolerance: tolerance) && a.end.isClose(to: b.start, tolerance: tolerance))
    }
}

/// How wall ends meet neighboring walls (corners, T-junctions, straight continuations or free ends).
enum WallJoins {
    /// How a wall end meets its neighbors: face extensions (+ extends, − shortens) for the +normal and −normal
    /// faces and whether the end needs a cap line.
    static func treatment(of wall: Wall, at point: Point2D, alongSign: Double, walls: [Wall]) -> (plus: Double, minus: Double, cap: Bool) {
        let tolerance = 0.03
        let half = wall.thickness / 2
        var partners: [Point2D] = []
        var tJunction = false
        for other in walls where other.id != wall.id {
            if other.start.isClose(to: point, tolerance: tolerance) {
                partners.append(other.end)
            } else if other.end.isClose(to: point, tolerance: tolerance) {
                partners.append(other.start)
            } else if other.distance(to: point) < tolerance {
                tJunction = true
            }
        }
        let u = wall.direction * alongSign
        let n = wall.normal
        if partners.contains(where: { ($0 - point).normalized.dot(u) > 0.98 }) { return (0, 0, false) }
        if tJunction || partners.count >= 2 { return (-half, -half, false) }
        if let other = partners.first {
            let side = (other - point).normalized.dot(n)
            if abs(side) < 0.2 { return (0, 0, false) }
            return side > 0 ? (-half, half, false) : (half, -half, false)
        }
        return (0, 0, true)
    }

    /// True when the wall end touches another wall (so filled walls should extend into the joint).
    static func isJoined(_ wall: Wall, at point: Point2D, walls: [Wall]) -> Bool {
        walls.contains { other in
            other.id != wall.id && (other.start.isClose(to: point, tolerance: 0.03) ||
                other.end.isClose(to: point, tolerance: 0.03) || other.distance(to: point) < 0.03)
        }
    }
}
