// Localized names and SF Symbols for model enums, plus the localized unit formatter.
import Foundation

extension RoomType {
    var displayName: String {
        switch self {
        case .living: String(localized: "Living room")
        case .bedroom: String(localized: "Bedroom")
        case .kitchen: String(localized: "Kitchen")
        case .bathroom: String(localized: "Bathroom")
        case .dining: String(localized: "Dining room")
        case .office: String(localized: "Office")
        case .hallway: String(localized: "Hallway")
        case .other: String(localized: "Room")
        }
    }

    var systemImage: String {
        switch self {
        case .living: "sofa.fill"
        case .bedroom: "bed.double.fill"
        case .kitchen: "refrigerator.fill"
        case .bathroom: "bathtub.fill"
        case .dining: "fork.knife"
        case .office: "desktopcomputer"
        case .hallway: "door.left.hand.open"
        case .other: "square.dashed"
        }
    }
}

extension RoomSource {
    var displayName: String {
        switch self {
        case .scanned: String(localized: "Scanned")
        case .manual: String(localized: "Manual")
        case .sample: String(localized: "Sample")
        }
    }

    var systemImage: String {
        switch self {
        case .scanned: "viewfinder"
        case .manual: "hand.draw.fill"
        case .sample: "sparkles"
        }
    }
}

extension Confidence {
    /// Scan quality wording used by the quality badge.
    var qualityName: String {
        switch self {
        case .high: String(localized: "Good scan")
        case .medium: String(localized: "Fair scan")
        case .low: String(localized: "Low quality")
        }
    }

    var confidenceName: String {
        switch self {
        case .high: String(localized: "High")
        case .medium: String(localized: "Medium")
        case .low: String(localized: "Low")
        }
    }
}

extension OpeningKind {
    var displayName: String {
        switch self {
        case .door: String(localized: "Door")
        case .window: String(localized: "Window")
        case .opening: String(localized: "Opening")
        }
    }

    var systemImage: String {
        switch self {
        case .door: "door.left.hand.open"
        case .window: "window.vertical.closed"
        case .opening: "rectangle.portrait"
        }
    }
}

extension FurnitureCategory {
    var displayName: String {
        switch self {
        case .storage: String(localized: "Storage")
        case .refrigerator: String(localized: "Refrigerator")
        case .stove: String(localized: "Stove")
        case .bed: String(localized: "Bed")
        case .sink: String(localized: "Sink")
        case .washerDryer: String(localized: "Washer / dryer")
        case .toilet: String(localized: "Toilet")
        case .bathtub: String(localized: "Bathtub")
        case .oven: String(localized: "Oven")
        case .dishwasher: String(localized: "Dishwasher")
        case .table: String(localized: "Table")
        case .sofa: String(localized: "Sofa")
        case .chair: String(localized: "Chair")
        case .fireplace: String(localized: "Fireplace")
        case .television: String(localized: "Television")
        case .stairs: String(localized: "Stairs")
        case .other: String(localized: "Object")
        }
    }

    /// SF Symbol drawn on the plan; the renderer falls back to `cube.fill` if a symbol is unavailable.
    var symbolName: String {
        switch self {
        case .storage: "cabinet.fill"
        case .refrigerator: "refrigerator.fill"
        case .stove: "oven.fill"
        case .bed: "bed.double.fill"
        case .sink: "sink.fill"
        case .washerDryer: "washer.fill"
        case .toilet: "toilet.fill"
        case .bathtub: "bathtub.fill"
        case .oven: "oven.fill"
        case .dishwasher: "dishwasher.fill"
        case .table: "table.furniture.fill"
        case .sofa: "sofa.fill"
        case .chair: "chair.fill"
        case .fireplace: "fireplace.fill"
        case .television: "tv.fill"
        case .stairs: "stairs"
        case .other: "cube.fill"
        }
    }
}

extension CalculatorKind {
    var displayName: String {
        switch self {
        case .paint: String(localized: "Paint")
        case .flooring: String(localized: "Flooring")
        case .baseboards: String(localized: "Baseboards")
        case .wallpaper: String(localized: "Wallpaper")
        case .tiles: String(localized: "Tiles")
        }
    }

    var subtitle: String {
        switch self {
        case .paint: String(localized: "Liters of paint for walls and ceiling")
        case .flooring: String(localized: "Floor covering with waste allowance")
        case .baseboards: String(localized: "Skirting length and pieces")
        case .wallpaper: String(localized: "Rolls, including pattern repeat")
        case .tiles: String(localized: "Tiles and boxes for the floor")
        }
    }

    var systemImage: String {
        switch self {
        case .paint: "paintbrush.pointed.fill"
        case .flooring: "square.grid.3x3.fill"
        case .baseboards: "ruler.fill"
        case .wallpaper: "scroll.fill"
        case .tiles: "square.grid.2x2.fill"
        }
    }
}

extension UnitFormatter {
    /// Formatter with localized unit symbols and the user's decimal separator.
    static func localized(_ system: UnitSystem, locale: Locale = .current) -> UnitFormatter {
        var symbols = UnitSymbols()
        symbols.meter = String(localized: "m", comment: "Unit symbol: meters")
        symbols.squareMeter = String(localized: "m²", comment: "Unit symbol: square meters")
        symbols.cubicMeter = String(localized: "m³", comment: "Unit symbol: cubic meters")
        symbols.liter = String(localized: "L", comment: "Unit symbol: liters")
        symbols.foot = String(localized: "ft", comment: "Unit symbol: feet")
        symbols.squareFoot = String(localized: "ft²", comment: "Unit symbol: square feet")
        symbols.cubicFoot = String(localized: "ft³", comment: "Unit symbol: cubic feet")
        symbols.gallon = String(localized: "gal", comment: "Unit symbol: US gallons")
        symbols.centimeter = String(localized: "cm", comment: "Unit symbol: centimeters")
        symbols.inch = String(localized: "in", comment: "Unit symbol: inches")
        return UnitFormatter(system: system, symbols: symbols, decimalSeparator: locale.decimalSeparator ?? ".")
    }

    /// ASCII-only variant for DXF text (feet-inches as 13'-11", areas with plain symbols).
    func dxfLength(_ meters: Double) -> String {
        switch system {
        case .metric:
            return String(format: "%.2f m", meters)
        case .imperial:
            let parts = UnitConversion.feetAndInches(meters: meters)
            return "\(parts.feet)'-\(parts.inches)\""
        }
    }

    func dxfArea(_ squareMeters: Double) -> String {
        switch system {
        case .metric: return String(format: "%.1f m²", squareMeters)
        case .imperial: return String(format: "%.0f sq ft", squareMeters * UnitConversion.squareFeetPerSquareMeter)
        }
    }
}
