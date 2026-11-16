// Raster output of the plan renderer (thumbnails, PNG export with optional watermark) and screen-space hit testing.
import UIKit

enum PlanImageRenderer {
    /// Thumbnail image (transparent background unless the style has one).
    static func thumbnail(for plan: FloorPlanModel, size: CGSize, style: PlanStyle = PlanStyle.blueprint.transparent(),
                          scale: CGFloat = 2) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = style.background != nil
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            FloorPlanDrawer.draw(plan, in: context.cgContext, rect: CGRect(origin: .zero, size: size), style: style,
                                 layers: .thumbnail, units: .metric)
        }
    }

    /// PNG export at 3× with a title line; Free users get a "Made with PlanScan" watermark.
    static func png(for plan: FloorPlanModel, title: String, subtitle: String, style: PlanStyle, layers: PlanLayers,
                    formatter: UnitFormatter, watermark: Bool) -> Data {
        let rotation = PlanLayout.rotation(for: plan)
        let bounds = PlanLayout.contentBounds(of: plan, rotation: rotation, includeAnnotations: layers.dimensions)
        let aspect = max(0.6, min(1.6, bounds.width / max(bounds.height, 0.1)))
        let width: CGFloat = 1200
        let header: CGFloat = 86
        let planHeight = width / CGFloat(aspect)
        let size = CGSize(width: width, height: planHeight + header)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let ctx = context.cgContext
            let background = style.background ?? .white
            ctx.setFillColor(background.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            let titleFont = UIFont.systemFont(ofSize: 30, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 18, weight: .medium)
            (title as NSString).draw(at: CGPoint(x: 36, y: 22), withAttributes: [.font: titleFont, .foregroundColor: style.label])
            (subtitle as NSString).draw(at: CGPoint(x: 36, y: 58),
                                        withAttributes: [.font: subtitleFont, .foregroundColor: style.labelSecondary])
            let planRect = CGRect(x: 0, y: header, width: width, height: planHeight)
            var scaled = style.scaled(font: 1.6, line: 1.5)
            scaled.background = background
            let layout = PlanLayout.fit(plan, in: CanvasRect(planRect), padding: 0.06, includeAnnotations: layers.dimensions)
            FloorPlanDrawer.draw(plan, in: ctx, rect: planRect, layout: layout, style: scaled, layers: layers,
                                 formatter: formatter, selection: nil)
            if watermark {
                drawWatermark(in: ctx, size: size, dark: style.background != .white)
            }
        }
        return image.pngData() ?? Data()
    }

    private static func drawWatermark(in ctx: CGContext, size: CGSize, dark: Bool) {
        UIGraphicsPushContext(ctx)
        defer { UIGraphicsPopContext() }
        let text = String(localized: "Made with PlanScan")
        let font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        let color = dark ? UIColor(white: 1, alpha: 0.55) : UIColor(white: 0, alpha: 0.45)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let box = CGRect(x: size.width - textSize.width - 64, y: size.height - textSize.height - 40,
                         width: textSize.width + 32, height: textSize.height + 16)
        ctx.addPath(CGPath(roundedRect: box, cornerWidth: box.height / 2, cornerHeight: box.height / 2, transform: nil))
        ctx.setFillColor((dark ? UIColor(white: 0, alpha: 0.35) : UIColor(white: 1, alpha: 0.7)).cgColor)
        ctx.fillPath()
        (text as NSString).draw(at: CGPoint(x: box.minX + 16, y: box.minY + 8), withAttributes: [.font: font, .foregroundColor: color])
    }
}

/// Finds the wall or object under a touch in canvas coordinates.
enum PlanHitTester {
    enum Hit: Hashable {
        case wall(roomIndex: Int, wallID: UUID)
        case object(roomIndex: Int, objectID: UUID)

        var elementID: UUID {
            switch self {
            case .wall(_, let id): id
            case .object(_, let id): id
            }
        }
    }

    static func hitTest(_ point: CGPoint, plan: FloorPlanModel, layout: PlanLayout, includeFurniture: Bool,
                        wallTolerance: CGFloat = 12) -> Hit? {
        if includeFurniture, let inverse = layout.transform.inverted {
            let planPoint = inverse.apply(Point2D(x: Double(point.x), y: Double(point.y)))
            for (roomIndex, room) in plan.rooms.enumerated() {
                for item in room.objects.reversed() {
                    let local = (planPoint - item.center).rotated(by: -item.angle)
                    if abs(local.x) <= item.width / 2 && abs(local.y) <= item.depth / 2 {
                        return .object(roomIndex: roomIndex, objectID: item.id)
                    }
                }
            }
        }
        var best: Hit?
        var bestDistance = wallTolerance
        for (roomIndex, room) in plan.rooms.enumerated() {
            for wall in room.walls {
                let a = layout.transform.apply(wall.start)
                let b = layout.transform.apply(wall.end)
                let distance = CGFloat(PlanGeometry.distance(from: Point2D(x: Double(point.x), y: Double(point.y)),
                                                             toSegmentFrom: a, to: b))
                if distance <= bestDistance {
                    bestDistance = distance
                    best = .wall(roomIndex: roomIndex, wallID: wall.id)
                }
            }
        }
        return best
    }
}
