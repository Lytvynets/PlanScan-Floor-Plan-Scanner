// Core Graphics floor plan renderer: the single source of truth for the screen, PNG, PDF and thumbnails.
import UIKit

enum FloorPlanDrawer {
    /// Fits the plan into `rect` (8% padding, longest wall horizontal) and applies `viewTransform` (zoom/pan).
    static func draw(_ plan: FloorPlanModel, in ctx: CGContext, rect: CGRect, style: PlanStyle, layers: PlanLayers,
                     units: UnitSystem, viewTransform: CGAffineTransform = .identity, selection: UUID? = nil) {
        let layout = PlanLayout.fit(plan, in: CanvasRect(rect), padding: 0.08, includeAnnotations: layers.dimensions)
            .applying(Affine2D(viewTransform))
        draw(plan, in: ctx, rect: rect, layout: layout, style: style, layers: layers,
             formatter: UnitFormatter.localized(units), selection: selection)
    }

    /// Draws with an explicit layout (fixed true scale for PDF pages).
    static func draw(_ plan: FloorPlanModel, in ctx: CGContext, rect: CGRect, layout: PlanLayout, style: PlanStyle,
                     layers: PlanLayers, formatter: UnitFormatter, selection: UUID? = nil) {
        UIGraphicsPushContext(ctx)
        defer { UIGraphicsPopContext() }
        ctx.saveGState()
        defer { ctx.restoreGState() }
        if let background = style.background {
            ctx.setFillColor(background.cgColor)
            ctx.fill(rect)
        }
        ctx.clip(to: rect)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let renderer = PlanRenderer(ctx: ctx, rect: rect, layout: layout, style: style, layers: layers,
                                    formatter: formatter, selection: selection, resolved: ResolvedPlan(plan))
        if layers.grid { renderer.drawGrid() }
        if layers.floorFill { renderer.drawFloors() }
        if layers.furniture { renderer.drawFurniture() }
        renderer.drawWalls()
        if layers.openings { renderer.drawOpenings() }
        if layers.dimensions { renderer.drawDimensions() }
        if layers.labels { renderer.drawLabels() }
        if layers.scaleBar { renderer.drawScaleBar() }
    }
}

/// One drawing pass; all geometry is transformed to canvas points before stroking so line widths and
/// text sizes stay constant in points regardless of zoom.
struct PlanRenderer {
    let ctx: CGContext
    let rect: CGRect
    let layout: PlanLayout
    let style: PlanStyle
    let layers: PlanLayers
    let formatter: UnitFormatter
    let selection: UUID?
    let resolved: ResolvedPlan

    var scale: CGFloat { CGFloat(layout.pointsPerMeter) }

    func pt(_ p: Point2D) -> CGPoint {
        let q = layout.transform.apply(p)
        return CGPoint(x: q.x, y: q.y)
    }

    // MARK: Grid

    func drawGrid() {
        guard let inverse = layout.transform.inverted else { return }
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
            .map { inverse.apply(Point2D(x: Double($0.x), y: Double($0.y))) }
        guard let bounds = PlanRect(points: corners) else { return }
        let spacing = formatter.gridSpacing
        let useMinor = spacing.minor * Double(scale) >= 7
        let step = useMinor ? spacing.minor : spacing.major
        guard step * Double(scale) >= 6 else { return }
        let minorPath = CGMutablePath()
        let majorPath = CGMutablePath()
        func isMajor(_ value: Double) -> Bool {
            let ratio = value / spacing.major
            return abs(ratio - ratio.rounded()) < 1e-6
        }
        var x = (bounds.minX / step).rounded(.down) * step
        var count = 0
        while x <= bounds.maxX && count < 600 {
            let path = isMajor(x) ? majorPath : minorPath
            path.move(to: pt(Point2D(x: x, y: bounds.minY)))
            path.addLine(to: pt(Point2D(x: x, y: bounds.maxY)))
            x += step
            count += 1
        }
        var y = (bounds.minY / step).rounded(.down) * step
        count = 0
        while y <= bounds.maxY && count < 600 {
            let path = isMajor(y) ? majorPath : minorPath
            path.move(to: pt(Point2D(x: bounds.minX, y: y)))
            path.addLine(to: pt(Point2D(x: bounds.maxX, y: y)))
            y += step
            count += 1
        }
        ctx.setLineWidth(0.5 * style.lineScale)
        ctx.setStrokeColor(style.grid.cgColor)
        ctx.addPath(minorPath)
        ctx.strokePath()
        ctx.setLineWidth(0.9 * style.lineScale)
        ctx.setStrokeColor(style.gridMajor.cgColor)
        ctx.addPath(majorPath)
        ctx.strokePath()
    }

    // MARK: Floors

    func drawFloors() {
        for room in resolved.rooms {
            let outline = room.outline
            guard outline.count >= 3 else { continue }
            let path = CGMutablePath()
            path.addLines(between: outline.map(pt))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.setFillColor(room.type.uiTint.withAlphaComponent(style.floorFillOpacity).cgColor)
            ctx.fillPath()
        }
    }

    // MARK: Furniture

    func drawFurniture() {
        for room in resolved.rooms {
            for item in room.objects {
                let center = pt(item.center)
                let axis = layout.transform.applyToVector(Point2D.unit(angle: item.angle))
                let angle = CGFloat(atan2(axis.y, axis.x))
                let width = CGFloat(item.width) * scale
                let depth = CGFloat(item.depth) * scale
                guard width >= 2 || depth >= 2 else { continue }
                let radius = min(min(width, depth) * 0.18, 6)
                let path = CGMutablePath()
                let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
                path.addRoundedRect(in: CGRect(x: -width / 2, y: -depth / 2, width: width, height: depth),
                                    cornerWidth: radius, cornerHeight: radius, transform: transform)
                let isSelected = item.id == selection
                ctx.addPath(path)
                ctx.setFillColor((isSelected ? style.selection.withAlphaComponent(0.25) : style.furnitureFill).cgColor)
                ctx.fillPath()
                ctx.addPath(path)
                ctx.setStrokeColor((isSelected ? style.selection : style.furnitureStroke).cgColor)
                ctx.setLineWidth((isSelected ? 2 : 0.9) * style.lineScale)
                ctx.strokePath()
                let iconSize = min(min(width, depth) * 0.5, 26 * style.fontScale)
                if iconSize >= 8 {
                    drawSymbol(item.category.symbolName, at: center, pointSize: iconSize,
                               color: isSelected ? style.selection : style.furnitureIcon)
                }
            }
        }
    }

    private func drawSymbol(_ name: String, at center: CGPoint, pointSize: CGFloat, color: UIColor) {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        let base = UIImage(systemName: name, withConfiguration: configuration)
            ?? UIImage(systemName: "cube.fill", withConfiguration: configuration)
        guard let image = base?.withTintColor(color, renderingMode: .alwaysOriginal) else { return }
        let size = image.size
        image.draw(in: CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                              width: size.width, height: size.height))
    }

    // MARK: Walls

    func drawWalls() {
        let allWalls = resolved.walls.map(\.wall)
        for entry in resolved.walls {
            let wall = entry.wall
            let length = wall.length
            let pieces = layers.openings ? resolved.solidIntervals(of: entry) : [WallInterval(start: 0, end: length)]
            let screenHalf = max(1.5, CGFloat(wall.thickness / 2) * scale)
            let halfMeters = Double(screenHalf / max(scale, 0.0001))
            let startJoined = WallJoins.isJoined(wall, at: wall.start, walls: allWalls)
            let endJoined = WallJoins.isJoined(wall, at: wall.end, walls: allWalls)
            let isSelected = wall.id == selection
            ctx.setFillColor((isSelected ? style.selection : style.walls).cgColor)
            for piece in pieces {
                var s = piece.start
                var e = piece.end
                if s < 0.005 && startJoined { s -= halfMeters }
                if e > length - 0.005 && endJoined { e += halfMeters }
                let a = pt(wall.point(at: s))
                let b = pt(wall.point(at: e))
                guard let n = (b - a).unitNormal else { continue }
                let offset = n * screenHalf
                let path = CGMutablePath()
                path.addLines(between: [a + offset, b + offset, b - offset, a - offset])
                path.closeSubpath()
                ctx.addPath(path)
                ctx.fillPath()
            }
        }
    }

    // MARK: Openings

    func drawOpenings() {
        for entry in resolved.openings {
            let opening = entry.opening
            let u = entry.hostWall?.direction ?? Point2D.unit(angle: opening.angle)
            let a = opening.center - u * (opening.width / 2)
            let b = opening.center + u * (opening.width / 2)
            let thickness = entry.hostWall?.thickness ?? 0.12
            let screenHalf = max(1.5, CGFloat(thickness / 2) * scale)
            let isSelected = opening.id == selection
            let color = isSelected ? style.selection : style.openings
            switch opening.kind {
            case .door:
                let hinge = pt(a)
                let leafEnd = pt(a + entry.inwardNormal * opening.width)
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(1.8 * style.lineScale)
                ctx.move(to: hinge)
                ctx.addLine(to: leafEnd)
                ctx.strokePath()
                let closed = pt(b) - hinge
                let open = leafEnd - hinge
                let radius = closed.length
                let startAngle = atan2(closed.y, closed.x)
                var delta = atan2(open.y, open.x) - startAngle
                while delta > .pi { delta -= 2 * .pi }
                while delta <= -.pi { delta += 2 * .pi }
                let arc = CGMutablePath()
                let steps = 24
                for i in 0...steps {
                    let angle = startAngle + delta * CGFloat(i) / CGFloat(steps)
                    let p = CGPoint(x: hinge.x + cos(angle) * radius, y: hinge.y + sin(angle) * radius)
                    if i == 0 { arc.move(to: p) } else { arc.addLine(to: p) }
                }
                ctx.addPath(arc)
                ctx.setStrokeColor(color.withAlphaComponent(0.8).cgColor)
                ctx.setLineWidth(0.9 * style.lineScale)
                ctx.strokePath()
            case .window:
                let pa = pt(a)
                let pb = pt(b)
                guard let n = (pb - pa).unitNormal else { continue }
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(1.0 * style.lineScale)
                for factor in [-0.75, 0.0, 0.75] {
                    let offset = n * (screenHalf * CGFloat(factor))
                    ctx.move(to: pa + offset)
                    ctx.addLine(to: pb + offset)
                }
                for end in [pa, pb] {
                    ctx.move(to: end + n * screenHalf)
                    ctx.addLine(to: end - n * screenHalf)
                }
                ctx.strokePath()
            case .opening:
                continue
            }
        }
    }
}

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }

    var length: CGFloat { (x * x + y * y).squareRoot() }

    /// Unit vector perpendicular to this direction vector, or nil for a zero vector.
    var unitNormal: CGPoint? {
        let len = length
        guard len > 1e-6 else { return nil }
        return CGPoint(x: -y / len, y: x / len)
    }

    var unit: CGPoint? {
        let len = length
        guard len > 1e-6 else { return nil }
        return CGPoint(x: x / len, y: y / len)
    }
}

extension CanvasRect {
    init(_ rect: CGRect) {
        self.init(x: Double(rect.origin.x), y: Double(rect.origin.y), width: Double(rect.width), height: Double(rect.height))
    }
}

extension Affine2D {
    init(_ t: CGAffineTransform) {
        self.init(a: Double(t.a), b: Double(t.b), c: Double(t.c), d: Double(t.d), tx: Double(t.tx), ty: Double(t.ty))
    }

    var cgAffineTransform: CGAffineTransform {
        CGAffineTransform(a: CGFloat(a), b: CGFloat(b), c: CGFloat(c), d: CGFloat(d), tx: CGFloat(tx), ty: CGFloat(ty))
    }
}
