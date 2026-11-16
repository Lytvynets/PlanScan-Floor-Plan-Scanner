// Design tokens: "blueprint at night" colors, gradients, typography, spacing and motion.
import SwiftUI
import UIKit

enum Theme {
    // MARK: Colors
    static let background = Color(hex: 0x060B18)
    static let surface = Color(hex: 0x0E1628)
    static let elevated = Color(hex: 0x142038)
    static let stroke = Color.white.opacity(0.08)
    static let cyan = Color(hex: 0x00E5FF)
    static let blue = Color(hex: 0x2F6BFF)
    static let mint = Color(hex: 0x3CF2B8)
    static let amber = Color(hex: 0xFFB020)
    static let coral = Color(hex: 0xFF5A6E)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    static let accentGradient = LinearGradient(colors: [cyan, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let horizontalAccent = LinearGradient(colors: [cyan, blue], startPoint: .leading, endPoint: .trailing)
    static let backgroundGradient = LinearGradient(colors: [Color(hex: 0x0A1530), background],
                                                   startPoint: .top, endPoint: .bottom)

    // MARK: Layout (8-pt grid)
    static let margin: CGFloat = 20
    static let spacing: CGFloat = 16
    static let smallSpacing: CGFloat = 8
    static let cornerRadius: CGFloat = 22
    static let smallCornerRadius: CGFloat = 14

    // MARK: Motion
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let quickSpring = Animation.spring(response: 0.4, dampingFraction: 0.82)
    static let slowSpring = Animation.spring(response: 0.6, dampingFraction: 0.8)
}

extension Color {
    /// Color from a 0xRRGGBB value.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension UIColor {
    /// Color from a 0xRRGGBB value.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Font {
    /// SF Pro with the expanded width, scaled with Dynamic Type relative to `style`.
    static func expanded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .default, weight: weight).width(.expanded)
    }
}

extension View {
    /// The app's dark background with a soft top glow.
    func appBackground() -> some View {
        background {
            ZStack {
                Theme.background
                RadialGradient(colors: [Theme.blue.opacity(0.18), .clear], center: .top, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
        }
    }

    /// Sheet styling shared by bottom sheets.
    func glassSheet(detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        presentationDetents(detents)
            .presentationBackground(.ultraThinMaterial)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
    }
}

extension RoomType {
    var tint: Color {
        switch self {
        case .living: Theme.blue
        case .bedroom: Theme.mint
        case .kitchen: Theme.amber
        case .bathroom: Theme.cyan
        case .dining: Color(hex: 0xC084FC)
        case .office: Color(hex: 0x60A5FA)
        case .hallway: Color(hex: 0x94A3B8)
        case .other: Color(hex: 0xA3A3A3)
        }
    }

    var uiTint: UIColor {
        switch self {
        case .living: UIColor(hex: 0x2F6BFF)
        case .bedroom: UIColor(hex: 0x3CF2B8)
        case .kitchen: UIColor(hex: 0xFFB020)
        case .bathroom: UIColor(hex: 0x00E5FF)
        case .dining: UIColor(hex: 0xC084FC)
        case .office: UIColor(hex: 0x60A5FA)
        case .hallway: UIColor(hex: 0x94A3B8)
        case .other: UIColor(hex: 0xA3A3A3)
        }
    }
}
