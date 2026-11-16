// Localized text for calculator results, shared by the calculator screens ("Share as text") and the PDF report.
import Foundation

enum CalculatorSummary {
    struct Line: Hashable {
        var label: String
        var value: String
    }

    static func title(_ kind: CalculatorKind) -> String { kind.displayName }

    /// The main result in display units (e.g. "12 L", "22.0 m² · 10 packs").
    static func result(_ snapshot: CalculatorSnapshot, formatter: UnitFormatter) -> String {
        let system = formatter.system
        switch snapshot {
        case .paint(let input):
            return formatter.paintAmount(Calculators.paint(input, system: system))
        case .flooring(let input):
            let result = Calculators.flooring(input)
            let area = formatter.area(result.area)
            if let packs = result.packs {
                return area + " · " + String(localized: "\(packs) packs")
            }
            return area
        case .baseboards(let input):
            let result = Calculators.baseboards(input)
            return formatter.length(result.length) + " · " + String(localized: "\(result.pieces) pieces")
        case .wallpaper(let input):
            let rolls = Calculators.wallpaperRolls(input)
            return String(localized: "\(rolls) rolls")
        case .tiles(let input):
            let result = Calculators.tiles(input)
            let tiles = String(localized: "\(result.tiles) tiles")
            if let boxes = result.boxes {
                return tiles + " · " + String(localized: "\(boxes) boxes")
            }
            return tiles
        }
    }

    /// The inputs behind a result, for the report and shared text.
    static func details(_ snapshot: CalculatorSnapshot, formatter: UnitFormatter) -> [Line] {
        let system = formatter.system
        switch snapshot {
        case .paint(let input):
            var lines = [Line(label: String(localized: "Wall area"), value: formatter.area(input.wallArea))]
            if input.includeCeiling {
                lines.append(Line(label: String(localized: "Ceiling"), value: formatter.area(input.ceilingArea)))
            }
            lines.append(Line(label: String(localized: "Coats"), value: "\(input.coats)"))
            let coverage: String
            if system == .metric {
                coverage = "\(formatter.compactNumber(input.coverage)) \(formatter.symbols.squareMeter)/\(formatter.symbols.liter)"
            } else {
                let value = input.coverage * UnitConversion.squareFeetPerSquareMeter * UnitConversion.litersPerGallon
                coverage = "\(formatter.compactNumber(value, maxFractionDigits: 0)) \(formatter.symbols.squareFoot)/\(formatter.symbols.gallon)"
            }
            lines.append(Line(label: String(localized: "Coverage"), value: coverage))
            return lines
        case .flooring(let input):
            var lines = [Line(label: String(localized: "Floor area"), value: formatter.area(input.area)),
                         Line(label: String(localized: "Waste"), value: "\(formatter.compactNumber(input.wastePercent))%")]
            if input.packSize > 0 {
                lines.append(Line(label: String(localized: "Pack size"), value: formatter.area(input.packSize)))
            }
            return lines
        case .baseboards(let input):
            return [Line(label: String(localized: "Perimeter"), value: formatter.length(input.perimeter)),
                    Line(label: String(localized: "Door widths"), value: formatter.length(input.doorWidths)),
                    Line(label: String(localized: "Piece length"), value: formatter.length(input.pieceLength))]
        case .wallpaper(let input):
            var lines = [Line(label: String(localized: "Net wall area"), value: formatter.area(input.wallArea)),
                         Line(label: String(localized: "Roll"), value: "\(formatter.length(input.rollWidth)) × \(formatter.length(input.rollLength))")]
            if input.patternRepeat > 0 {
                let repeatValue = UnitConversion.toDisplaySmall(input.patternRepeat, system)
                lines.append(Line(label: String(localized: "Pattern repeat"),
                                  value: "\(formatter.compactNumber(repeatValue)) \(formatter.smallLengthSymbol)"))
            }
            return lines
        case .tiles(let input):
            let width = UnitConversion.toDisplaySmall(input.tileWidth, system)
            let length = UnitConversion.toDisplaySmall(input.tileLength, system)
            var lines = [Line(label: String(localized: "Floor area"), value: formatter.area(input.area)),
                         Line(label: String(localized: "Tile"), value: "\(formatter.compactNumber(width)) × \(formatter.compactNumber(length)) \(formatter.smallLengthSymbol)"),
                         Line(label: String(localized: "Waste"), value: "\(formatter.compactNumber(input.wastePercent))%")]
            if input.tilesPerBox > 0 {
                lines.append(Line(label: String(localized: "Tiles per box"), value: "\(input.tilesPerBox)"))
            }
            return lines
        }
    }

    /// Plain text for "Share as text".
    static func shareText(_ snapshot: CalculatorSnapshot, roomName: String?, formatter: UnitFormatter) -> String {
        var lines: [String] = []
        if let roomName, !roomName.isEmpty {
            lines.append("\(title(snapshot.kind)) — \(roomName)")
        } else {
            lines.append(title(snapshot.kind))
        }
        lines.append(String(localized: "Result") + ": " + result(snapshot, formatter: formatter))
        for line in details(snapshot, formatter: formatter) {
            lines.append("\(line.label): \(line.value)")
        }
        lines.append(String(localized: "Calculated with PlanScan"))
        return lines.joined(separator: "\n")
    }
}
