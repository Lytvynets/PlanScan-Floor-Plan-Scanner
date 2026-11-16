// Plan-to-canvas layout: orientation (longest wall horizontal + user rotation), fit-to-rect and fixed true scale.
import Foundation

/// A 2D affine transform with the same layout and semantics as CGAffineTransform:
/// x' = a·x + c·y + tx, y' = b·x + d·y + ty.
struct Affine2D: Hashable {
    var a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double

    static let identity = Affine2D(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    static func translation(_ x: Double, _ y: Double) -> Affine2D { Affine2D(a: 1, b: 0, c: 0, d: 1, tx: x, ty: y) }
    static func scale(_ s: Double) -> Affine2D { Affine2D(a: s, b: 0, c: 0, d: s, tx: 0, ty: 0) }
    static func rotation(_ angle: Double) -> Affine2D {
        Affine2D(a: cos(angle), b: sin(angle), c: -sin(angle), d: cos(angle), tx: 0, ty: 0)
    }

    /// Applies `self` first, then `other` (same as CGAffineTransform.concatenating).
    func concatenating(_ other: Affine2D) -> Affine2D {
        Affine2D(a: a * other.a + b * other.c,
                 b: a * other.b + b * other.d,
                 c: c * other.a + d * other.c,
                 d: c * other.b + d * other.d,
                 tx: tx * other.a + ty * other.c + other.tx,
                 ty: tx * other.b + ty * other.d + other.ty)
    }

    func apply(_ p: Point2D) -> Point2D {
        Point2D(x: a * p.x + c * p.y + tx, y: b * p.x + d * p.y + ty)
    }

    /// Applies only the linear part (for direction vectors).
    func applyToVector(_ v: Point2D) -> Point2D {
        Point2D(x: a * v.x + c * v.y, y: b * v.x + d * v.y)
    }

    var determinant: Double { a * d - b * c }

    /// Uniform scale factor of the transform.
    var scaleFactor: Double { abs(determinant).squareRoot() }

    var inverted: Affine2D? {
        let det = determinant
        guard abs(det) > 1e-12 else { return nil }
        return Affine2D(a: d / det, b: -b / det, c: -c / det, d: a / det,
                        tx: (c * ty - d * tx) / det, ty: (b * tx - a * ty) / det)
    }
}

/// A rectangle in canvas points.
struct CanvasRect: Hashable {
    var x: Double, y: Double, width: Double, height: Double
    var midX: Double { x + width / 2 }
    var midY: Double { y + height / 2 }
}

struct PlanLayout: Hashable {
    /// Plan meters → canvas points.
    let transform: Affine2D
    /// Canvas points per plan meter.
    let pointsPerMeter: Double
    /// Total rotation applied to the plan (radians).
    let rotation: Double

    /// Extra margin (meters) kept around the geometry for dimension lines and their labels.
    static let annotationMargin = 0.8

    /// Rotation that makes the longest wall horizontal, plus the user's 90° steps.
    static func rotation(for plan: FloorPlanModel) -> Double {
        let walls = plan.rooms.flatMap(\.walls)
        var base = 0.0
        if let longest = walls.max(by: { $0.length < $1.length }), longest.length > 0.01 {
            base = -PlanGeometry.normalizedLineAngle(longest.angle)
        }
        return base + plan.rotationDegrees * .pi / 180
    }

    /// All points that should be visible, rotated by `rotation`.
    static func contentPoints(of plan: FloorPlanModel, rotation: Double) -> [Point2D] {
        var points: [Point2D] = []
        for room in plan.rooms {
            for wall in room.walls {
                let n = wall.normal * (wall.thickness / 2)
                points.append(contentsOf: [wall.start + n, wall.start - n, wall.end + n, wall.end - n])
            }
            points.append(contentsOf: room.floorPolygon)
            for item in room.objects {
                points.append(contentsOf: PlanGeometry.rectangleCorners(center: item.center, width: item.width,
                                                                        depth: item.depth, angle: item.angle))
            }
        }
        return points.map { $0.rotated(by: rotation) }
    }

    static func contentBounds(of plan: FloorPlanModel, rotation: Double, includeAnnotations: Bool) -> PlanRect {
        var bounds = PlanRect(points: contentPoints(of: plan, rotation: rotation))
            ?? PlanRect(minX: -2, minY: -2, maxX: 2, maxY: 2)
        if bounds.width < 1 { bounds = bounds.union(PlanRect(minX: bounds.center.x - 0.5, minY: bounds.minY, maxX: bounds.center.x + 0.5, maxY: bounds.maxY)) }
        if bounds.height < 1 { bounds = bounds.union(PlanRect(minX: bounds.minX, minY: bounds.center.y - 0.5, maxX: bounds.maxX, maxY: bounds.center.y + 0.5)) }
        return includeAnnotations ? bounds.expanded(by: annotationMargin) : bounds
    }

    private static func make(rotation: Double, scale: Double, contentCenter: Point2D, canvasCenter: Point2D) -> PlanLayout {
        let transform = Affine2D.rotation(rotation)
            .concatenating(.translation(-contentCenter.x, -contentCenter.y))
            .concatenating(.scale(scale))
            .concatenating(.translation(canvasCenter.x, canvasCenter.y))
        return PlanLayout(transform: transform, pointsPerMeter: scale, rotation: rotation)
    }

    /// Fits the plan into `rect` with `padding` (fraction of each side), keeping the aspect ratio.
    static func fit(_ plan: FloorPlanModel, in rect: CanvasRect, padding: Double = 0.08,
                    includeAnnotations: Bool = true) -> PlanLayout {
        let rotation = rotation(for: plan)
        let bounds = contentBounds(of: plan, rotation: rotation, includeAnnotations: includeAnnotations)
        let availableWidth = max(1, rect.width * (1 - 2 * padding))
        let availableHeight = max(1, rect.height * (1 - 2 * padding))
        let scale = max(0.0001, min(availableWidth / bounds.width, availableHeight / bounds.height))
        return make(rotation: rotation, scale: scale, contentCenter: bounds.center,
                    canvasCenter: Point2D(x: rect.midX, y: rect.midY))
    }

    /// Centers the plan in `rect` at a fixed scale (used for true-scale PDF output).
    static func fixedScale(_ plan: FloorPlanModel, pointsPerMeter: Double, in rect: CanvasRect,
                           includeAnnotations: Bool = true) -> PlanLayout {
        let rotation = rotation(for: plan)
        let bounds = contentBounds(of: plan, rotation: rotation, includeAnnotations: includeAnnotations)
        return make(rotation: rotation, scale: pointsPerMeter, contentCenter: bounds.center,
                    canvasCenter: Point2D(x: rect.midX, y: rect.midY))
    }

    /// Same layout followed by an extra canvas-space transform (zoom/pan of the interactive view).
    func applying(_ view: Affine2D) -> PlanLayout {
        PlanLayout(transform: transform.concatenating(view),
                   pointsPerMeter: pointsPerMeter * view.scaleFactor, rotation: rotation)
    }
}

/// Standard architectural scales for true-scale PDF pages.
enum PlanScale {
    static let standard = [20, 25, 50, 75, 100, 200]

    /// PDF points per real meter at 1:N (1 m on paper = 1000/N mm).
    static func pointsPerMeter(denominator n: Int) -> Double {
        (1000.0 / Double(n)) / 25.4 * 72.0
    }

    /// The smallest standard N whose drawing of the given extents fits the available area, or nil when none fits.
    static func bestDenominator(contentWidth: Double, contentHeight: Double,
                                availableWidth: Double, availableHeight: Double) -> Int? {
        standard.first { n in
            let ppm = pointsPerMeter(denominator: n)
            return contentWidth * ppm <= availableWidth && contentHeight * ppm <= availableHeight
        }
    }
}
