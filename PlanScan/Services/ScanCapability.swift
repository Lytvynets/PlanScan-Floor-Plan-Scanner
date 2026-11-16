// Whether this device can scan rooms (RoomPlan needs a LiDAR device; it never runs in the Simulator).
import Foundation

#if canImport(RoomPlan) && !targetEnvironment(simulator)
import RoomPlan
#endif

enum ScanCapability {
    static var isSupported: Bool {
        #if canImport(RoomPlan) && !targetEnvironment(simulator)
        return RoomCaptureSession.isSupported
        #else
        return false
        #endif
    }
}
