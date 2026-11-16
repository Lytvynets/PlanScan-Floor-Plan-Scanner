// Unit systems, conversions and measurement formatting ("4.25 m" / "13′ 11″", "18.4 m²" / "198 ft²").
import Foundation

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
}

enum UnitConversion {
    static let metersPerFoot = 0.3048
    static let metersPerInch = 0.0254
    static let squareFeetPerSquareMeter = 10.763_910_416_7
    static let cubicFeetPerCubicMeter = 35.314_666_721_5
    static let litersPerGallon = 3.785_411_784

    /// Feet and whole inches, rounded to the nearest inch (12″ carries into the feet).
    static func feetAndInches(meters: Double) -> (feet: Int, inches: Int) {
        let totalInches = Int((abs(meters) / metersPerInch).rounded())
        return (totalInches / 12, totalInches % 12)
    }

    /// Display length unit (m or ft) ↔ meters.
    static func toDisplayLength(_ meters: Double, _ system: UnitSystem) -> Double {
        system == .metric ? meters : meters / metersPerFoot
    }

    static func fromDisplayLength(_ value: Double, _ system: UnitSystem) -> Double {
        system == .metric ? value : value * metersPerFoot
    }

    /// Display area unit (m² or ft²) ↔ square meters.
    static func toDisplayArea(_ squareMeters: Double, _ system: UnitSystem) -> Double {
        system == .metric ? squareMeters : squareMeters * squareFeetPerSquareMeter
    }

    static func fromDisplayArea(_ value: Double, _ system: UnitSystem) -> Double {
        system == .metric ? value : value / squareFeetPerSquareMeter
    }

    /// Small display length (cm or in) ↔ meters.
    static func toDisplaySmall(_ meters: Double, _ system: UnitSystem) -> Double {
        system == .metric ? meters * 100 : meters / metersPerInch
    }

    static func fromDisplaySmall(_ value: Double, _ system: UnitSystem) -> Double {
        system == .metric ? value / 100 : value * metersPerInch
    }
}

/// Localizable unit symbols; the app fills them from the String Catalog.
struct UnitSymbols: Hashable {
    var meter = "m"
    var squareMeter = "m²"
    var cubicMeter = "m³"
    var liter = "L"
    var foot = "ft"
    var squareFoot = "ft²"
    var cubicFoot = "ft³"
    var gallon = "gal"
    var centimeter = "cm"
    var inch = "in"
}

struct UnitFormatter: Hashable {
    var system: UnitSystem
    var symbols = UnitSymbols()
    var decimalSeparator = "."

    func number(_ value: Double, fractionDigits: Int) -> String {
        let text = String(format: "%.\(max(0, fractionDigits))f", value)
        return decimalSeparator == "." ? text : text.replacingOccurrences(of: ".", with: decimalSeparator)
    }

    /// Up to `maxFractionDigits`, without trailing zeros ("12", "12.5").
    func compactNumber(_ value: Double, maxFractionDigits: Int = 1) -> String {
        var text = String(format: "%.\(max(0, maxFractionDigits))f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return decimalSeparator == "." ? text : text.replacingOccurrences(of: ".", with: decimalSeparator)
    }

    func length(_ meters: Double) -> String {
        switch system {
        case .metric:
            return "\(number(meters, fractionDigits: 2)) \(symbols.meter)"
        case .imperial:
            let parts = UnitConversion.feetAndInches(meters: meters)
            let sign = meters < 0 ? "-" : ""
            return "\(sign)\(parts.feet)′ \(parts.inches)″"
        }
    }

    func area(_ squareMeters: Double) -> String {
        switch system {
        case .metric: return "\(number(squareMeters, fractionDigits: 1)) \(symbols.squareMeter)"
        case .imperial: return "\(number(squareMeters * UnitConversion.squareFeetPerSquareMeter, fractionDigits: 0)) \(symbols.squareFoot)"
        }
    }

    func volume(_ cubicMeters: Double) -> String {
        switch system {
        case .metric: return "\(number(cubicMeters, fractionDigits: 1)) \(symbols.cubicMeter)"
        case .imperial: return "\(number(cubicMeters * UnitConversion.cubicFeetPerCubicMeter, fractionDigits: 0)) \(symbols.cubicFoot)"
        }
    }

    /// Paint amount that is already expressed in the display unit (liters or gallons).
    func paintAmount(_ value: Double) -> String {
        "\(compactNumber(value)) \(system == .metric ? symbols.liter : symbols.gallon)"
    }

    /// Value already in display area units (m² or ft²).
    func displayArea(_ value: Double, fractionDigits: Int = 1) -> String {
        "\(number(value, fractionDigits: fractionDigits)) \(lengthAreaSymbol)"
    }

    /// Value already in display length units (m or ft).
    func displayLength(_ value: Double, fractionDigits: Int = 1) -> String {
        "\(number(value, fractionDigits: fractionDigits)) \(lengthSymbol)"
    }

    var lengthSymbol: String { system == .metric ? symbols.meter : symbols.foot }
    var lengthAreaSymbol: String { system == .metric ? symbols.squareMeter : symbols.squareFoot }
    var smallLengthSymbol: String { system == .metric ? symbols.centimeter : symbols.inch }
    var paintSymbol: String { system == .metric ? symbols.liter : symbols.gallon }

    /// Scale bar length for the plan: 1 m or 3 ft.
    var scaleBarMeters: Double { system == .metric ? 1 : 3 * UnitConversion.metersPerFoot }
    var scaleBarLabel: String { system == .metric ? "1 \(symbols.meter)" : "3 \(symbols.foot)" }

    /// Grid spacing in meters: 0.5 m / 1 m, or 1 ft / 5 ft.
    var gridSpacing: (minor: Double, major: Double) {
        system == .metric ? (0.5, 1.0) : (UnitConversion.metersPerFoot, 5 * UnitConversion.metersPerFoot)
    }
}
