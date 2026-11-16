// Renovation calculators (paint, flooring, baseboards, wallpaper, tiles). Inputs are stored in SI units.
import Foundation

enum CalculatorKind: String, Codable, CaseIterable, Identifiable {
    case paint, flooring, baseboards, wallpaper, tiles
    var id: String { rawValue }
}

struct PaintInputs: Codable, Hashable {
    var wallArea: Double = 0            // m², net of doors and windows
    var includeCeiling = false
    var ceilingArea: Double = 0         // m²
    var coats = 2
    var coverage: Double = 10           // m² per liter

    static let defaultImperialCoverage = 350.0 // ft² per gallon
}

struct FlooringInputs: Codable, Hashable {
    var area: Double = 0                // m²
    var wastePercent: Double = 10
    var packSize: Double = 0            // m² per pack, 0 = not used
}

struct BaseboardInputs: Codable, Hashable {
    var perimeter: Double = 0           // m
    var doorWidths: Double = 0          // m
    var pieceLength: Double = 2.5       // m (8 ft in imperial)
}

struct WallpaperInputs: Codable, Hashable {
    var wallArea: Double = 0            // m², net
    var wallHeight: Double = 2.5        // m
    var rollWidth: Double = 0.53        // m
    var rollLength: Double = 10.05      // m
    var patternRepeat: Double = 0       // m
}

struct TileInputs: Codable, Hashable {
    var area: Double = 0                // m²
    var tileWidth: Double = 0.3         // m
    var tileLength: Double = 0.3        // m
    var wastePercent: Double = 10
    var tilesPerBox = 0                 // 0 = not used
}

/// A calculator with its inputs, as saved per room for the PDF report.
enum CalculatorSnapshot: Codable, Hashable {
    case paint(PaintInputs)
    case flooring(FlooringInputs)
    case baseboards(BaseboardInputs)
    case wallpaper(WallpaperInputs)
    case tiles(TileInputs)

    var kind: CalculatorKind {
        switch self {
        case .paint: return .paint
        case .flooring: return .flooring
        case .baseboards: return .baseboards
        case .wallpaper: return .wallpaper
        case .tiles: return .tiles
        }
    }
}

enum Calculators {
    /// Smallest whole number ≥ value (tolerant to floating point noise), never negative.
    static func ceilCount(_ value: Double) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        let rounded: Double = (value - 1e-9).rounded(.up)
        return Int(rounded)
    }

    /// Rounds up to the next multiple of `step`.
    static func roundUp(_ value: Double, step: Double) -> Double {
        guard step > 0, value > 0 else { return max(0, value) }
        return (value / step - 1e-9).rounded(.up) * step
    }

    /// Paint in liters (metric) or gallons (imperial), rounded up to 0.5.
    static func paint(_ input: PaintInputs, system: UnitSystem) -> Double {
        let area = input.wallArea + (input.includeCeiling ? input.ceilingArea : 0)
        guard input.coverage > 0, area > 0 else { return 0 }
        let coats = Double(max(1, input.coats))
        let liters: Double = area * coats / input.coverage
        let amount: Double = system == .metric ? liters : liters / UnitConversion.litersPerGallon
        return roundUp(amount, step: 0.5)
    }

    struct FlooringResult: Hashable {
        var area: Double                // m², including waste
        var packs: Int?
    }

    static func flooring(_ input: FlooringInputs) -> FlooringResult {
        let wasteFactor: Double = 1 + max(0, input.wastePercent) / 100
        let area: Double = max(0, input.area) * wasteFactor
        let packs: Int? = input.packSize > 0 ? ceilCount(area / input.packSize) : nil
        return FlooringResult(area: area, packs: packs)
    }

    struct BaseboardResult: Hashable {
        var length: Double              // m, including 10% waste
        var pieces: Int
    }

    static func baseboards(_ input: BaseboardInputs) -> BaseboardResult {
        let length: Double = max(0, input.perimeter - input.doorWidths) * 1.1
        let pieces: Int = input.pieceLength > 0 ? ceilCount(length / input.pieceLength) : 0
        return BaseboardResult(length: length, pieces: pieces)
    }

    /// Rolls = ceil(net wall area × 1.15 × repeat factor ÷ (roll width × roll length)).
    /// A pattern repeat wastes on average one repeat per strip, i.e. repeat ÷ wall height of extra material.
    static func wallpaperRolls(_ input: WallpaperInputs) -> Int {
        let rollArea = input.rollWidth * input.rollLength
        guard rollArea > 0, input.wallArea > 0 else { return 0 }
        let repeatFactor: Double = 1 + max(0, input.patternRepeat) / max(0.5, input.wallHeight)
        let exact: Double = input.wallArea * 1.15 * repeatFactor / rollArea
        return ceilCount(exact)
    }

    struct TileResult: Hashable {
        var tiles: Int
        var boxes: Int?
    }

    static func tiles(_ input: TileInputs) -> TileResult {
        let tileArea = input.tileWidth * input.tileLength
        guard tileArea > 0, input.area > 0 else { return TileResult(tiles: 0, boxes: input.tilesPerBox > 0 ? 0 : nil) }
        let wasteFactor: Double = 1 + max(0, input.wastePercent) / 100
        let exact: Double = input.area / tileArea * wasteFactor
        let count = ceilCount(exact)
        let boxes: Int? = input.tilesPerBox > 0 ? ceilCount(Double(count) / Double(input.tilesPerBox)) : nil
        return TileResult(tiles: count, boxes: boxes)
    }
}

extension PaintInputs {
    init(room: RoomMetrics) {
        self.init(wallArea: room.netWallArea, includeCeiling: false, ceilingArea: room.floorArea, coats: 2, coverage: 10)
    }
}

extension FlooringInputs {
    init(room: RoomMetrics) { self.init(area: room.floorArea, wastePercent: 10, packSize: 0) }
}

extension BaseboardInputs {
    init(room: RoomMetrics, system: UnitSystem) {
        self.init(perimeter: room.perimeter, doorWidths: room.doorWidthTotal,
                  pieceLength: system == .metric ? 2.5 : 8 * UnitConversion.metersPerFoot)
    }
}

extension WallpaperInputs {
    init(room: RoomMetrics) {
        self.init(wallArea: room.netWallArea, wallHeight: room.ceilingHeight > 0.5 ? room.ceilingHeight : 2.5,
                  rollWidth: 0.53, rollLength: 10.05, patternRepeat: 0)
    }
}

extension TileInputs {
    init(room: RoomMetrics) { self.init(area: room.floorArea, tileWidth: 0.3, tileLength: 0.3, wastePercent: 10, tilesPerBox: 0) }
}
