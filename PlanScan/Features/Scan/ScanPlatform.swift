// RoomPlan glue (device only): wraps captured rooms, exports USDZ and merges whole-home scans. Simulator builds get stubs.
import Foundation

#if canImport(RoomPlan) && !targetEnvironment(simulator)
import RoomPlan

/// The raw RoomPlan result kept for USDZ export and merging.
struct NativeCapturedRoom {
    let room: CapturedRoom
}

enum ScanPlatform {
    /// Converts a processed CapturedRoom into a reviewable scan.
    static func makeScan(from room: CapturedRoom, number: Int) -> CapturedScan {
        let type = CapturedRoomConverter.suggestedType(for: room)
        let name = type?.displayName ?? String(localized: "Room \(number)")
        let geometry = CapturedRoomConverter.convert(room, name: name, type: type ?? .other)
        let captureData = try? JSONEncoder().encode(room)
        return CapturedScan(geometry: geometry, captureData: captureData, suggestedName: name,
                            suggestedType: type ?? .other, native: NativeCapturedRoom(room: room))
    }

    /// Exports the room's parametric USDZ to a temporary file (nil if unavailable).
    static func exportUSDZ(_ scan: CapturedScan, files: FileStore) async -> URL? {
        guard let room = scan.native?.room else { return nil }
        do {
            let url = try files.exportURL(fileName: FileStore.modelFile)
            try await Task.detached(priority: .userInitiated) {
                try room.export(to: url, exportOptions: .parametric)
            }.value
            return url
        } catch {
            return nil
        }
    }

    /// Combines the rooms of a whole-home session into one CapturedStructure (shared coordinates).
    static func merge(_ scans: [CapturedScan], files: FileStore) async throws -> MergedHome {
        let rooms = scans.compactMap { $0.native?.room }
        guard rooms.count >= 2 else { throw ScanError.nothingToMerge }
        let builder = StructureBuilder(options: [.beautifyObjects])
        let structure = try await builder.capturedStructure(from: rooms)
        var merged: [CapturedScan] = []
        for (index, room) in structure.rooms.enumerated() {
            merged.append(makeScan(from: room, number: index + 1))
        }
        if merged.isEmpty { throw ScanError.nothingToMerge }
        var usdzURL: URL?
        if let url = try? files.exportURL(fileName: FileStore.mergedModelFile) {
            do {
                try structure.export(to: url, exportOptions: .parametric)
                usdzURL = url
            } catch {
                usdzURL = nil
            }
        }
        return MergedHome(scans: merged, usdzURL: usdzURL)
    }
}

#else

/// Simulator stub: RoomPlan is unavailable, so there is never a native capture.
struct NativeCapturedRoom {}

enum ScanPlatform {
    static func exportUSDZ(_ scan: CapturedScan, files: FileStore) async -> URL? { nil }

    static func merge(_ scans: [CapturedScan], files: FileStore) async throws -> MergedHome {
        throw ScanError.unsupported
    }
}

#endif
