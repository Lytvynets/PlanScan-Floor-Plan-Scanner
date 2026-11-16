// ASCII DXF R12 (AC1009) writer: wall outlines, doors, windows, openings, furniture, room labels and dimensions.
import Foundation

/// Builds a DXF R12 drawing in meters. DXF Y = −Z (plan y) so the drawing is not mirrored compared to the screen.
struct DXFExporter {
    var lengthLabel: (Double) -> String
    var areaLabel: (Double) -> String
    var includeFurniture = true

    static let layers: [(name: String, color: Int)] = [
        ("WALLS", 7), ("DOORS", 3), ("WINDOWS", 4), ("OPENINGS", 6),
        ("FURNITURE", 8), ("TEXT", 7), ("DIMENSIONS", 5)
    ]

    func makeDXF(plan: FloorPlanModel) -> String {
        let resolved = ResolvedPlan(plan)
        var writer = DXFWriter()
        let allWalls = resolved.walls.map(\.wall)

        var entities = DXFWriter()
        for entry in resolved.walls {
            writeWall(entry, resolved: resolved, allWalls: allWalls, into: &entities)
        }
        for entry in resolved.openings {
            writeOpening(entry, into: &entities)
        }
        if includeFurniture {
            for room in plan.rooms {
                for item in room.objects {
                    let corners = PlanGeometry.rectangleCorners(center: item.center, width: item.width,
                                                                depth: item.depth, angle: item.angle)
                    for i in corners.indices {
                        entities.line(layer: "FURNITURE", corners[i], corners[(i + 1) % corners.count])
                    }
                }
            }
        }
        for entry in resolved.walls {
            writeDimension(entry, resolved: resolved, into: &entities)
        }
        for room in plan.rooms {
            let anchor = room.labelAnchor
            let metrics = RoomMetrics(room: room)
            entities.text(layer: "TEXT", room.name, at: anchor + Point2D(x: 0, y: -0.14), height: 0.2, rotationDegrees: 0)
            entities.text(layer: "TEXT", areaLabel(metrics.floorArea), at: anchor + Point2D(x: 0, y: 0.16),
                          height: 0.14, rotationDegrees: 0)
        }

        let extents = PlanRect(points: PlanLayout.contentPoints(of: plan, rotation: 0))
            ?? PlanRect(minX: 0, minY: 0, maxX: 1, maxY: 1)
        writer.header(extents: extents.expanded(by: 1))
        writer.tables(layers: Self.layers)
        writer.pair(0, "SECTION")
        writer.pair(2, "ENTITIES")
        writer.append(entities)
        writer.pair(0, "ENDSEC")
        writer.pair(0, "EOF")
        return writer.text
    }

    // MARK: - Walls

    private func writeWall(_ entry: ResolvedPlan.WallEntry, resolved: ResolvedPlan, allWalls: [Wall], into out: inout DXFWriter) {
        let wall = entry.wall
        let length = wall.length
        let u = wall.direction
        let n = wall.normal
        let half = wall.thickness / 2
        let startJoin = WallJoins.treatment(of: wall, at: wall.start, alongSign: -1, walls: allWalls)
        let endJoin = WallJoins.treatment(of: wall, at: wall.end, alongSign: 1, walls: allWalls)

        for piece in resolved.solidIntervals(of: entry) {
            let atStart = piece.start < 0.005
            let atEnd = piece.end > length - 0.005
            for side in [1.0, -1.0] {
                let s = atStart ? -(side > 0 ? startJoin.plus : startJoin.minus) : piece.start
                let e = atEnd ? length + (side > 0 ? endJoin.plus : endJoin.minus) : piece.end
                let a = wall.start + u * s + n * (half * side)
                let b = wall.start + u * e + n * (half * side)
                out.line(layer: "WALLS", a, b)
            }
            if !atStart || startJoin.cap {
                let p = wall.start + u * piece.start
                out.line(layer: "WALLS", p + n * half, p - n * half)
            }
            if !atEnd || endJoin.cap {
                let p = wall.start + u * piece.end
                out.line(layer: "WALLS", p + n * half, p - n * half)
            }
        }
    }

    // MARK: - Openings

    private func writeOpening(_ entry: ResolvedPlan.OpeningEntry, into out: inout DXFWriter) {
        let opening = entry.opening
        let u = entry.hostWall?.direction ?? Point2D.unit(angle: opening.angle)
        let n = entry.hostWall?.normal ?? u.perpendicular
        let t = entry.hostWall?.thickness ?? 0.12
        let a = opening.center - u * (opening.width / 2)
        let b = opening.center + u * (opening.width / 2)
        switch opening.kind {
        case .door:
            let hinge = a
            let open = entry.inwardNormal
            out.line(layer: "DOORS", hinge, hinge + open * opening.width)
            let closedAngle = Self.dxfAngleDegrees(of: u)
            let openAngle = Self.dxfAngleDegrees(of: open)
            let sweep = (openAngle - closedAngle + 720).truncatingRemainder(dividingBy: 360)
            let (startAngle, endAngle) = sweep <= 180 ? (closedAngle, openAngle) : (openAngle, closedAngle)
            out.arc(layer: "DOORS", center: hinge, radius: opening.width, startDegrees: startAngle, endDegrees: endAngle)
        case .window:
            for offset in [-t / 2, 0, t / 2] {
                out.line(layer: "WINDOWS", a + n * offset, b + n * offset)
            }
        case .opening:
            out.line(layer: "OPENINGS", a, b)
        }
    }

    // MARK: - Dimensions

    private func writeDimension(_ entry: ResolvedPlan.WallEntry, resolved: ResolvedPlan, into out: inout DXFWriter) {
        let wall = entry.wall
        guard wall.length >= 0.3 else { return }
        var normal = entry.outwardNormal
        if resolved.isInsideOtherRoom(wall.midpoint + normal * 0.35, excluding: entry.roomIndex) {
            normal = -normal
        }
        let offset = normal * 0.35
        let a = wall.start + offset
        let b = wall.end + offset
        out.line(layer: "DIMENSIONS", a, b)
        let tick = normal * 0.08
        out.line(layer: "DIMENSIONS", a - tick, a + tick)
        out.line(layer: "DIMENSIONS", b - tick, b + tick)
        let textPosition = wall.midpoint + normal * 0.5
        out.text(layer: "DIMENSIONS", lengthLabel(wall.length), at: textPosition, height: 0.12,
                 rotationDegrees: Self.uprightDXFAngle(of: wall.direction))
    }

    // MARK: - Angles in DXF space (y flipped)

    static func dxfAngleDegrees(of v: Point2D) -> Double {
        var degrees = atan2(-v.y, v.x) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return degrees
    }

    /// Text rotation in DXF space, kept readable (between −90° and 90°).
    static func uprightDXFAngle(of v: Point2D) -> Double {
        var degrees = atan2(-v.y, v.x) * 180 / .pi
        if degrees > 90 { degrees -= 180 }
        if degrees <= -90 { degrees += 180 }
        return degrees
    }
}

/// Low-level DXF group code writer. Group codes and values alternate on separate lines.
struct DXFWriter {
    private(set) var lines: [String] = []

    var text: String { lines.joined(separator: "\n") + "\n" }

    mutating func pair(_ code: Int, _ value: String) {
        lines.append(String(format: "%3d", code))
        lines.append(value)
    }

    mutating func pair(_ code: Int, _ value: Double) {
        pair(code, String(format: "%.4f", value.isFinite ? value : 0))
    }

    mutating func pair(_ code: Int, _ value: Int) {
        pair(code, String(format: "%6d", value))
    }

    mutating func append(_ other: DXFWriter) {
        lines.append(contentsOf: other.lines)
    }

    /// Plan point → DXF point (y flipped).
    private mutating func point(_ p: Point2D, codes: (Int, Int, Int)) {
        pair(codes.0, p.x)
        pair(codes.1, -p.y)
        pair(codes.2, 0.0)
    }

    mutating func header(extents: PlanRect) {
        pair(0, "SECTION")
        pair(2, "HEADER")
        pair(9, "$ACADVER")
        pair(1, "AC1009")
        pair(9, "$INSUNITS")
        pair(70, 6)
        pair(9, "$DWGCODEPAGE")
        pair(3, "ANSI_1252")
        pair(9, "$EXTMIN")
        point(Point2D(x: extents.minX, y: extents.maxY), codes: (10, 20, 30))
        pair(9, "$EXTMAX")
        point(Point2D(x: extents.maxX, y: extents.minY), codes: (10, 20, 30))
        pair(0, "ENDSEC")
    }

    mutating func tables(layers: [(name: String, color: Int)]) {
        pair(0, "SECTION")
        pair(2, "TABLES")

        pair(0, "TABLE")
        pair(2, "LTYPE")
        pair(70, 1)
        pair(0, "LTYPE")
        pair(2, "CONTINUOUS")
        pair(70, 0)
        pair(3, "Solid line")
        pair(72, 65)
        pair(73, 0)
        pair(40, 0.0)
        pair(0, "ENDTAB")

        pair(0, "TABLE")
        pair(2, "LAYER")
        pair(70, layers.count + 1)
        for (name, color) in [("0", 7)] + layers {
            pair(0, "LAYER")
            pair(2, name)
            pair(70, 0)
            pair(62, color)
            pair(6, "CONTINUOUS")
        }
        pair(0, "ENDTAB")

        pair(0, "TABLE")
        pair(2, "STYLE")
        pair(70, 1)
        pair(0, "STYLE")
        pair(2, "STANDARD")
        pair(70, 0)
        pair(40, 0.0)
        pair(41, 1.0)
        pair(50, 0.0)
        pair(71, 0)
        pair(42, 0.2)
        pair(3, "txt")
        pair(4, "")
        pair(0, "ENDTAB")

        pair(0, "ENDSEC")
    }

    mutating func line(layer: String, _ a: Point2D, _ b: Point2D) {
        guard a.distance(to: b) > 1e-6 else { return }
        pair(0, "LINE")
        pair(8, layer)
        point(a, codes: (10, 20, 30))
        point(b, codes: (11, 21, 31))
    }

    mutating func arc(layer: String, center: Point2D, radius: Double, startDegrees: Double, endDegrees: Double) {
        pair(0, "ARC")
        pair(8, layer)
        point(center, codes: (10, 20, 30))
        pair(40, radius)
        pair(50, startDegrees)
        pair(51, endDegrees)
    }

    /// Centered single-line text.
    mutating func text(layer: String, _ string: String, at position: Point2D, height: Double, rotationDegrees: Double) {
        let value = Self.encode(string)
        guard !value.isEmpty else { return }
        pair(0, "TEXT")
        pair(8, layer)
        point(position, codes: (10, 20, 30))
        pair(40, height)
        pair(1, value)
        pair(50, rotationDegrees)
        pair(72, 1)
        point(position, codes: (11, 21, 31))
        pair(73, 2)
    }

    /// R12 text is code-page based; non-ASCII characters are written as \U+XXXX escapes.
    static func encode(_ string: String) -> String {
        var result = ""
        for scalar in string.unicodeScalars {
            switch scalar.value {
            case 0x20..<0x7F:
                result.unicodeScalars.append(scalar)
            case 0x7F...0xFFFF:
                result += String(format: "\\U+%04X", scalar.value)
            default:
                continue
            }
        }
        return result
    }
}
