// PDF schedule pages: walls, openings and objects tables, totals and calculator results, paginated.
import UIKit

enum ScheduleBlock {
    case section(String)
    case subheading(String)
    case header([String], widths: [CGFloat])
    case row([String], widths: [CGFloat])
    case totals([String], widths: [CGFloat])
    case note(String)
    case spacer(CGFloat)

    var height: CGFloat {
        switch self {
        case .section: 30
        case .subheading: 22
        case .header: 18
        case .row: 16
        case .totals: 19
        case .note: 15
        case .spacer(let value): value
        }
    }
}

extension PDFReportBuilder {
    static func scheduleBlocks(_ content: PDFReportContent, contentWidth: CGFloat) -> [ScheduleBlock] {
        let formatter = content.formatter
        var blocks: [ScheduleBlock] = []
        let wallWidths: [CGFloat] = [0.12, 0.3, 0.28, 0.3].map { $0 * contentWidth }
        let openingWidths: [CGFloat] = [0.31, 0.23, 0.23, 0.23].map { $0 * contentWidth }
        let objectWidths: [CGFloat] = [0.4, 0.6].map { $0 * contentWidth }
        let calculatorWidths: [CGFloat] = [0.4, 0.6].map { $0 * contentWidth }

        for item in content.rooms {
            let room = item.geometry
            let metrics = RoomMetrics(room: room)
            blocks.append(.section("\(room.name) — \(formatter.area(metrics.floorArea))"))
            if content.includeSchedule {
                blocks.append(.subheading(String(localized: "Walls")))
                blocks.append(.header(["#", String(localized: "Length"), String(localized: "Height"), String(localized: "Area")],
                                      widths: wallWidths))
                for (index, wall) in room.walls.enumerated() {
                    blocks.append(.row(["\(index + 1)", formatter.length(wall.length), formatter.length(wall.height),
                                        formatter.area(wall.length * wall.height)], widths: wallWidths))
                }
                let totalLength = room.walls.reduce(0) { $0 + $1.length }
                blocks.append(.totals([String(localized: "Total"), formatter.length(totalLength), "",
                                       formatter.area(metrics.grossWallArea)], widths: wallWidths))
                if !room.openings.isEmpty {
                    blocks.append(.subheading(String(localized: "Doors & windows")))
                    blocks.append(.header([String(localized: "Type"), String(localized: "Width"), String(localized: "Height"),
                                           String(localized: "Sill")], widths: openingWidths))
                    for opening in room.openings {
                        blocks.append(.row([opening.kind.displayName, formatter.length(opening.width), formatter.length(opening.height),
                                            opening.kind == .window ? formatter.length(opening.sillHeight) : "—"],
                                           widths: openingWidths))
                    }
                }
                if !room.objects.isEmpty {
                    blocks.append(.subheading(String(localized: "Objects")))
                    blocks.append(.header([String(localized: "Object"), String(localized: "W × D × H")], widths: objectWidths))
                    for object in room.objects {
                        blocks.append(.row([object.category.displayName,
                                            "\(formatter.length(object.width)) × \(formatter.length(object.depth)) × \(formatter.length(object.height))"],
                                           widths: objectWidths))
                    }
                }
                blocks.append(.subheading(String(localized: "Totals")))
                blocks.append(.row([String(localized: "Floor area"), formatter.area(metrics.floorArea)], widths: calculatorWidths))
                blocks.append(.row([String(localized: "Net wall area"), formatter.area(metrics.netWallArea)], widths: calculatorWidths))
                blocks.append(.row([String(localized: "Perimeter"), formatter.length(metrics.perimeter)], widths: calculatorWidths))
                blocks.append(.row([String(localized: "Volume"), formatter.volume(metrics.volume)], widths: calculatorWidths))
            }
            if content.includeCalculators && !item.snapshots.isEmpty {
                blocks.append(.subheading(String(localized: "Calculator results")))
                for snapshot in item.snapshots {
                    blocks.append(.totals([CalculatorSummary.title(snapshot.kind), CalculatorSummary.result(snapshot, formatter: formatter)],
                                          widths: calculatorWidths))
                    let details = CalculatorSummary.details(snapshot, formatter: formatter)
                        .map { "\($0.label): \($0.value)" }
                        .joined(separator: " · ")
                    blocks.append(.note(details))
                }
            }
            blocks.append(.spacer(14))
        }
        return blocks
    }

    /// Splits blocks into pages; a heading is never left alone at the bottom of a page.
    static func paginate(_ blocks: [ScheduleBlock], available: CGFloat) -> [[ScheduleBlock]] {
        var pages: [[ScheduleBlock]] = []
        var current: [ScheduleBlock] = []
        var used: CGFloat = 0
        for (index, block) in blocks.enumerated() {
            var needed = block.height
            switch block {
            case .section, .subheading, .header:
                if index + 1 < blocks.count { needed += blocks[index + 1].height }
            default:
                break
            }
            if used + needed > available && !current.isEmpty {
                pages.append(current)
                current = []
                used = 0
                if case .spacer = block { continue }
            }
            current.append(block)
            used += block.height
        }
        if !current.isEmpty { pages.append(current) }
        return pages
    }

    static func drawSchedule(_ blocks: [ScheduleBlock], pageRect: CGRect, in cg: CGContext) {
        UIGraphicsPushContext(cg)
        defer { UIGraphicsPopContext() }
        var y = margin + headerHeight + 12
        let left = margin
        let width = pageRect.width - margin * 2
        for block in blocks {
            switch block {
            case .section(let title):
                draw(title, at: CGPoint(x: left, y: y + 8), font: .systemFont(ofSize: 13, weight: .bold), color: textColor, maxWidth: width)
            case .subheading(let title):
                draw(title.uppercased(), at: CGPoint(x: left, y: y + 7), font: .systemFont(ofSize: 8.5, weight: .bold),
                     color: accentColor, maxWidth: width)
            case .header(let cells, let widths):
                let rect = CGRect(x: left, y: y, width: width, height: block.height)
                UIColor(hex: 0xF3F4F6).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 3).fill()
                drawCells(cells, widths: widths, x: left, y: y + 3.5, font: .systemFont(ofSize: 8.5, weight: .semibold), color: secondaryColor)
            case .row(let cells, let widths):
                drawCells(cells, widths: widths, x: left, y: y + 2.5, font: .monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                          color: textColor)
                let rule = UIBezierPath()
                rule.move(to: CGPoint(x: left, y: y + block.height))
                rule.addLine(to: CGPoint(x: left + width, y: y + block.height))
                rule.lineWidth = 0.4
                ruleColor.setStroke()
                rule.stroke()
            case .totals(let cells, let widths):
                drawCells(cells, widths: widths, x: left, y: y + 3, font: .monospacedDigitSystemFont(ofSize: 9.5, weight: .bold),
                          color: textColor)
            case .note(let text):
                draw(text, at: CGPoint(x: left, y: y + 1), font: .systemFont(ofSize: 8), color: secondaryColor, maxWidth: width)
            case .spacer:
                break
            }
            y += block.height
        }
    }

    private static func drawCells(_ cells: [String], widths: [CGFloat], x: CGFloat, y: CGFloat, font: UIFont, color: UIColor) {
        var cursor = x
        for (index, cell) in cells.enumerated() {
            let cellWidth = index < widths.count ? widths[index] : 60
            if index == 0 {
                draw(cell, at: CGPoint(x: cursor + 6, y: y), font: font, color: color, maxWidth: cellWidth - 10)
            } else {
                drawRightAligned(cell, right: cursor + cellWidth - 6, y: y, font: font, color: color)
            }
            cursor += cellWidth
        }
    }
}
