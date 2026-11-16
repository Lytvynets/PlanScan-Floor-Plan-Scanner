// LiDAR-style dot field with expanding scan pulses, shared by the splash, onboarding and backgrounds.
import SwiftUI

/// Pure drawing routine for the dot grid so the splash can drive it with its own timeline.
enum DotField {
    /// Draws a grid of dots; `pulses` are radii (0…1 of the max radius) of expanding rings that brighten dots.
    static func draw(in context: inout GraphicsContext, size: CGSize, columns: Int = 24, rows: Int = 40,
                     baseOpacity: Double = 0.10, pulses: [Double], pulseStrength: Double = 1, tint: Color = Theme.cyan) {
        guard columns > 1, rows > 1, size.width > 0, size.height > 0 else { return }
        let width = Double(size.width), height = Double(size.height)
        let maxRadius: Double = (width * width + height * height).squareRoot() / 2
        let dx: Double = width / Double(columns - 1)
        let dy: Double = height / Double(rows - 1)
        let band: Double = maxRadius * 0.09
        for row in 0..<rows {
            for column in 0..<columns {
                let px: Double = Double(column) * dx
                let py: Double = Double(row) * dy
                let distance: Double = ((px - width / 2) * (px - width / 2) + (py - height / 2) * (py - height / 2)).squareRoot()
                var boost: Double = 0
                for pulse in pulses where pulse > 0 && pulse < 1.2 {
                    let radius: Double = maxRadius * pulse
                    let delta: Double = (distance - radius) / band
                    let fade: Double = max(0, 1 - pulse * 0.75)
                    boost = max(boost, Foundation.exp(-delta * delta) * fade)
                }
                boost *= pulseStrength
                let point = CGPoint(x: px, y: py)
                let dotRadius: Double = 1.1 + boost * 1.4
                let rect = CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                if boost > 0.05 {
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(min(1, baseOpacity + boost))))
                } else {
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(baseOpacity)))
                }
            }
        }
    }
}

/// Animated background: a calm dot field with a scan pulse every few seconds.
@MainActor
struct DotFieldBackground: View {
    var intensity: Double = 0.6
    var pulsePeriod: Double = 4.5
    var columns = 24
    var rows = 40
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                let phase = elapsed.truncatingRemainder(dividingBy: pulsePeriod) / pulsePeriod
                let pulses = reduceMotion ? [] : [phase * 1.15]
                DotField.draw(in: &context, size: size, columns: columns, rows: rows,
                              baseOpacity: 0.07 + 0.05 * intensity, pulses: pulses, pulseStrength: intensity)
            }
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
