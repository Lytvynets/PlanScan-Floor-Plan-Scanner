// Onboarding demos 1–2: scanning on a generic mock phone, and a blueprint plan that draws and measures itself.
import SwiftUI

/// Looping clock for demos: runs only while the page is visible and restarts when it becomes visible again.
@MainActor
struct DemoTimeline<Content: View>: View {
    let isActive: Bool
    let loop: Double
    /// Time shown statically when Reduce Motion is on.
    let finalTime: Double
    @ViewBuilder let content: (Double) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: !isActive || reduceMotion)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            content(reduceMotion ? finalTime : max(0, elapsed.truncatingRemainder(dividingBy: loop)))
        }
        .onChange(of: isActive) { _, active in
            if active { start = Date() }
        }
        .accessibilityHidden(true)
    }
}

/// Generic phone silhouette (rounded rectangle, no device artwork).
@MainActor
struct MockPhone<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color(hex: 0x05070D))
            content
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .padding(9)
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 2)
        }
        .aspectRatio(0.56, contentMode: .fit)
        .shadow(color: Theme.cyan.opacity(0.18), radius: 30, x: 0, y: 12)
    }
}

// MARK: - Page 1: scanning

@MainActor
struct ScanDemoView: View {
    let isActive: Bool

    var body: some View {
        DemoTimeline(isActive: isActive, loop: 5.4, finalTime: 4.6) { t in
            VStack(spacing: 16) {
                MockPhone {
                    ZStack(alignment: .bottom) {
                        Canvas { context, size in
                            ScanDemoArt.draw(in: &context, size: size, time: t)
                        }
                        progressRing(time: t)
                            .padding(.bottom, 22)
                    }
                    .background(RadialGradient(colors: [Color(hex: 0x16233D), Color(hex: 0x05070D)],
                                               center: .center, startRadius: 10, endRadius: 260))
                }
                .padding(.top, 20)
                HStack(spacing: 8) {
                    Chip("LiDAR", systemImage: "dot.radiowaves.left.and.right")
                    Chip("On-device", systemImage: "cpu")
                    Chip("No account", systemImage: "person.crop.circle.badge.xmark")
                }
                .font(.footnote)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, Theme.margin)
        }
    }

    @ViewBuilder
    private func progressRing(time t: Double) -> some View {
        let progress = Easing.progress(t, 0.5, 3.6)
        let done = t >= 3.6
        let check = Easing.spring(t - 3.6, damping: 8, frequency: 2)
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(done ? AnyShapeStyle(Theme.mint) : AnyShapeStyle(Theme.horizontalAccent),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.mint)
                        .scaleEffect(max(0.01, check))
                } else {
                    Text(verbatim: "\(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color.white)
                }
            }
            .frame(width: 52, height: 52)
            Text(done ? "Room captured" : "Scanning…")
                .font(.caption.weight(.semibold))
                .foregroundStyle(done ? Theme.mint : Color.white.opacity(0.8))
        }
    }
}

enum ScanDemoArt {
    static func random(_ i: Int, _ k: Int) -> Double {
        let v = sin(Double(i) * 91.345 + Double(k) * 47.853) * 24_634.6345
        return v - floor(v)
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        // Sparkling LiDAR points.
        let sparkle = Easing.progress(t, 0, 0.8)
        for i in 0..<70 {
            let x = random(i, 1) * size.width
            let y = random(i, 2) * size.height * 0.8
            let twinkle = 0.25 + 0.75 * max(0, sin(t * (2 + random(i, 3) * 4) + random(i, 4) * 6))
            let r = 0.8 + random(i, 5) * 1.4
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(Theme.cyan.opacity(0.7 * twinkle * sparkle)))
        }
        // Isometric room whose walls appear one after another.
        let room = DemoRoom(width: 4.0, depth: 3.4, height: 2.4)
        let camera = IsoCamera(yaw: 40 * .pi / 180, pitch: IsoCamera.isometricPitch,
                               scale: Double(size.width) / 8.2, center: CGPoint(x: size.width / 2, y: size.height * 0.46))
        let w = room.width / 2, d = room.depth / 2
        let corners = [Vec3(x: -w, y: 0, z: -d), Vec3(x: w, y: 0, z: -d), Vec3(x: w, y: 0, z: d), Vec3(x: -w, y: 0, z: d)]
        let floorProgress = Easing.progress(t, 0.3, 0.9)
        if floorProgress > 0 {
            var floor = Path()
            floor.addLines(corners.map(camera.project))
            floor.closeSubpath()
            context.fill(floor, with: .color(Theme.cyan.opacity(0.08 * floorProgress)))
            context.stroke(floor, with: .color(Theme.cyan.opacity(0.9 * floorProgress)), lineWidth: 1.2)
        }
        // Back walls first so front walls overlap them.
        let order = [0, 3, 1, 2]
        for (step, index) in order.enumerated() {
            let p = Easing.easeOut(Easing.progress(t, 0.7 + 0.65 * Double(step), 1.25 + 0.65 * Double(step)))
            guard p > 0 else { continue }
            let a = corners[index], b = corners[(index + 1) % 4]
            let h = room.height * p
            let quad = [a, b, Vec3(x: b.x, y: h, z: b.z), Vec3(x: a.x, y: h, z: a.z)].map(camera.project)
            var path = Path()
            path.addLines(quad)
            path.closeSubpath()
            context.fill(path, with: .color(Theme.cyan.opacity(0.12)))
            context.stroke(path, with: .color(Theme.cyan.opacity(0.95)), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        }
    }
}

// MARK: - Page 2: blueprint plan

@MainActor
struct PlanDemoView: View {
    let isActive: Bool
    private let roomWidth = 4.25
    private let roomDepth = 4.33

    var body: some View {
        DemoTimeline(isActive: isActive, loop: 6.8, finalTime: 3.4) { t in
            GeometryReader { geo in
                let cardWidth = min(geo.size.width - 2 * Theme.margin, 360)
                let cardHeight = min(geo.size.height - 40, cardWidth * 1.02)
                let card = CGRect(x: (geo.size.width - cardWidth) / 2, y: (geo.size.height - cardHeight) / 2 + 6,
                                  width: cardWidth, height: cardHeight)
                let scale = Double(min(card.width, card.height) * 0.56) / max(roomWidth, roomDepth)
                let center = CGPoint(x: card.midX, y: card.midY + 4)
                let imperial = t >= 4.1 && t < 6.2
                let formatter = UnitFormatter.localized(imperial ? .imperial : .metric)
                let count = Easing.easeOut(Easing.progress(t, 1.8, 2.8))
                let badge = Easing.spring(t - 2.8, damping: 7, frequency: 2.2)
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(hex: 0x0A1A33))
                        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.stroke))
                        .frame(width: card.width, height: card.height)
                        .position(x: card.midX, y: card.midY)
                    Canvas { context, _ in
                        PlanDemoArt.draw(in: &context, card: card, center: center, scale: scale, width: roomWidth,
                                         depth: roomDepth, time: t)
                    }
                    Text(verbatim: formatter.length(roomWidth * count))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.cyan)
                        .position(x: center.x, y: center.y - CGFloat(roomDepth / 2 * scale) - 18)
                        .opacity(Easing.progress(t, 1.7, 1.9))
                    Text(verbatim: formatter.length(roomDepth * count))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.cyan)
                        .rotationEffect(.degrees(-90))
                        .position(x: center.x + CGFloat(roomWidth / 2 * scale) + 20, y: center.y)
                        .opacity(Easing.progress(t, 1.7, 1.9))
                    Badge(verbatim: formatter.area(roomWidth * roomDepth), systemImage: "square.dashed", tint: Theme.mint)
                        .scaleEffect(max(0.01, badge))
                        .opacity(t >= 2.8 ? 1 : 0)
                        .position(x: center.x, y: center.y)
                    Chip("m ⇄ ft", systemImage: "ruler", isSelected: imperial)
                        .scaleEffect(0.85)
                        .position(x: card.maxX - 58, y: card.minY + 26)
                        .animation(Theme.quickSpring, value: imperial)
                }
            }
        }
    }
}

enum PlanDemoArt {
    static func draw(in context: inout GraphicsContext, card: CGRect, center: CGPoint, scale: Double,
                     width: Double, depth: Double, time t: Double) {
        // Grid
        var grid = Path()
        let step = scale * 0.5
        var x = Double(card.minX) + 12
        while x < Double(card.maxX) - 12 {
            grid.move(to: CGPoint(x: x, y: card.minY + 12))
            grid.addLine(to: CGPoint(x: x, y: card.maxY - 12))
            x += step
        }
        var y = Double(card.minY) + 12
        while y < Double(card.maxY) - 12 {
            grid.move(to: CGPoint(x: card.minX + 12, y: y))
            grid.addLine(to: CGPoint(x: card.maxX - 12, y: y))
            y += step
        }
        context.stroke(grid, with: .color(Color(hex: 0x1E3A66).opacity(0.45)), lineWidth: 0.5)

        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: center.x + CGFloat(x * scale), y: center.y + CGFloat(y * scale))
        }
        let w = width / 2, d = depth / 2
        let doorLeft = 0.6, doorWidth = 0.9
        let windowStart = -1.4, windowWidth = 1.5
        // Walls (with gaps) traced in order, drawing themselves.
        let segments: [(CGPoint, CGPoint)] = [
            (p(-w, -d), p(windowStart, -d)), (p(windowStart + windowWidth, -d), p(w, -d)),
            (p(w, -d), p(w, d)), (p(w, d), p(doorLeft + doorWidth, d)), (p(doorLeft, d), p(-w, d)), (p(-w, d), p(-w, -d)),
        ]
        let wallProgress = Easing.progress(t, 0.2, 1.6)
        var walls = Path()
        let total = Double(segments.count)
        for (i, segment) in segments.enumerated() {
            let local = Easing.clamp(wallProgress * total - Double(i))
            guard local > 0 else { continue }
            let end = CGPoint(x: segment.0.x + (segment.1.x - segment.0.x) * local,
                              y: segment.0.y + (segment.1.y - segment.0.y) * local)
            walls.move(to: segment.0)
            walls.addLine(to: end)
        }
        context.stroke(walls, with: .color(Color(hex: 0xE8F1FF)), style: StrokeStyle(lineWidth: 6, lineCap: .square))

        // Window
        let windowOpacity = Easing.progress(t, 1.6, 2.0)
        var window = Path()
        for offset in [-2.0, 0.0, 2.0] {
            window.move(to: CGPoint(x: p(windowStart, -d).x, y: p(windowStart, -d).y + offset))
            window.addLine(to: CGPoint(x: p(windowStart + windowWidth, -d).x, y: p(windowStart, -d).y + offset))
        }
        context.stroke(window, with: .color(Theme.mint.opacity(windowOpacity)), lineWidth: 1)

        // Door swinging open
        let swing = Easing.easeOut(Easing.progress(t, 1.4, 2.1))
        if swing > 0 {
            let hinge = p(doorLeft, d)
            let radius = CGFloat(doorWidth * scale)
            var arc = Path()
            for i in 0...20 {
                let a = -Double.pi / 2 * swing * Double(i) / 20
                let point = CGPoint(x: hinge.x + CGFloat(cos(a)) * radius, y: hinge.y + CGFloat(sin(a)) * radius)
                if i == 0 { arc.move(to: point) } else { arc.addLine(to: point) }
            }
            context.stroke(arc, with: .color(Theme.mint.opacity(0.85)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            var leaf = Path()
            leaf.move(to: hinge)
            let angle = -Double.pi / 2 * swing
            leaf.addLine(to: CGPoint(x: hinge.x + CGFloat(cos(angle)) * radius, y: hinge.y + CGFloat(sin(angle)) * radius))
            context.stroke(leaf, with: .color(Theme.mint), lineWidth: 2)
        }

        // Dimension lines
        let dims = Easing.progress(t, 1.7, 2.0)
        if dims > 0 {
            var dimension = Path()
            let top = p(-w, -d).y - 8
            dimension.move(to: CGPoint(x: p(-w, -d).x, y: top))
            dimension.addLine(to: CGPoint(x: p(w, -d).x, y: top))
            let right = p(w, d).x + 8
            dimension.move(to: CGPoint(x: right, y: p(w, -d).y))
            dimension.addLine(to: CGPoint(x: right, y: p(w, d).y))
            context.stroke(dimension, with: .color(Theme.cyan.opacity(0.8 * dims)), lineWidth: 1)
        }
    }
}
