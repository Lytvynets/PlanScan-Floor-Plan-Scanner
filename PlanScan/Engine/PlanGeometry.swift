// Pure 2D geometry helpers: vector math, polygons, corner snapping and wall chaining.
import Foundation

extension Point2D {
    static func + (lhs: Point2D, rhs: Point2D) -> Point2D { Point2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: Point2D, rhs: Point2D) -> Point2D { Point2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: Point2D, rhs: Double) -> Point2D { Point2D(x: lhs.x * rhs, y: lhs.y * rhs) }
    static func * (lhs: Double, rhs: Point2D) -> Point2D { Point2D(x: lhs * rhs.x, y: lhs * rhs.y) }
    static func / (lhs: Point2D, rhs: Double) -> Point2D { Point2D(x: lhs.x / rhs, y: lhs.y / rhs) }
    static prefix func - (point: Point2D) -> Point2D { Point2D(x: -point.x, y: -point.y) }

    var length: Double { (x * x + y * y).squareRoot() }

    var normalized: Point2D {
        let len = length
        return len > 1e-9 ? self / len : Point2D(x: 1, y: 0)
    }

    func dot(_ other: Point2D) -> Double { x * other.x + y * other.y }
    func cross(_ other: Point2D) -> Double { x * other.y - y * other.x }
    func distance(to other: Point2D) -> Double { (self - other).length }

    /// Perpendicular vector (rotated by +90°).
    var perpendicular: Point2D { Point2D(x: -y, y: x) }

    func rotated(by angle: Double) -> Point2D {
        let c = cos(angle), s = sin(angle)
        return Point2D(x: x * c - y * s, y: x * s + y * c)
    }

    func rotated(by angle: Double, around pivot: Point2D) -> Point2D {
        (self - pivot).rotated(by: angle) + pivot
    }

    func isClose(to other: Point2D, tolerance: Double) -> Bool { distance(to: other) <= tolerance }

    static func unit(angle: Double) -> Point2D { Point2D(x: cos(angle), y: sin(angle)) }
}

/// Axis-aligned bounds in plan space (meters).
struct PlanRect: Hashable {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    init?(points: [Point2D]) {
        guard let first = points.first else { return nil }
        var rect = PlanRect(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        for p in points.dropFirst() {
            rect.minX = min(rect.minX, p.x)
            rect.minY = min(rect.minY, p.y)
            rect.maxX = max(rect.maxX, p.x)
            rect.maxY = max(rect.maxY, p.y)
        }
        self = rect
    }

    var width: Double { maxX - minX }
    var height: Double { maxY - minY }
    var center: Point2D { Point2D(x: (minX + maxX) / 2, y: (minY + maxY) / 2) }

    func union(_ other: PlanRect) -> PlanRect {
        PlanRect(minX: min(minX, other.minX), minY: min(minY, other.minY),
                 maxX: max(maxX, other.maxX), maxY: max(maxY, other.maxY))
    }

    func expanded(by amount: Double) -> PlanRect {
        PlanRect(minX: minX - amount, minY: minY - amount, maxX: maxX + amount, maxY: maxY + amount)
    }

    func contains(_ point: Point2D) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

extension Wall {
    var length: Double { start.distance(to: end) }
    var vector: Point2D { end - start }
    var direction: Point2D { vector.normalized }
    var normal: Point2D { direction.perpendicular }
    var midpoint: Point2D { (start + end) / 2 }
    var angle: Double { atan2(end.y - start.y, end.x - start.x) }

    func point(at distanceFromStart: Double) -> Point2D { start + direction * distanceFromStart }
    func distanceAlong(_ point: Point2D) -> Double { (point - start).dot(direction) }
    func distance(to point: Point2D) -> Double {
        PlanGeometry.distance(from: point, toSegmentFrom: start, to: end)
    }
}

enum PlanGeometry {
    static func signedArea(_ points: [Point2D]) -> Double {
        guard points.count >= 3 else { return 0 }
        var sum = 0.0
        for i in points.indices {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }

    /// Floor area with the shoelace formula (absolute value).
    static func area(_ points: [Point2D]) -> Double { abs(signedArea(points)) }

    static func perimeter(_ points: [Point2D]) -> Double {
        guard points.count >= 2 else { return 0 }
        var sum = 0.0
        for i in points.indices {
            sum += points[i].distance(to: points[(i + 1) % points.count])
        }
        return sum
    }

    static func average(_ points: [Point2D]) -> Point2D {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(Point2D.zero) { $0 + $1 }
        return sum / Double(points.count)
    }

    static func centroid(_ points: [Point2D]) -> Point2D {
        let area = signedArea(points)
        guard abs(area) > 1e-9 else { return average(points) }
        var cx = 0.0, cy = 0.0
        for i in points.indices {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            let f = a.x * b.y - b.x * a.y
            cx += (a.x + b.x) * f
            cy += (a.y + b.y) * f
        }
        return Point2D(x: cx / (6 * area), y: cy / (6 * area))
    }

    /// Even-odd ray casting.
    static func contains(_ point: Point2D, in polygon: [Point2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let pi = polygon[i], pj = polygon[j]
            if (pi.y > point.y) != (pj.y > point.y) {
                let xCross = (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x
                if point.x < xCross { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    static func distance(from point: Point2D, toSegmentFrom a: Point2D, to b: Point2D) -> Double {
        let ab = b - a
        let lengthSquared = ab.dot(ab)
        guard lengthSquared > 1e-12 else { return point.distance(to: a) }
        let t = min(max((point - a).dot(ab) / lengthSquared, 0), 1)
        return point.distance(to: a + ab * t)
    }

    static func distanceToEdges(_ point: Point2D, polygon: [Point2D]) -> Double {
        guard polygon.count >= 2 else { return .infinity }
        var best = Double.infinity
        for i in polygon.indices {
            best = min(best, distance(from: point, toSegmentFrom: polygon[i], to: polygon[(i + 1) % polygon.count]))
        }
        return best
    }

    /// A good interior point for a label: the area centroid when it lies inside, otherwise
    /// an approximation of the pole of inaccessibility found with a grid search.
    static func labelAnchor(for polygon: [Point2D]) -> Point2D {
        guard polygon.count >= 3, let bounds = PlanRect(points: polygon) else { return average(polygon) }
        let c = centroid(polygon)
        let centroidClearance = contains(c, in: polygon) ? distanceToEdges(c, polygon: polygon) : -1
        var best = c
        var bestScore = -1.0
        let steps = 24
        for ix in 0...steps {
            for iy in 0...steps {
                let p = Point2D(x: bounds.minX + bounds.width * Double(ix) / Double(steps),
                                y: bounds.minY + bounds.height * Double(iy) / Double(steps))
                guard contains(p, in: polygon) else { continue }
                let score = distanceToEdges(p, polygon: polygon)
                if score > bestScore {
                    bestScore = score
                    best = p
                }
            }
        }
        // Prefer the centroid when it is comfortably inside: it reads more naturally for simple rooms.
        if centroidClearance >= 0, centroidClearance >= bestScore * 0.6 { return c }
        return bestScore > 0 ? best : c
    }

    /// Monotone chain convex hull, counter-clockwise in a y-up frame.
    static func convexHull(_ points: [Point2D]) -> [Point2D] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard sorted.count >= 3 else { return sorted }
        func turn(_ o: Point2D, _ a: Point2D, _ b: Point2D) -> Double { (a - o).cross(b - o) }
        var lower: [Point2D] = []
        for p in sorted {
            while lower.count >= 2 && turn(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [Point2D] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && turn(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    /// Corners of a rotated rectangle (width along `angle`, depth perpendicular).
    static func rectangleCorners(center: Point2D, width: Double, depth: Double, angle: Double) -> [Point2D] {
        let u = Point2D.unit(angle: angle) * (width / 2)
        let v = Point2D.unit(angle: angle).perpendicular * (depth / 2)
        return [center - u - v, center + u - v, center + u + v, center - u + v]
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    /// Maps an angle into (-π/2, π/2] so a line direction never renders upside down.
    static func normalizedLineAngle(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: .pi)
        if a <= -Double.pi / 2 { a += .pi }
        if a > Double.pi / 2 { a -= .pi }
        return a
    }

    /// Clusters wall endpoints closer than `tolerance`, replaces each cluster by its average
    /// and removes walls that became (almost) zero length.
    static func snapCorners(_ walls: [Wall], tolerance: Double = 0.15) -> [Wall] {
        var points: [Point2D] = []
        for wall in walls {
            points.append(wall.start)
            points.append(wall.end)
        }
        guard !points.isEmpty else { return walls }
        var parent = Array(points.indices)
        func find(_ i: Int) -> Int {
            var root = i
            while parent[root] != root { root = parent[root] }
            var node = i
            while parent[node] != root {
                let next = parent[node]
                parent[node] = root
                node = next
            }
            return root
        }
        for i in points.indices {
            for j in (i + 1)..<points.count where points[i].distance(to: points[j]) < tolerance {
                let ri = find(i), rj = find(j)
                if ri != rj { parent[rj] = ri }
            }
        }
        var sums: [Int: (Point2D, Int)] = [:]
        for i in points.indices {
            let root = find(i)
            let current = sums[root] ?? (.zero, 0)
            sums[root] = (current.0 + points[i], current.1 + 1)
        }
        var snapped = walls
        for (index, _) in walls.enumerated() {
            if let s = sums[find(index * 2)] { snapped[index].start = s.0 / Double(s.1) }
            if let e = sums[find(index * 2 + 1)] { snapped[index].end = e.0 / Double(e.1) }
        }
        return snapped.filter { $0.length > 0.01 }
    }

    /// Chains wall endpoints into a closed loop. Returns nil when the walls do not form a loop.
    static func chainWalls(_ walls: [Wall], tolerance: Double = 0.2) -> [Point2D]? {
        guard walls.count >= 3, let first = walls.first else { return nil }
        var used = Set<Int>([0])
        var loop: [Point2D] = [first.start, first.end]
        var current = first.end
        while true {
            var nextIndex: Int?
            var nextPoint = Point2D.zero
            var bestDistance = tolerance
            for (i, wall) in walls.enumerated() where !used.contains(i) {
                let ds = wall.start.distance(to: current)
                let de = wall.end.distance(to: current)
                if ds <= bestDistance { bestDistance = ds; nextIndex = i; nextPoint = wall.end }
                if de <= bestDistance { bestDistance = de; nextIndex = i; nextPoint = wall.start }
            }
            guard let index = nextIndex else { break }
            used.insert(index)
            current = nextPoint
            if current.distance(to: loop[0]) <= tolerance {
                return loop.count >= 3 ? loop : nil
            }
            loop.append(current)
        }
        if loop.count >= 3, current.distance(to: loop[0]) <= tolerance * 2 {
            loop.removeLast()
            return loop.count >= 3 ? loop : nil
        }
        return nil
    }
}
