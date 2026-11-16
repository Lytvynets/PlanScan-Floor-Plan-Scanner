// Animated splash (3.5 s): LiDAR dot field → wireframe room → top-down plan → wordmark → viewfinder → exit.
import SwiftUI

@MainActor
struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if reduceMotion {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSince(start)
                    let opacity = t < 0.4 ? t / 0.4 : (t > 0.7 ? max(0, (1.0 - t) / 0.3) : 1)
                    StaticLogo()
                        .opacity(opacity)
                }
            } else {
                TimelineView(.animation) { timeline in
                    SplashFrame(time: min(timeline.date.timeIntervalSince(start), SplashTiming.total))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "PlanScan"))
        .task { await run() }
    }

    private func run() async {
        start = Date()
        if reduceMotion {
            try? await Task.sleep(for: .seconds(1.0))
        } else {
            try? await Task.sleep(for: .seconds(SplashTiming.bracketsStart))
            Haptics.shared.light()
            try? await Task.sleep(for: .seconds(SplashTiming.total - SplashTiming.bracketsStart))
        }
        guard !finished else { return }
        finished = true
        onFinished()
    }
}

/// One frame of the splash timeline. Everything is derived from `time`, so it renders identically at any frame rate.
@MainActor
private struct SplashFrame: View {
    let time: Double

    private var units: UnitSystem { Locale.current.measurementSystem == .us ? .imperial : .metric }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let planCenter = CGPoint(x: size.width / 2, y: size.height / 2 - 80)
            let exit = Easing.progress(time, SplashTiming.exitStart, SplashTiming.total)
            ZStack {
                Canvas { context, canvasSize in
                    let pulse = Easing.progress(time, 0, SplashTiming.dotsEnd + 0.45)
                    let calm = 1 - 0.55 * Easing.progress(time, 1.6, 2.6)
                    DotField.draw(in: &context, size: canvasSize, baseOpacity: 0.11 * calm,
                                  pulses: [pulse * 1.15], pulseStrength: calm)
                }
                Canvas { context, _ in
                    SplashArtwork.draw(in: &context, center: planCenter, time: time)
                }
                dimensionLabels(center: planCenter)
                wordmark
                    .position(x: size.width / 2, y: planCenter.y + 152)
                tagline
                    .position(x: size.width / 2, y: planCenter.y + 196)
                brackets
                    .position(x: size.width / 2, y: planCenter.y + 62)
            }
            .scaleEffect(1 + 0.35 * exit * exit)
            .blur(radius: 14 * exit)
            .opacity(1 - exit)
        }
        .ignoresSafeArea()
    }

    // MARK: Dimension labels counting up

    @ViewBuilder
    private func dimensionLabels(center: CGPoint) -> some View {
        let count = Easing.easeOut(Easing.progress(time, 1.6, SplashTiming.morphEnd))
        let visible = Easing.progress(time, 1.55, 1.8)
        let room = SplashArtwork.room
        let scale = SplashArtwork.planScale
        let formatter = UnitFormatter.localized(units)
        Text(verbatim: formatter.length(room.width * count))
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.cyan)
            .position(x: center.x, y: center.y - CGFloat(room.depth / 2 * scale) - 20)
            .opacity(visible)
        Text(verbatim: formatter.length(room.depth * count))
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.cyan)
            .rotationEffect(.degrees(-90))
            .position(x: center.x + CGFloat(room.width / 2 * scale) + 22, y: center.y)
            .opacity(visible)
    }

    // MARK: Wordmark

    private var letters: some View {
        let characters = Array("PlanScan")
        return HStack(spacing: 0) {
            ForEach(characters.indices, id: \.self) { index in
                let begin = SplashTiming.wordStart + 0.04 * Double(index)
                let p = Easing.easeOut(Easing.progress(time, begin, begin + 0.38))
                Text(verbatim: String(characters[index]))
                    .opacity(p)
                    .offset(y: 12 * (1 - p))
                    .blur(radius: 8 * (1 - p))
            }
        }
        .font(.system(size: 38, weight: .bold).width(.expanded))
        .foregroundStyle(Color.white)
        .fixedSize()
    }

    private var wordmark: some View {
        letters
            .overlay {
                GeometryReader { geo in
                    let s = Easing.progress(time, SplashTiming.shimmerStart, SplashTiming.exitStart)
                    LinearGradient(colors: [.clear, Theme.cyan.opacity(0.9), .white, Theme.cyan.opacity(0.9), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 80)
                        .offset(x: -80 + (geo.size.width + 160) * CGFloat(s))
                        .opacity(s > 0 && s < 1 ? 1 : 0)
                }
                .mask(letters)
            }
    }

    private var tagline: some View {
        let p = Easing.easeOut(Easing.progress(time, SplashTiming.taglineStart, SplashTiming.taglineStart + 0.3))
        return Text("LiDAR Room Measure, 3D & PDF")
            .font(.subheadline.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.textSecondary)
            .opacity(p)
            .offset(y: 8 * (1 - p))
            .fixedSize()
    }

    // MARK: Viewfinder

    private var brackets: some View {
        let local = time - SplashTiming.bracketsStart
        let snap = local > 0 ? Easing.spring(local, damping: 9, frequency: 2.6) : 0
        let opacity = Easing.progress(time, SplashTiming.bracketsStart, SplashTiming.bracketsStart + 0.08)
        let inset = 26 * (1 - snap)
        return ViewfinderBrackets(length: 30)
            .stroke(Theme.horizontalAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 290 + inset * 2, height: 330 + inset * 2)
            .opacity(opacity)
            .shadow(color: Theme.cyan.opacity(0.6), radius: 8)
    }
}

/// Static logo used when Reduce Motion is on.
@MainActor
struct StaticLogo: View {
    var body: some View {
        VStack(spacing: 22) {
            Canvas { context, size in
                SplashArtwork.draw(in: &context, center: CGPoint(x: size.width / 2, y: size.height / 2), time: SplashTiming.total)
            }
            .frame(width: 260, height: 200)
            Text(verbatim: "PlanScan")
                .font(.system(size: 38, weight: .bold).width(.expanded))
                .foregroundStyle(Color.white)
            Text("LiDAR Room Measure, 3D & PDF")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
