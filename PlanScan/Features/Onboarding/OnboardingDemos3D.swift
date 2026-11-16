// Onboarding demos 3–4: a rotating shaded dollhouse with furniture dropping in, and the export/estimate showcase.
import SwiftUI

// MARK: - Page 3: 3D dollhouse

@MainActor
struct ThreeDDemoView: View {
    let isActive: Bool

    var body: some View {
        DemoTimeline(isActive: isActive, loop: 12, finalTime: 3.5) { t in
            VStack(spacing: 12) {
                Canvas { context, size in
                    DollhouseDemoArt.draw(in: &context, size: size, time: t)
                }
                .padding(.top, 16)
                Chip("View in AR", systemImage: "arkit", isSelected: true)
                    .padding(.bottom, 10)
            }
        }
    }
}

enum DollhouseDemoArt {
    private struct Face {
        var points: [Vec3]
        var color: Color
        var depth: Double
    }

    private struct RGB {
        var r: Double, g: Double, b: Double
    }

    private static let light = Vec3(x: -0.45, y: 1.0, z: 0.55)

    private static func shade(_ base: RGB, normal: Vec3) -> Color {
        let length = (light.x * light.x + light.y * light.y + light.z * light.z).squareRoot()
        let dot = (normal.x * light.x + normal.y * light.y + normal.z * light.z) / length
        let k = 0.42 + 0.58 * max(0, dot)
        return Color(red: min(1, base.r * k), green: min(1, base.g * k), blue: min(1, base.b * k))
    }

    private static func box(min a: Vec3, max b: Vec3, base: RGB, camera: IsoCamera) -> [Face] {
        let quads: [([Vec3], Vec3)] = [
            ([Vec3(x: a.x, y: b.y, z: a.z), Vec3(x: b.x, y: b.y, z: a.z), Vec3(x: b.x, y: b.y, z: b.z), Vec3(x: a.x, y: b.y, z: b.z)], Vec3(x: 0, y: 1, z: 0)),
            ([Vec3(x: a.x, y: a.y, z: b.z), Vec3(x: b.x, y: a.y, z: b.z), Vec3(x: b.x, y: b.y, z: b.z), Vec3(x: a.x, y: b.y, z: b.z)], Vec3(x: 0, y: 0, z: 1)),
            ([Vec3(x: a.x, y: a.y, z: a.z), Vec3(x: b.x, y: a.y, z: a.z), Vec3(x: b.x, y: b.y, z: a.z), Vec3(x: a.x, y: b.y, z: a.z)], Vec3(x: 0, y: 0, z: -1)),
            ([Vec3(x: b.x, y: a.y, z: a.z), Vec3(x: b.x, y: a.y, z: b.z), Vec3(x: b.x, y: b.y, z: b.z), Vec3(x: b.x, y: b.y, z: a.z)], Vec3(x: 1, y: 0, z: 0)),
            ([Vec3(x: a.x, y: a.y, z: a.z), Vec3(x: a.x, y: a.y, z: b.z), Vec3(x: a.x, y: b.y, z: b.z), Vec3(x: a.x, y: b.y, z: a.z)], Vec3(x: -1, y: 0, z: 0)),
        ]
        return quads.map { points, normal in
            let depth = points.map(camera.depth).reduce(0, +) / Double(points.count)
            return Face(points: points, color: shade(base, normal: normal), depth: depth)
        }
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let camera = IsoCamera(yaw: 0.7 + t * 0.3, pitch: 34 * .pi / 180,
                               scale: Double(min(size.width, size.height)) / 6.2,
                               center: CGPoint(x: size.width / 2, y: size.height * 0.58))
        let w = 2.1, d = 1.75, h = 1.15, th = 0.12
        var faces: [Face] = []
        let floor = [Vec3(x: -w, y: 0, z: -d), Vec3(x: w, y: 0, z: -d), Vec3(x: w, y: 0, z: d), Vec3(x: -w, y: 0, z: d)]
        faces.append(Face(points: floor, color: Color(hex: 0x16294A), depth: -100))
        let wallBase = RGB(r: 0.78, g: 0.86, b: 0.98)
        faces += box(min: Vec3(x: -w, y: 0, z: -d), max: Vec3(x: w, y: h, z: -d + th), base: wallBase, camera: camera)
        faces += box(min: Vec3(x: -w, y: 0, z: d - th), max: Vec3(x: w, y: h * 0.55, z: d), base: wallBase, camera: camera)
        faces += box(min: Vec3(x: -w, y: 0, z: -d), max: Vec3(x: -w + th, y: h, z: d), base: wallBase, camera: camera)
        faces += box(min: Vec3(x: w - th, y: 0, z: -d), max: Vec3(x: w, y: h * 0.55, z: d), base: wallBase, camera: camera)

        let furniture: [(Vec3, Vec3, RGB, Double)] = [
            (Vec3(x: -1.6, y: 0, z: -1.5), Vec3(x: 0.2, y: 0.45, z: -0.7), RGB(r: 0.24, g: 0.95, b: 0.72), 0.6),
            (Vec3(x: 0.6, y: 0, z: -1.5), Vec3(x: 1.9, y: 0.5, z: 0.4), RGB(r: 0.25, g: 0.48, b: 1.0), 1.0),
            (Vec3(x: -1.2, y: 0, z: 0.3), Vec3(x: -0.1, y: 0.42, z: 1.1), RGB(r: 1.0, g: 0.7, b: 0.18), 1.4),
        ]
        for (minPoint, maxPoint, color, start) in furniture {
            let local = t - start
            guard local > 0 else { continue }
            let drop = max(0, 1 - Easing.spring(local, damping: 7.5, frequency: 1.8)) * 2.4
            let offset = Vec3(x: 0, y: abs(drop), z: 0)
            faces += box(min: minPoint + offset, max: maxPoint + offset, base: color, camera: camera)
        }

        for face in faces.sorted(by: { $0.depth < $1.depth }) {
            var path = Path()
            path.addLines(face.points.map(camera.project))
            path.closeSubpath()
            context.fill(path, with: .color(face.color))
            context.stroke(path, with: .color(Color.white.opacity(0.12)), lineWidth: 0.6)
        }
    }
}

// MARK: - Page 4: export & estimate

@MainActor
struct ExportDemoView: View {
    let isActive: Bool

    private var formatter: UnitFormatter {
        UnitFormatter.localized(Locale.current.measurementSystem == .us ? .imperial : .metric)
    }

    var body: some View {
        DemoTimeline(isActive: isActive, loop: 6.6, finalTime: 3.4) { t in
            let sheet = min(1.0, Easing.spring(t - 0.1, damping: 7, frequency: 1.4))
            VStack(spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    PaperSheetArt()
                        .frame(width: 136, height: 192)
                        .offset(y: 200 * (1 - sheet))
                        .opacity(t > 0.1 ? 1 : 0)
                    calculatorCard(time: t)
                }
                HStack(spacing: 8) {
                    ForEach(Array(["PDF", "PNG", "DXF", "USDZ"].enumerated()), id: \.offset) { index, name in
                        let e = Easing.easeOut(Easing.progress(t, 0.9 + 0.12 * Double(index), 1.35 + 0.12 * Double(index)))
                        Chip(verbatim: name, isSelected: index == 0)
                            .offset(x: (index.isMultiple(of: 2) ? -1 : 1) * 140 * (1 - e))
                            .opacity(e)
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Theme.margin)
        }
    }

    private func calculatorCard(time t: Double) -> some View {
        let p = Easing.easeOut(Easing.progress(t, 1.6, 2.8))
        let imperial = formatter.system == .imperial
        let paint = imperial ? 3.5 : 12.0
        let flooring = imperial ? 226.0 : 21.0
        let baseboards = imperial ? 56.0 : 17.0
        return VStack(alignment: .leading, spacing: 12) {
            calcRow(.paint, value: formatter.paintAmount(paint * p))
            calcRow(.flooring, value: formatter.displayArea(flooring * p, fractionDigits: 0))
            calcRow(.baseboards, value: formatter.displayLength(baseboards * p, fractionDigits: 0))
        }
        .padding(14)
        .frame(maxWidth: 200)
        .glassCardBackground(cornerRadius: 18)
        .opacity(Easing.progress(t, 1.4, 1.7))
    }

    private func calcRow(_ kind: CalculatorKind, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: kind.systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.cyan)
                .frame(width: 26, height: 26)
                .background(Theme.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: kind.displayName)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(verbatim: value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.white)
            }
        }
    }
}

/// A4 sheet with a mini plan and a title block.
@MainActor
private struct PaperSheetArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 8)
            Canvas { context, size in
                let plan = CGRect(x: 16, y: 26, width: size.width - 32, height: size.height * 0.5)
                var walls = Path()
                walls.addRect(plan)
                walls.move(to: CGPoint(x: plan.midX, y: plan.minY))
                walls.addLine(to: CGPoint(x: plan.midX, y: plan.minY + plan.height * 0.55))
                walls.move(to: CGPoint(x: plan.minX, y: plan.minY + plan.height * 0.62))
                walls.addLine(to: CGPoint(x: plan.minX + plan.width * 0.3, y: plan.minY + plan.height * 0.62))
                context.stroke(walls, with: .color(Color(hex: 0x111827)), lineWidth: 2.4)
                var dims = Path()
                dims.move(to: CGPoint(x: plan.minX, y: plan.minY - 8))
                dims.addLine(to: CGPoint(x: plan.maxX, y: plan.minY - 8))
                context.stroke(dims, with: .color(Color(hex: 0x2563EB)), lineWidth: 0.8)
                let block = CGRect(x: size.width - 70, y: size.height - 44, width: 56, height: 30)
                context.stroke(Path(block), with: .color(Color(hex: 0x9CA3AF)), lineWidth: 0.6)
                for i in 0..<3 {
                    let y = block.minY + 7 + CGFloat(i) * 8
                    var line = Path()
                    line.move(to: CGPoint(x: block.minX + 5, y: y))
                    line.addLine(to: CGPoint(x: block.maxX - 5 - CGFloat(i) * 8, y: y))
                    context.stroke(line, with: .color(Color(hex: 0xD1D5DB)), lineWidth: 2)
                }
                for i in 0..<3 {
                    let y = size.height - 40 + CGFloat(i) * 8
                    var line = Path()
                    line.move(to: CGPoint(x: 16, y: y))
                    line.addLine(to: CGPoint(x: 16 + 40 - CGFloat(i) * 9, y: y))
                    context.stroke(line, with: .color(Color(hex: 0xE5E7EB)), lineWidth: 2)
                }
            }
            Text(verbatim: "1:50")
                .font(.system(size: 8, weight: .bold).monospacedDigit())
                .foregroundStyle(Color(hex: 0x6B7280))
                .padding(.leading, 16)
                .padding(.top, 8)
        }
    }
}
