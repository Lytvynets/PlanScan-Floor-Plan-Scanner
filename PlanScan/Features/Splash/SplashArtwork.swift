// Splash artwork drawn in a Canvas: wireframe room with a scanning plane that morphs into a top-down floor plan.
import SwiftUI

enum SplashTiming {
    static let total: Double = 3.5
    static let dotsEnd: Double = 0.6
    static let wireStart: Double = 0.4
    static let wireEnd: Double = 1.6
    static let morphStart: Double = 1.4
    static let morphEnd: Double = 2.2
    static let wordStart: Double = 1.9
    static let taglineStart: Double = 2.5
    static let bracketsStart: Double = 2.6
    static let shimmerStart: Double = 2.75
    static let exitStart: Double = 3.1
}

enum SplashArtwork {
    static let room = DemoRoom()
    static let planScale: Double = 44

    /// Camera for a given morph amount (0 = isometric wireframe, 1 = straight top view).
    static func camera(center: CGPoint, morph: Double) -> IsoCamera {
        IsoCamera(yaw: (45 * Double.pi / 180) * (1 - morph),
                  pitch: IsoCamera.isometricPitch + (Double.pi / 2 - IsoCamera.isometricPitch) * morph,
                  scale: planScale, center: center)
    }

    static func draw(in context: inout GraphicsContext, center: CGPoint, time: Double) {
        let wire = Easing.progress(time, SplashTiming.wireStart, SplashTiming.wireEnd)
        let morph = Easing.easeInOut(Easing.progress(time, SplashTiming.morphStart, SplashTiming.morphEnd))
        let camera = camera(center: center, morph: morph)
        let edges = room.edges
        let cyan = Theme.cyan
        let wallColor = Color(hex: 0xE8F1FF)

        // Edge paths, split into floor edges (become plan walls) and the rest (fade out in the top view).
        var floorPath = Path()
        var detailPath = Path()
        let count = Double(edges.count)
        for (index, edge) in edges.enumerated() {
            let startOffset = 0.62 * Double(index) / max(1, count - 1)
            let edgeProgress = Easing.clamp((wire - startOffset) / 0.38)
            guard edgeProgress > 0 else { continue }
            let a = camera.project(edge.0)
            let b = camera.project(edge.0.lerp(to: edge.1, edgeProgress))
            if index < DemoRoom.floorEdgeCount {
                floorPath.move(to: a)
                floorPath.addLine(to: b)
            } else {
                detailPath.move(to: a)
                detailPath.addLine(to: b)
            }
        }

        let floorWidth = 1.6 + 3.4 * morph
        let detailOpacity = 1 - morph
        // Glow layer.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 6))
            layer.stroke(floorPath, with: .color(cyan.opacity(0.75)), style: StrokeStyle(lineWidth: floorWidth + 3, lineCap: .round))
            layer.stroke(detailPath, with: .color(cyan.opacity(0.6 * detailOpacity)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        let floorColor = morph > 0.5 ? wallColor : cyan
        context.stroke(floorPath, with: .color(floorColor), style: StrokeStyle(lineWidth: floorWidth, lineCap: .round, lineJoin: .round))
        context.stroke(detailPath, with: .color(cyan.opacity(detailOpacity)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        drawScanPlane(in: &context, center: center, time: time, camera: camera)
        if morph > 0.01 {
            drawPlanSymbols(in: &context, camera: camera, morph: morph, time: time)
        }
    }

    /// Horizontal gradient band sweeping over the wireframe from top to bottom.
    private static func drawScanPlane(in context: inout GraphicsContext, center: CGPoint, time: Double, camera: IsoCamera) {
        let progress = Easing.progress(time, SplashTiming.dotsEnd, SplashTiming.wireEnd)
        guard progress > 0, progress < 1 else { return }
        let points = room.edges.flatMap { [camera.project($0.0), camera.project($0.1)] }
        guard let bounds = CGRect(points: points) else { return }
        let bandHeight: CGFloat = 28
        let y = bounds.minY - bandHeight + (bounds.height + bandHeight * 2) * CGFloat(progress)
        let rect = CGRect(x: bounds.minX - 30, y: y - bandHeight / 2, width: bounds.width + 60, height: bandHeight)
        let fade = sin(Double.pi * progress)
        let gradient = Gradient(colors: [Theme.cyan.opacity(0), Theme.cyan.opacity(0.32 * fade), Theme.cyan.opacity(0)])
        context.fill(Path(rect), with: .linearGradient(gradient, startPoint: CGPoint(x: rect.midX, y: rect.minY),
                                                       endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        var line = Path()
        line.move(to: CGPoint(x: rect.minX + 20, y: rect.midY))
        line.addLine(to: CGPoint(x: rect.maxX - 20, y: rect.midY))
        context.stroke(line, with: .color(Theme.cyan.opacity(0.7 * fade)), lineWidth: 1)
    }

    /// Door swing arc and window marks that appear once the model has become a plan.
    private static func drawPlanSymbols(in context: inout GraphicsContext, camera: IsoCamera, morph: Double, time: Double) {
        let mint = Theme.mint
        let d = room.depth / 2
        let hinge = Vec3(x: room.doorCenterX - room.doorWidth / 2, y: 0, z: d)
        let arcProgress = Easing.easeOut(Easing.progress(time, 1.7, SplashTiming.morphEnd))
        if arcProgress > 0 {
            var arc = Path()
            let steps = 24
            for i in 0...steps {
                let angle = -Double.pi / 2 * arcProgress * Double(i) / Double(steps)
                let p = Vec3(x: hinge.x + cos(angle) * room.doorWidth, y: 0, z: hinge.z + sin(angle) * room.doorWidth)
                let point = camera.project(p)
                if i == 0 { arc.move(to: point) } else { arc.addLine(to: point) }
            }
            context.stroke(arc, with: .color(mint.opacity(0.85)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 3]))
            let leafAngle = -Double.pi / 2 * arcProgress
            var leaf = Path()
            leaf.move(to: camera.project(hinge))
            leaf.addLine(to: camera.project(Vec3(x: hinge.x + cos(leafAngle) * room.doorWidth, y: 0,
                                                 z: hinge.z + sin(leafAngle) * room.doorWidth)))
            context.stroke(leaf, with: .color(mint), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        let w = room.width / 2
        let z0 = room.windowCenterZ - room.windowWidth / 2
        let z1 = room.windowCenterZ + room.windowWidth / 2
        var window = Path()
        for offset in [-0.07, 0.07] {
            window.move(to: camera.project(Vec3(x: -w + offset, y: 0, z: z0)))
            window.addLine(to: camera.project(Vec3(x: -w + offset, y: 0, z: z1)))
        }
        context.stroke(window, with: .color(mint.opacity(morph)), lineWidth: 1.4)
    }
}

/// Four viewfinder corner brackets.
struct ViewfinderBrackets: Shape {
    var length: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = min(length, rect.width / 3, rect.height / 3)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return path
    }
}
