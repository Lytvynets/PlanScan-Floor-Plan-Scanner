// Celebratory particle burst drawn with Canvas; fires on appear and whenever `trigger` changes.
import SwiftUI

@MainActor
struct ParticleBurst: View {
    var trigger: Int = 0
    var fireOnAppear = true
    var particleCount = 72
    var duration: Double = 1.7
    var origin: UnitPoint = .center
    var colors: [Color] = [Theme.cyan, Theme.blue, Theme.mint, Theme.amber, .white]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate: Date?

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { timeline in
            Canvas { context, size in
                guard let startDate else { return }
                let t = timeline.date.timeIntervalSince(startDate)
                guard t >= 0, t < duration else { return }
                draw(in: &context, size: size, time: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: trigger) {
            guard !reduceMotion else { return }
            if trigger == 0 && !fireOnAppear { return }
            startDate = Date()
            try? await Task.sleep(for: .seconds(duration + 0.1))
            startDate = nil
        }
    }

    /// Deterministic pseudo-random value in 0…1 for particle `i` and channel `k`.
    private func random(_ i: Int, _ k: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43_758.5453
        return v - floor(v)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let center = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
        let progress = t / duration
        let gravity = 520.0
        for i in 0..<particleCount {
            let angle = random(i, 1) * .pi * 2
            let speed = 180 + random(i, 2) * 360
            let damping = exp(-t * 1.6)
            let distance = speed * (1 - damping) / 1.6
            let x = center.x + cos(angle) * distance
            let y = center.y + sin(angle) * distance - 140 * random(i, 3) * (1 - damping) + 0.5 * gravity * t * t * 0.35
            let alpha = max(0, 1 - progress * progress)
            let width = 4 + random(i, 4) * 6
            let height = 3 + random(i, 5) * 4
            var particle = context
            particle.translateBy(x: x, y: y)
            particle.rotate(by: .radians(random(i, 6) * .pi * 2 + t * (random(i, 7) * 10 - 5)))
            let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
            let color = colors.isEmpty ? Color.white : colors[i % colors.count]
            particle.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color.opacity(alpha)))
        }
    }
}
