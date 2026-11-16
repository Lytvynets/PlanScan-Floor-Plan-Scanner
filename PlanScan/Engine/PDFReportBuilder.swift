// True-scale vector PDF report: whole-floor page, a page per room, schedule pages, header and footer on every page.
import UIKit

struct PDFRoomItem {
    var geometry: RoomGeometry
    var snapshots: [CalculatorSnapshot]
}

struct PDFReportContent {
    var projectName: String
    var companyName: String?
    var date: Date
    var wholeFloor: FloorPlanModel?
    var rooms: [PDFRoomItem]
    var paperSize: PaperSize
    var includeFurniture: Bool
    var includeSchedule: Bool
    var includeCalculators: Bool
    var formatter: UnitFormatter
    var rotationDegrees: Double
}

enum PDFReportBuilder {
    static let margin: CGFloat = 36
    static let headerHeight: CGFloat = 62
    static let footerHeight: CGFloat = 28
    static let metricsHeight: CGFloat = 52

    private enum Page {
        case plan(title: String, plan: FloorPlanModel, metrics: RoomMetrics, roomCount: Int)
        case schedule([ScheduleBlock])
    }

    static let textColor = UIColor(hex: 0x111827)
    static let secondaryColor = UIColor(hex: 0x6B7280)
    static let accentColor = UIColor(hex: 0x2563EB)
    static let ruleColor = UIColor(hex: 0xE5E7EB)

    static func makePDF(_ content: PDFReportContent) -> Data {
        let pageSize = content.paperSize.pointSize
        let pageRect = CGRect(origin: .zero, size: pageSize)
        var pages: [Page] = []
        if var whole = content.wholeFloor {
            whole.rotationDegrees = content.rotationDegrees
            pages.append(.plan(title: String(localized: "Whole floor"), plan: whole,
                               metrics: RoomMetrics.total(of: whole.rooms), roomCount: whole.rooms.count))
        }
        for item in content.rooms {
            var plan = FloorPlanModel(room: item.geometry)
            plan.rotationDegrees = content.rotationDegrees
            pages.append(.plan(title: item.geometry.name, plan: plan, metrics: RoomMetrics(room: item.geometry), roomCount: 1))
        }
        let hasCalculators = content.includeCalculators && content.rooms.contains { !$0.snapshots.isEmpty }
        if content.includeSchedule || hasCalculators {
            let blocks = scheduleBlocks(content, contentWidth: pageSize.width - margin * 2)
            let available = pageSize.height - margin * 2 - headerHeight - footerHeight - 12
            for pageBlocks in paginate(blocks, available: available) {
                pages.append(.schedule(pageBlocks))
            }
        }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: content.projectName,
            kCGPDFContextCreator as String: "PlanScan",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { context in
            for (index, page) in pages.enumerated() {
                context.beginPage()
                let cg = context.cgContext
                switch page {
                case .plan(let title, let plan, let metrics, let roomCount):
                    drawHeader(content: content, subtitle: title, pageRect: pageRect)
                    drawPlanPage(plan: plan, metrics: metrics, roomCount: roomCount, content: content, pageRect: pageRect, in: cg)
                case .schedule(let blocks):
                    drawHeader(content: content, subtitle: String(localized: "Schedule"), pageRect: pageRect)
                    drawSchedule(blocks, pageRect: pageRect, in: cg)
                }
                drawFooter(page: index + 1, of: pages.count, pageRect: pageRect, in: cg)
            }
        }
    }

    // MARK: Header & footer

    private static func drawHeader(content: PDFReportContent, subtitle: String, pageRect: CGRect) {
        let left = margin
        let top = margin
        // Logo glyph: rounded square with a tiny plan.
        let glyph = CGRect(x: left, y: top, width: 22, height: 22)
        let glyphPath = UIBezierPath(roundedRect: glyph, cornerRadius: 6)
        UIColor(hex: 0x0A1A33).setFill()
        glyphPath.fill()
        let lines = UIBezierPath()
        lines.move(to: CGPoint(x: glyph.minX + 5, y: glyph.minY + 5))
        lines.addLine(to: CGPoint(x: glyph.maxX - 5, y: glyph.minY + 5))
        lines.addLine(to: CGPoint(x: glyph.maxX - 5, y: glyph.maxY - 5))
        lines.addLine(to: CGPoint(x: glyph.minX + 5, y: glyph.maxY - 5))
        lines.close()
        lines.move(to: CGPoint(x: glyph.midX, y: glyph.minY + 5))
        lines.addLine(to: CGPoint(x: glyph.midX, y: glyph.midY + 2))
        lines.lineWidth = 1.6
        UIColor(hex: 0x00E5FF).setStroke()
        lines.stroke()
        draw("PlanScan", at: CGPoint(x: glyph.maxX + 6, y: top + 4),
             font: .systemFont(ofSize: 11, weight: .bold), color: textColor)

        draw(content.projectName, at: CGPoint(x: left, y: top + 28), font: .systemFont(ofSize: 16, weight: .bold),
             color: textColor, maxWidth: pageRect.width * 0.6)
        draw(subtitle, at: CGPoint(x: left, y: top + 47), font: .systemFont(ofSize: 10.5, weight: .medium),
             color: secondaryColor, maxWidth: pageRect.width * 0.6)

        let dateText = content.date.formatted(date: .long, time: .omitted)
        drawRightAligned(dateText, right: pageRect.width - margin, y: top + 6, font: .systemFont(ofSize: 9.5), color: secondaryColor)
        if let company = content.companyName, !company.isEmpty {
            drawRightAligned(company, right: pageRect.width - margin, y: top + 28, font: .systemFont(ofSize: 11, weight: .semibold),
                             color: textColor)
        }
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: margin, y: top + headerHeight - 1))
        rule.addLine(to: CGPoint(x: pageRect.width - margin, y: top + headerHeight - 1))
        rule.lineWidth = 0.6
        ruleColor.setStroke()
        rule.stroke()
    }

    private static func drawFooter(page: Int, of total: Int, pageRect: CGRect, in cg: CGContext) {
        let y = pageRect.height - margin - footerHeight + 10
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: margin, y: y - 6))
        rule.addLine(to: CGPoint(x: pageRect.width - margin, y: y - 6))
        rule.lineWidth = 0.6
        ruleColor.setStroke()
        rule.stroke()
        draw(String(localized: "Measurements are approximate — verify critical dimensions."), at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 8), color: secondaryColor, maxWidth: pageRect.width * 0.7)
        drawRightAligned(String(localized: "Page \(page) / \(total)"), right: pageRect.width - margin, y: y,
                         font: .monospacedDigitSystemFont(ofSize: 8, weight: .medium), color: secondaryColor)
    }

    // MARK: Plan pages

    private static func drawPlanPage(plan: FloorPlanModel, metrics: RoomMetrics, roomCount: Int, content: PDFReportContent,
                                     pageRect: CGRect, in cg: CGContext) {
        let top = margin + headerHeight + 26
        let bottom = pageRect.height - margin - footerHeight - metricsHeight - 14
        let drawable = CGRect(x: margin, y: top, width: pageRect.width - margin * 2, height: max(80, bottom - top))
        let rotation = PlanLayout.rotation(for: plan)
        let bounds = PlanLayout.contentBounds(of: plan, rotation: rotation, includeAnnotations: true)
        let denominator = PlanScale.bestDenominator(contentWidth: bounds.width, contentHeight: bounds.height,
                                                    availableWidth: Double(drawable.width), availableHeight: Double(drawable.height))
        let layout: PlanLayout
        let scaleText: String
        if let denominator {
            layout = PlanLayout.fixedScale(plan, pointsPerMeter: PlanScale.pointsPerMeter(denominator: denominator),
                                           in: CanvasRect(drawable))
            scaleText = String(localized: "Scale 1:\(denominator) (\(content.paperSize.displayName))")
        } else {
            layout = PlanLayout.fit(plan, in: CanvasRect(drawable), padding: 0.02)
            scaleText = String(localized: "Not to scale")
        }
        var layers = PlanLayers.all
        layers.grid = false
        layers.furniture = content.includeFurniture
        let style = PlanStyle.paper.scaled(font: 0.72, line: 0.75)
        FloorPlanDrawer.draw(plan, in: cg, rect: drawable, layout: layout, style: style, layers: layers,
                             formatter: content.formatter, selection: nil)
        UIGraphicsPushContext(cg)
        drawRightAligned(scaleText, right: drawable.maxX, y: top - 18, font: .systemFont(ofSize: 9, weight: .semibold),
                         color: accentColor)
        UIGraphicsPopContext()

        let formatter = content.formatter
        var cells: [(String, String)] = [
            (String(localized: "Area"), formatter.area(metrics.floorArea)),
            (String(localized: "Perimeter"), formatter.length(metrics.perimeter)),
            (String(localized: "Height"), formatter.length(metrics.ceilingHeight)),
            (String(localized: "Volume"), formatter.volume(metrics.volume)),
        ]
        if roomCount > 1 {
            cells[1] = (String(localized: "Rooms"), "\(roomCount)")
        }
        UIGraphicsPushContext(cg)
        drawMetricsStrip(cells, rect: CGRect(x: margin, y: pageRect.height - margin - footerHeight - metricsHeight - 4,
                                             width: pageRect.width - margin * 2, height: metricsHeight))
        UIGraphicsPopContext()
    }

    private static func drawMetricsStrip(_ cells: [(String, String)], rect: CGRect) {
        let background = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        UIColor(hex: 0xF3F4F6).setFill()
        background.fill()
        let width = rect.width / CGFloat(max(1, cells.count))
        for (index, cell) in cells.enumerated() {
            let x = rect.minX + CGFloat(index) * width + 12
            draw(cell.0, at: CGPoint(x: x, y: rect.minY + 9), font: .systemFont(ofSize: 8.5, weight: .medium), color: secondaryColor,
                 maxWidth: width - 16)
            draw(cell.1, at: CGPoint(x: x, y: rect.minY + 23), font: .monospacedDigitSystemFont(ofSize: 13, weight: .bold),
                 color: textColor, maxWidth: width - 16)
        }
    }

    // MARK: Text helpers (require a pushed UIKit context)

    static func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor, maxWidth: CGFloat? = nil) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if let maxWidth {
            let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: font.lineHeight * 1.3)
            (text as NSString).draw(with: rect, options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                                    attributes: attributes, context: nil)
        } else {
            (text as NSString).draw(at: point, withAttributes: attributes)
        }
    }

    static func drawRightAligned(_ text: String, right: CGFloat, y: CGFloat, font: UIFont, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: right - size.width, y: y), withAttributes: attributes)
    }
}
