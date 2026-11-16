// Tiny orthographic 3D projection used by the splash, onboarding demos and paywall art.
import SwiftUI

struct Vec3: Hashable {
    var x: Double
    var y: Double
    var z: Double

    static func + (lhs: Vec3, rhs: Vec3) -> Vec3 { Vec3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z) }
    static func - (lhs: Vec3, rhs: Vec3) -> Vec3 { Vec3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z) }
    static func * (lhs: Vec3, rhs: Double) -> Vec3 { Vec3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs) }

    func lerp(to other: Vec3, _ t: Double) -> Vec3 { self + (other - self) * t }
}

/// Orthographic camera: `yaw` rotates around the vertical axis, `pitch` tilts from a front view (0) to a top view (π/2).
struct IsoCamera {
    var yaw: Double
    var pitch: Double
    var scale: Double
    var center: CGPoint

    static let isometricPitch = 35.264 * Double.pi / 180

    func project(_ p: Vec3) -> CGPoint {
        let x1 = p.x * cos(yaw) - p.z * sin(yaw)
        let z1 = p.x * sin(yaw) + p.z * cos(yaw)
        let screenY = -p.y * cos(pitch) + z1 * sin(pitch)
        return CGPoint(x: center.x + CGFloat(x1 * scale), y: center.y + CGFloat(screenY * scale))
    }

    /// Larger values are closer to the viewer (used to sort faces back to front).
    func depth(_ p: Vec3) -> Double {
        let z1 = p.x * sin(yaw) + p.z * cos(yaw)
        return z1 * cos(pitch) + p.y * sin(pitch)
    }
}

enum Easing {
    static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    /// Progress of `time` within [start, end], clamped to 0…1.
    static func progress(_ time: Double, _ start: Double, _ end: Double) -> Double {
        guard end > start else { return time >= end ? 1 : 0 }
        return clamp((time - start) / (end - start))
    }

    static func easeInOut(_ t: Double) -> Double { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }
    static func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }

    /// Damped spring from 0 to 1 with a small overshoot.
    static func spring(_ t: Double, damping: Double = 6.5, frequency: Double = 2.2) -> Double {
        guard t > 0 else { return 0 }
        return 1 - exp(-damping * t) * cos(2 * .pi * frequency * t)
    }
}

/// A simple box room used by the splash and onboarding artwork, in meters, centered at the origin.
struct DemoRoom {
    var width = 4.2
    var depth = 3.6
    var height = 2.6
    var doorCenterX = 1.0
    var doorWidth = 0.9
    var doorHeight = 2.0
    var windowCenterZ = -0.3
    var windowWidth = 1.2
    var windowSill = 0.9
    var windowHeight = 1.2

    /// Wireframe edges in drawing order: floor (split by the door), ceiling, corners, door frame, window frame.
    var edges: [(Vec3, Vec3)] {
        let w = width / 2, d = depth / 2, h = height
        let doorLeft = doorCenterX - doorWidth / 2, doorRight = doorCenterX + doorWidth / 2
        let w0 = windowCenterZ - windowWidth / 2, w1 = windowCenterZ + windowWidth / 2
        return [
            (Vec3(x: -w, y: 0, z: -d), Vec3(x: w, y: 0, z: -d)),
            (Vec3(x: w, y: 0, z: -d), Vec3(x: w, y: 0, z: d)),
            (Vec3(x: w, y: 0, z: d), Vec3(x: doorRight, y: 0, z: d)),
            (Vec3(x: doorLeft, y: 0, z: d), Vec3(x: -w, y: 0, z: d)),
            (Vec3(x: -w, y: 0, z: d), Vec3(x: -w, y: 0, z: -d)),
            (Vec3(x: -w, y: 0, z: -d), Vec3(x: -w, y: h, z: -d)),
            (Vec3(x: w, y: 0, z: -d), Vec3(x: w, y: h, z: -d)),
            (Vec3(x: w, y: 0, z: d), Vec3(x: w, y: h, z: d)),
            (Vec3(x: -w, y: 0, z: d), Vec3(x: -w, y: h, z: d)),
            (Vec3(x: -w, y: h, z: -d), Vec3(x: w, y: h, z: -d)),
            (Vec3(x: w, y: h, z: -d), Vec3(x: w, y: h, z: d)),
            (Vec3(x: w, y: h, z: d), Vec3(x: -w, y: h, z: d)),
            (Vec3(x: -w, y: h, z: d), Vec3(x: -w, y: h, z: -d)),
            (Vec3(x: doorLeft, y: 0, z: d), Vec3(x: doorLeft, y: doorHeight, z: d)),
            (Vec3(x: doorLeft, y: doorHeight, z: d), Vec3(x: doorRight, y: doorHeight, z: d)),
            (Vec3(x: doorRight, y: doorHeight, z: d), Vec3(x: doorRight, y: 0, z: d)),
            (Vec3(x: -w, y: windowSill, z: w0), Vec3(x: -w, y: windowSill, z: w1)),
            (Vec3(x: -w, y: windowSill, z: w1), Vec3(x: -w, y: windowSill + windowHeight, z: w1)),
            (Vec3(x: -w, y: windowSill + windowHeight, z: w1), Vec3(x: -w, y: windowSill + windowHeight, z: w0)),
            (Vec3(x: -w, y: windowSill + windowHeight, z: w0), Vec3(x: -w, y: windowSill, z: w0)),
        ]
    }

    /// Indices of edges that remain visible as plan walls in the top view (floor edges).
    static let floorEdgeCount = 5
}
