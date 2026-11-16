// Shimmer highlight that sweeps across content, and a shimmering placeholder block for loading states.
import SwiftUI

@MainActor
struct ShimmerModifier: ViewModifier {
    var isActive = true
    var duration: Double = 1.8
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    func body(content: Content) -> some View {
        content.overlay {
            if isActive && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    GeometryReader { geo in
                        let cycle = duration + delay
                        let elapsed = timeline.date.timeIntervalSince(start).truncatingRemainder(dividingBy: cycle)
                        let progress = max(0, min(1, (elapsed - delay) / duration))
                        let bandWidth = max(geo.size.width * 0.5, 40)
                        LinearGradient(colors: [.clear, Color.white.opacity(0.55), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: bandWidth)
                            .offset(x: -bandWidth + CGFloat(progress) * (geo.size.width + bandWidth))
                            .blendMode(.plusLighter)
                    }
                }
                .mask(content)
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func shimmer(isActive: Bool = true, duration: Double = 1.8, delay: Double = 0) -> some View {
        modifier(ShimmerModifier(isActive: isActive, duration: duration, delay: delay))
    }
}

/// Placeholder block used while content (e.g. StoreKit prices) is loading.
@MainActor
struct ShimmerView: View {
    var cornerRadius: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .shimmer()
            .accessibilityLabel(Text("Loading"))
    }
}
