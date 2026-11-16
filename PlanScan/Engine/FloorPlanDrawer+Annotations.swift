// Plan annotations: dimension lines with upright labels, room names with areas, scale bar and text drawing.
import UIKit

extension PlanRenderer {
    // MARK: Dimensions

    func drawDimensions() {
        let offset = 0.35
        let font = UIFont.monospacedDigitSystemFont(ofSize: 10.5 * style.fontScale, weight: .semibold)
        for entry in resolved.walls where entry.wall.length >= 0.3 {
            let wall = entry.wall
            var normal = entry.outwardNormal
            if resolved.isInsideOtherRoom(wall.midpoint + normal * offset, excluding: entry.roomIndex) {
                normal = -normal
            }
            let color = (wall.id == selection ? style.selection : style.dimensions)
            let p1 = pt(wall.start + normal * offset)
            let p2 = pt(wall.end + normal * offset)
            guard let direction = (p2 - p1).unit else { continue }

            // Extension lines from the wall face to just past the dimension line.
            ctx.setStrokeColor(color.withAlphaComponent(0.45).cgColor)
            ctx.setLineWidth(0.6 * style.lineScale)
            for (base, dimPoint) in [(wall.start, p1), (wall.end, p2)] {
                let from = pt(base + normal * (wall.thickness / 2 + 0.05))
                guard let along = (dimPoint - from).unit else { continue }
                ctx.move(to: from)
                ctx.addLine(to: dimPoint + along * 4)
            }
            ctx.strokePath()

            // Dimension line with 45° ticks.
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(0.9 * style.lineScale)
            ctx.move(to: p1)
            ctx.addLine(to: p2)
            let tick = CGPoint(x: (direction.x - direction.y) * 3.5, y: (direction.y + direction.x) * 3.5)
            for end in [p1, p2] {
                ctx.move(to: end - tick)
                ctx.addLine(to: end + tick)
            }
            ctx.strokePath()

            let text = formatter.length(wall.length)
            let textSize = (text as NSString).size(withAttributes: [.font: font])
            let available = (p2 - p1).length
            guard available >= textSize.width + 10 else { continue }
            var angle = atan2(direction.y, direction.x)
            if angle > .pi / 2 { angle -= .pi }
            if angle < -.pi / 2 { angle += .pi }
            let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            drawText(text, at: mid, angle: angle, font: font, color: color, background: style.labelBackground)
        }
    }

    // MARK: Room labels

    func drawLabels() {
        let nameFont = UIFont.systemFont(ofSize: 13 * style.fontScale, weight: .semibold)
        let areaFont = UIFont.monospacedDigitSystemFont(ofSize: 11.5 * style.fontScale, weight: .regular)
        for room in resolved.rooms {
            let outline = room.outline
            guard let bounds = CGRect(points: outline.map(pt)), bounds.width >= 44, bounds.height >= 28 else { continue }
            let anchor = pt(room.labelAnchor)
            let name = room.name.isEmpty ? room.type.displayName : room.name
            let area = formatter.area(RoomMetrics(room: room).floorArea)
            let nameSize = (name as NSString).size(withAttributes: [.font: nameFont])
            let areaSize = (area as NSString).size(withAttributes: [.font: areaFont])
            let width = max(nameSize.width, areaSize.width) + 12
            let height = nameSize.height + areaSize.height + 6
            let box = CGRect(x: anchor.x - width / 2, y: anchor.y - height / 2, width: width, height: height)
            ctx.addPath(CGPath(roundedRect: box, cornerWidth: 6, cornerHeight: 6, transform: nil))
            ctx.setFillColor(style.labelBackground.withAlphaComponent(0.7).cgColor)
            ctx.fillPath()
            (name as NSString).draw(at: CGPoint(x: anchor.x - nameSize.width / 2, y: box.minY + 3),
                                    withAttributes: [.font: nameFont, .foregroundColor: style.label])
            (area as NSString).draw(at: CGPoint(x: anchor.x - areaSize.width / 2, y: box.minY + 3 + nameSize.height),
                                    withAttributes: [.font: areaFont, .foregroundColor: style.labelSecondary])
        }
    }

    // MARK: Scale bar

    func drawScaleBar() {
        let base = formatter.scaleBarMeters
        let multipliers: [Double] = [1, 2, 5, 10, 20, 50]
        let maxLength = rect.width * 0.4
        let multiplier = multipliers.first { CGFloat(base * $0) * scale >= 36 } ?? 50
        let length = CGFloat(base * multiplier) * scale
        guard length >= 8, length <= max(maxLength, 40) else { return }
        let origin = CGPoint(x: rect.minX + 16, y: rect.maxY - 16)
        let end = CGPoint(x: origin.x + length, y: origin.y)
        ctx.setStrokeColor(style.label.cgColor)
        ctx.setLineWidth(1.4 * style.lineScale)
        ctx.move(to: origin)
        ctx.addLine(to: end)
        for x in [origin.x, end.x, origin.x + length / 2] {
            let h: CGFloat = x == origin.x + length / 2 ? 3 : 5
            ctx.move(to: CGPoint(x: x, y: origin.y - h))
            ctx.addLine(to: CGPoint(x: x, y: origin.y + h))
        }
        ctx.strokePath()
        let value = formatter.system == .metric ? base * multiplier : 3 * multiplier
        let unit = formatter.system == .metric ? formatter.symbols.meter : formatter.symbols.foot
        let label = "\(formatter.compactNumber(value, maxFractionDigits: 0)) \(unit)"
        let font = UIFont.systemFont(ofSize: 10 * style.fontScale, weight: .semibold)
        let size = (label as NSString).size(withAttributes: [.font: font])
        (label as NSString).draw(at: CGPoint(x: origin.x + (length - size.width) / 2, y: origin.y - size.height - 6),
                                 withAttributes: [.font: font, .foregroundColor: style.label])
    }

    // MARK: Text

    /// Draws centered, rotated text. The context must be pushed with UIGraphicsPushContext (y-down coordinates).
    func drawText(_ string: String, at center: CGPoint, angle: CGFloat, font: UIFont, color: UIColor, background: UIColor?) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (string as NSString).size(withAttributes: attributes)
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle)
        if let background {
            let box = CGRect(x: -size.width / 2 - 4, y: -size.height / 2 - 1, width: size.width + 8, height: size.height + 2)
            ctx.addPath(CGPath(roundedRect: box, cornerWidth: 4, cornerHeight: 4, transform: nil))
            ctx.setFillColor(background.cgColor)
            ctx.fillPath()
        }
        (string as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
        ctx.restoreGState()
    }
}

extension CGRect {
    /// Bounding box of points.
    init?(points: [CGPoint]) {
        guard let first = points.first else { return nil }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }
        self.init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
