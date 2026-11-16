// Plan rendering styles (Blueprint / Paper) and toggleable layers.
import UIKit

struct PlanLayers: Hashable, Codable {
    var dimensions = true
    var openings = true
    var furniture = true
    var grid = true
    var labels = true
    var floorFill = true
    var scaleBar = true

    static let all = PlanLayers()
    static let thumbnail = PlanLayers(dimensions: false, openings: true, furniture: false, grid: false,
                                      labels: false, floorFill: true, scaleBar: false)
    static let thumbnailWithFurniture = PlanLayers(dimensions: false, openings: true, furniture: true, grid: false,
                                                   labels: false, floorFill: true, scaleBar: false)
}

struct PlanStyle {
    var background: UIColor?
    var grid: UIColor
    var gridMajor: UIColor
    var walls: UIColor
    var dimensions: UIColor
    var openings: UIColor
    var furnitureFill: UIColor
    var furnitureStroke: UIColor
    var furnitureIcon: UIColor
    var label: UIColor
    var labelSecondary: UIColor
    var labelBackground: UIColor
    var selection: UIColor
    var floorFillOpacity: CGFloat
    /// Multiplies font sizes (PDF uses smaller text than the screen).
    var fontScale: CGFloat = 1
    /// Multiplies hairline widths.
    var lineScale: CGFloat = 1

    static let blueprint = PlanStyle(
        background: UIColor(hex: 0x0A1A33),
        grid: UIColor(hex: 0x1E3A66, alpha: 0.35),
        gridMajor: UIColor(hex: 0x1E3A66, alpha: 0.75),
        walls: UIColor(hex: 0xE8F1FF),
        dimensions: UIColor(hex: 0x00E5FF),
        openings: UIColor(hex: 0x3CF2B8),
        furnitureFill: UIColor(white: 1, alpha: 0.14),
        furnitureStroke: UIColor(white: 1, alpha: 0.38),
        furnitureIcon: UIColor(white: 1, alpha: 0.75),
        label: UIColor.white,
        labelSecondary: UIColor(white: 1, alpha: 0.65),
        labelBackground: UIColor(hex: 0x0A1A33, alpha: 0.82),
        selection: UIColor(hex: 0xFFB020),
        floorFillOpacity: 0.13)

    static let paper = PlanStyle(
        background: UIColor.white,
        grid: UIColor(hex: 0xE5E7EB),
        gridMajor: UIColor(hex: 0xD1D5DB),
        walls: UIColor(hex: 0x111827),
        dimensions: UIColor(hex: 0x2563EB),
        openings: UIColor(hex: 0x059669),
        furnitureFill: UIColor(hex: 0x6B7280, alpha: 0.15),
        furnitureStroke: UIColor(hex: 0x6B7280, alpha: 0.6),
        furnitureIcon: UIColor(hex: 0x4B5563),
        label: UIColor(hex: 0x111827),
        labelSecondary: UIColor(hex: 0x4B5563),
        labelBackground: UIColor(white: 1, alpha: 0.85),
        selection: UIColor(hex: 0xF59E0B),
        floorFillOpacity: 0.10)

    static func theme(_ theme: PlanTheme) -> PlanStyle {
        theme == .blueprint ? .blueprint : .paper
    }

    /// Same palette without a background fill (thumbnails on cards).
    func transparent() -> PlanStyle {
        var copy = self
        copy.background = nil
        return copy
    }

    func scaled(font: CGFloat, line: CGFloat = 1) -> PlanStyle {
        var copy = self
        copy.fontScale = font
        copy.lineScale = line
        return copy
    }
}
