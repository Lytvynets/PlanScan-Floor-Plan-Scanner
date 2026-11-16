// Paywall building blocks: blueprint hero with PRO badge, benefit rows, plan cards and StoreKit price text.
import StoreKit
import SwiftUI

/// Human-readable subscription periods and prices, always derived from StoreKit products.
enum SubscriptionText {
    static func duration(_ period: Product.SubscriptionPeriod) -> String {
        let value = period.value
        switch period.unit {
        case .day: return String(localized: "\(value) days")
        case .week: return String(localized: "\(value) weeks")
        case .month: return String(localized: "\(value) months")
        case .year: return String(localized: "\(value) years")
        @unknown default: return String(localized: "\(value) days")
        }
    }

    /// "year", "month" … or "3 months" for multi-unit periods.
    static func perUnit(_ period: Product.SubscriptionPeriod) -> String {
        guard period.value == 1 else { return duration(period) }
        switch period.unit {
        case .day: return String(localized: "day")
        case .week: return String(localized: "week")
        case .month: return String(localized: "month")
        case .year: return String(localized: "year")
        @unknown default: return duration(period)
        }
    }

    /// "$39.99/year"
    static func recurringPrice(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        return "\(product.displayPrice)/\(perUnit(period))"
    }

    /// Price line: "3 days free, then $39.99/year" for an eligible free trial, otherwise "$39.99/year".
    static func priceLine(_ product: Product, eligibleForIntro: Bool) -> String {
        let recurring = recurringPrice(product)
        guard eligibleForIntro, let offer = product.subscription?.introductoryOffer else { return recurring }
        let offerDuration = duration(offer.period)
        switch offer.paymentMode {
        case .freeTrial:
            return String(localized: "\(offerDuration) free, then \(recurring)")
        default:
            return String(localized: "\(offer.displayPrice) for \(offerDuration), then \(recurring)")
        }
    }

    /// "≈ $0.77/week" computed from `product.price` (the only computed price on the paywall).
    static func weeklyPrice(_ product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }
        let weeksPerUnit: Double
        switch period.unit {
        case .day: weeksPerUnit = 1.0 / 7.0
        case .week: weeksPerUnit = 1
        case .month: weeksPerUnit = 52.0 / 12.0
        case .year: weeksPerUnit = 52
        @unknown default: return nil
        }
        let weeks = weeksPerUnit * Double(period.value)
        guard weeks >= 2 else { return nil }
        let weekly = product.price / Decimal(weeks)
        let formatted = weekly.formatted(product.priceFormatStyle)
        return String(localized: "≈ \(formatted)/week")
    }

    static func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }
}

/// Selectable subscription card with gradient border and glow when selected.
@MainActor
struct PlanOptionCard: View {
    let title: LocalizedStringKey
    let priceLine: String
    let detailLine: String?
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.selection()
            action()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().strokeBorder(isSelected ? Theme.cyan : Color.white.opacity(0.3), lineWidth: 2)
                    if isSelected {
                        Circle().fill(Theme.accentGradient).padding(5)
                    }
                }
                .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.expanded(.headline, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.caption2.weight(.heavy))
                                .tracking(0.6)
                                .foregroundStyle(Theme.background)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.mint, in: Capsule())
                        }
                    }
                    Text(verbatim: priceLine)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    if let detailLine {
                        Text(verbatim: detailLine)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(isSelected ? Theme.elevated : Theme.surface.opacity(0.7))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.stroke),
                                  lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: Theme.cyan.opacity(isSelected ? 0.3 : 0), radius: 18, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
        .animation(Theme.quickSpring, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Blueprint hero: the sample apartment drawing itself, with a shimmering PRO badge.
@MainActor
struct PaywallHero: View {
    @State private var start = Date()

    private static let segments: [(CGPoint, CGPoint)] = [
        (CGPoint(x: 0, y: 0), CGPoint(x: 5.2, y: 0)), (CGPoint(x: 5.2, y: 0), CGPoint(x: 8.4, y: 0)),
        (CGPoint(x: 8.4, y: 0), CGPoint(x: 8.4, y: 2.8)), (CGPoint(x: 8.4, y: 2.8), CGPoint(x: 5.2, y: 2.8)),
        (CGPoint(x: 5.2, y: 0), CGPoint(x: 5.2, y: 4.0)), (CGPoint(x: 5.2, y: 4.0), CGPoint(x: 3.8, y: 4.0)),
        (CGPoint(x: 3.8, y: 4.0), CGPoint(x: 3.8, y: 7.4)), (CGPoint(x: 3.8, y: 7.4), CGPoint(x: 0, y: 7.4)),
        (CGPoint(x: 0, y: 7.4), CGPoint(x: 0, y: 0)), (CGPoint(x: 0, y: 4.0), CGPoint(x: 3.8, y: 4.0)),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                draw(in: &context, size: size, time: t)
            }
        }
        .frame(height: 190)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(hex: 0x0A1A33))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.stroke))
        }
        .overlay(alignment: .topTrailing) {
            Text(verbatim: "PRO")
                .font(.system(size: 15, weight: .heavy).width(.expanded))
                .foregroundStyle(Theme.background)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Theme.accentGradient, in: Capsule())
                .shimmer(duration: 1.6, delay: 1.2)
                .shadow(color: Theme.cyan.opacity(0.6), radius: 10)
                .padding(14)
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let planWidth = 8.4, planHeight = 7.4
        let scale = min(Double(size.width) * 0.62 / planWidth, Double(size.height) * 0.78 / planHeight)
        let origin = CGPoint(x: Double(size.width) / 2 - planWidth * scale / 2, y: Double(size.height) / 2 - planHeight * scale / 2)
        func p(_ point: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
        }
        var grid = Path()
        var x = 10.0
        while x < Double(size.width) {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            x += scale * 0.5
        }
        var y = 10.0
        while y < Double(size.height) {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
            y += scale * 0.5
        }
        context.stroke(grid, with: .color(Color(hex: 0x1E3A66).opacity(0.4)), lineWidth: 0.5)

        let progress = Easing.easeInOut(Easing.progress(t, 0.2, 2.2))
        let count = Double(Self.segments.count)
        var walls = Path()
        for (index, segment) in Self.segments.enumerated() {
            let local = Easing.clamp(progress * count - Double(index))
            guard local > 0 else { continue }
            let a = p(segment.0), b = p(segment.1)
            walls.move(to: a)
            walls.addLine(to: CGPoint(x: a.x + (b.x - a.x) * local, y: a.y + (b.y - a.y) * local))
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.stroke(walls, with: .color(Theme.cyan.opacity(0.7)), lineWidth: 6)
        }
        context.stroke(walls, with: .color(Color(hex: 0xE8F1FF)), style: StrokeStyle(lineWidth: 3, lineCap: .square))
        let labels = Easing.progress(t, 2.0, 2.6)
        if labels > 0 {
            let font = Font.system(size: 10, weight: .semibold).monospacedDigit()
            let formatter = UnitFormatter.localized(.metric)
            let areas: [(Double, CGPoint)] = [(20.8, CGPoint(x: 2.6, y: 2.0)), (8.96, CGPoint(x: 6.8, y: 1.4)),
                                              (12.92, CGPoint(x: 1.9, y: 5.7))]
            for (area, position) in areas {
                context.draw(Text(verbatim: formatter.area(area)).font(font).foregroundStyle(Theme.cyan.opacity(labels)),
                             at: p(position))
            }
        }
    }
}

/// One benefit row with a checkmark that animates in.
@MainActor
struct BenefitRow: View {
    let text: LocalizedStringKey
    let systemImage: String
    let isVisible: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.mint)
                .symbolEffect(.bounce, value: isVisible)
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: systemImage)
                .foregroundStyle(Theme.textTertiary)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -16)
        .animation(Theme.spring.delay(0.25 + Double(index) * 0.12), value: isVisible)
    }
}
