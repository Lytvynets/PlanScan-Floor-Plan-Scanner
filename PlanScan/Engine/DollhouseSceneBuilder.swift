// All SceneKit code: builds the stylized "dollhouse" model from the plan and hosts it in an SCNView (swappable for RealityKit).
import SceneKit
import SwiftUI
import UIKit

enum DollhouseSceneBuilder {
    struct Result {
        let scene: SCNScene
        let model: SCNNode
        let camera: SCNNode
    }

    static func build(plan: FloorPlanModel, cutaway: Bool, background: UIColor) -> Result {
        let scene = SCNScene()
        scene.background.contents = background
        let model = SCNNode()
        model.name = "model"
        scene.rootNode.addChildNode(model)

        let bounds = PlanRect(points: PlanLayout.contentPoints(of: plan, rotation: 0))
            ?? PlanRect(minX: -2, minY: -2, maxX: 2, maxY: 2)
        let center = bounds.center
        populate(model, plan: plan, center: center, cutaway: cutaway)

        let extent = max(bounds.width, bounds.height, 2)
        addLights(to: scene, extent: extent)

        let camera = SCNCamera()
        camera.fieldOfView = 40
        camera.zNear = 0.05
        camera.zFar = 400
        camera.wantsHDR = false
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        let distance = Float(extent * 1.05 + 1.5)
        cameraNode.position = SCNVector3(0, distance, distance)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        return Result(scene: scene, model: model, camera: cameraNode)
    }

    /// Rebuilds the model contents (used when the cutaway toggle changes).
    static func populate(_ model: SCNNode, plan: FloorPlanModel, center: Point2D, cutaway: Bool) {
        model.childNodes.forEach { $0.removeFromParentNode() }
        let resolved = ResolvedPlan(plan)
        let allWalls = resolved.walls.map(\.wall)

        for room in plan.rooms {
            let outline = room.outline
            guard outline.count >= 3 else { continue }
            let path = UIBezierPath()
            path.move(to: CGPoint(x: outline[0].x - center.x, y: outline[0].y - center.y))
            for point in outline.dropFirst() {
                path.addLine(to: CGPoint(x: point.x - center.x, y: point.y - center.y))
            }
            path.close()
            let shape = SCNShape(path: path, extrusionDepth: 0.04)
            shape.materials = [material(color: floorColor(for: room.type))]
            let node = SCNNode(geometry: shape)
            node.eulerAngles.x = .pi / 2
            node.position.y = -0.02
            model.addChildNode(node)
        }

        let wallMaterial = material(color: UIColor(hex: 0xF4F1EA))
        let lintelMaterial = material(color: UIColor(hex: 0xE9E4DA))
        for entry in resolved.walls {
            let wall = entry.wall
            let length = wall.length
            guard length > 0.02 else { continue }
            let height = cutaway ? min(wall.height, 1.2) : wall.height
            let startJoined = WallJoins.isJoined(wall, at: wall.start, walls: allWalls)
            let endJoined = WallJoins.isJoined(wall, at: wall.end, walls: allWalls)
            let half = wall.thickness / 2
            for piece in resolved.solidIntervals(of: entry) {
                var s = piece.start, e = piece.end
                if s < 0.005 && startJoined { s -= half }
                if e > length - 0.005 && endJoined { e += half }
                addWallBox(to: model, wall: wall, from: s, to: e, bottom: 0, top: height, center: center, material: wallMaterial)
            }
            for opening in entry.openings {
                guard let interval = opening.interval(on: wall) else { continue }
                switch opening.kind {
                case .door:
                    let top = min(height, opening.sillHeight + opening.height)
                    if height - top > 0.02 {
                        addWallBox(to: model, wall: wall, from: interval.start, to: interval.end, bottom: top, top: height,
                                   center: center, material: lintelMaterial)
                    }
                case .window:
                    let sill = min(height, opening.sillHeight)
                    if sill > 0.02 {
                        addWallBox(to: model, wall: wall, from: interval.start, to: interval.end, bottom: 0, top: sill,
                                   center: center, material: wallMaterial)
                    }
                    let top = min(height, opening.sillHeight + opening.height)
                    if height - top > 0.02 {
                        addWallBox(to: model, wall: wall, from: interval.start, to: interval.end, bottom: top, top: height,
                                   center: center, material: lintelMaterial)
                    }
                case .opening:
                    continue
                }
            }
        }

        for room in plan.rooms {
            for item in room.objects {
                let box = SCNBox(width: CGFloat(max(item.width, 0.05)), height: CGFloat(max(item.height, 0.05)),
                                 length: CGFloat(max(item.depth, 0.05)),
                                 chamferRadius: CGFloat(min(0.03, min(item.width, item.depth, item.height) / 4)))
                box.materials = [material(color: furnitureColor(item.category))]
                let node = SCNNode(geometry: box)
                node.position = SCNVector3(Float(item.center.x - center.x), Float(item.height / 2), Float(item.center.y - center.y))
                node.eulerAngles.y = Float(-item.angle)
                model.addChildNode(node)
            }
        }
    }

    private static func addWallBox(to parent: SCNNode, wall: Wall, from s: Double, to e: Double, bottom: Double, top: Double,
                                   center: Point2D, material: SCNMaterial) {
        guard e - s > 0.005, top - bottom > 0.005 else { return }
        let a = wall.point(at: s)
        let b = wall.point(at: e)
        let mid = (a + b) / 2
        let box = SCNBox(width: CGFloat(e - s), height: CGFloat(top - bottom), length: CGFloat(max(wall.thickness, 0.04)), chamferRadius: 0)
        box.materials = [material]
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(Float(mid.x - center.x), Float((top + bottom) / 2), Float(mid.y - center.y))
        let direction = wall.direction
        node.eulerAngles.y = Float(atan2(-direction.y, direction.x))
        node.castsShadow = true
        parent.addChildNode(node)
    }

    private static func addLights(to scene: SCNScene, extent: Double) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        ambient.light?.color = UIColor(white: 1, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        let light = SCNLight()
        light.type = .directional
        light.intensity = 1100
        light.castsShadow = true
        light.shadowMode = .deferred
        light.shadowRadius = 8
        light.shadowSampleCount = 16
        light.shadowColor = UIColor(white: 0, alpha: 0.45)
        light.shadowMapSize = CGSize(width: 2048, height: 2048)
        light.orthographicScale = CGFloat(extent * 0.8 + 1)
        light.automaticallyAdjustsShadowProjection = true
        sun.light = light
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)
    }

    private static func material(color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = 0.9
        material.metalness.contents = 0.0
        return material
    }

    private static func floorColor(for type: RoomType) -> UIColor {
        let base = UIColor(hex: 0x8E99AA)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        type.uiTint.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k: CGFloat = 0.22
        return UIColor(red: r1 * (1 - k) + r2 * k, green: g1 * (1 - k) + g2 * k, blue: b1 * (1 - k) + b2 * k, alpha: 1)
    }

    private static func furnitureColor(_ category: FurnitureCategory) -> UIColor {
        switch category {
        case .bed: UIColor(hex: 0x6C8EF5)
        case .sofa, .chair: UIColor(hex: 0x3CC9A0)
        case .table: UIColor(hex: 0xD9A35B)
        case .storage: UIColor(hex: 0xB8A48A)
        case .refrigerator, .stove, .oven, .dishwasher, .washerDryer: UIColor(hex: 0xD5DCE6)
        case .sink, .toilet, .bathtub: UIColor(hex: 0xEAF2F8)
        case .television: UIColor(hex: 0x3A4250)
        case .fireplace: UIColor(hex: 0xC2674B)
        case .stairs: UIColor(hex: 0xA7A29A)
        case .other: UIColor(hex: 0x9CA3AF)
        }
    }
}

/// SwiftUI host for the dollhouse: camera control, gentle auto-rotation until the first touch, reset and cutaway.
@MainActor
struct DollhouseSceneView: UIViewRepresentable {
    let plan: FloorPlanModel
    let cutaway: Bool
    let resetToken: Int
    let background: UIColor

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = background
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        let touch = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.userTouched(_:)))
        touch.minimumPressDuration = 0
        touch.cancelsTouchesInView = false
        touch.delegate = context.coordinator
        view.addGestureRecognizer(touch)
        context.coordinator.attach(to: view, plan: plan, cutaway: cutaway, background: background, resetToken: resetToken)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(plan: plan, cutaway: cutaway, background: background, resetToken: resetToken)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var view: SCNView?
        private var plan: FloorPlanModel?
        private var cutaway = false
        private var resetToken = 0
        private var result: DollhouseSceneBuilder.Result?
        private var initialCameraTransform = SCNMatrix4Identity
        private var center = Point2D.zero

        func attach(to view: SCNView, plan: FloorPlanModel, cutaway: Bool, background: UIColor, resetToken: Int) {
            self.view = view
            self.resetToken = resetToken
            rebuild(plan: plan, cutaway: cutaway, background: background)
        }

        func update(plan: FloorPlanModel, cutaway: Bool, background: UIColor, resetToken: Int) {
            if plan != self.plan {
                rebuild(plan: plan, cutaway: cutaway, background: background)
            } else if cutaway != self.cutaway, let model = result?.model {
                self.cutaway = cutaway
                DollhouseSceneBuilder.populate(model, plan: plan, center: center, cutaway: cutaway)
            }
            view?.backgroundColor = background
            result?.scene.background.contents = background
            if resetToken != self.resetToken {
                self.resetToken = resetToken
                resetCamera()
            }
        }

        private func rebuild(plan: FloorPlanModel, cutaway: Bool, background: UIColor) {
            self.plan = plan
            self.cutaway = cutaway
            let bounds = PlanRect(points: PlanLayout.contentPoints(of: plan, rotation: 0))
            center = bounds?.center ?? .zero
            let result = DollhouseSceneBuilder.build(plan: plan, cutaway: cutaway, background: background)
            self.result = result
            view?.scene = result.scene
            view?.pointOfView = result.camera
            initialCameraTransform = result.camera.transform
            let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 40))
            result.model.runAction(spin, forKey: "spin")
        }

        func resetCamera() {
            guard let result else { return }
            view?.pointOfView = result.camera
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.6
            result.camera.transform = initialCameraTransform
            result.model.eulerAngles = SCNVector3Zero
            SCNTransaction.commit()
        }

        @objc func userTouched(_ recognizer: UIGestureRecognizer) {
            if recognizer.state == .began {
                result?.model.removeAction(forKey: "spin")
            }
        }

        nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
