// Platform-neutral scan state machine: scanning → processing → review → save / next room / merge home.
import Foundation
import Observation

enum ScanMode: String, CaseIterable, Identifiable {
    case singleRoom, wholeHome
    var id: String { rawValue }
}

/// A processed room ready for review and saving.
struct CapturedScan: Identifiable {
    let id = UUID()
    var geometry: RoomGeometry
    var captureData: Data?
    var suggestedName: String
    var suggestedType: RoomType
    var native: NativeCapturedRoom?
}

/// Everything the save sheet needs: one room, or all rooms of a whole-home session (optionally merged).
struct PendingSave: Identifiable {
    let id = UUID()
    var scans: [CapturedScan]
    var mergedPlan: FloorPlanModel?
    var mergedUSDZ: URL?
    var mergeFailed = false

    var isWholeHome: Bool { scans.count > 1 }
}

@Observable
@MainActor
final class ScanCoordinator {
    enum Phase: Equatable {
        case scanning
        case processing
        case review
        case betweenRooms
        case merging
        case interrupted(String)
        case failed(String)
    }

    let mode: ScanMode
    let projectID: UUID?
    private(set) var phase: Phase = .scanning
    private(set) var roomNumber = 1
    private(set) var startedAt = Date()
    private(set) var thermalWarning = false
    private(set) var current: CapturedScan?
    private(set) var collected: [CapturedScan] = []
    var pendingSave: PendingSave?
    /// Friendly notice when merging rooms into one structure failed (rooms are then saved individually).
    var mergeNotice: String?

    /// Hooks installed by the capture view controller.
    @ObservationIgnored var startCapture: (() -> Void)?
    @ObservationIgnored var stopCapture: (() -> Void)?
    @ObservationIgnored var cancelCapture: (() -> Void)?
    @ObservationIgnored private var thermalObserver: NSObjectProtocol?

    init(mode: ScanMode, projectID: UUID?) {
        self.mode = mode
        self.projectID = projectID
    }

    var totalRoomsInSession: Int { collected.count + (current == nil ? 0 : 1) }

    func activate() {
        updateThermalState()
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateThermalState() }
        }
    }

    func deactivate() {
        if let thermalObserver { NotificationCenter.default.removeObserver(thermalObserver) }
        thermalObserver = nil
        cancelCapture?()
    }

    private func updateThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        thermalWarning = state == .serious || state == .critical
    }

    // MARK: Events from the capture controller

    func captureDidStart() {
        startedAt = Date()
        phase = .scanning
        Haptics.shared.light()
    }

    func didProcess(_ scan: CapturedScan) {
        current = scan
        phase = .review
        Haptics.shared.success()
    }

    func didFail(_ message: String) {
        phase = .failed(message)
        Haptics.shared.error()
    }

    func didInterrupt() {
        guard phase == .scanning || phase == .processing else { return }
        cancelCapture?()
        phase = .interrupted(String(localized: "Scan interrupted — please start again."))
        Haptics.shared.warning()
    }

    // MARK: User actions

    func canFinishRoom(at date: Date) -> Bool {
        phase == .scanning && date.timeIntervalSince(startedAt) >= 5
    }

    func finishRoom() {
        guard phase == .scanning else { return }
        phase = .processing
        stopCapture?()
    }

    func rescan() {
        current = nil
        startCapture?()
    }

    /// Restarts after an interruption or error, keeping rooms already collected in this session.
    func restartAfterProblem() {
        current = nil
        startCapture?()
    }

    func saveCurrentRoom() {
        guard let current else { return }
        pendingSave = PendingSave(scans: [current])
    }

    func saveAndScanNext() {
        guard let current else { return }
        collected.append(current)
        self.current = nil
        phase = .betweenRooms
    }

    func startNextRoom() {
        roomNumber += 1
        startCapture?()
    }

    /// Merges all rooms of the session with RoomPlan's StructureBuilder and prepares the save sheet.
    func finishHome(files: FileStore) async {
        var scans = collected
        if let current { scans.append(current) }
        guard !scans.isEmpty else { return }
        guard scans.count > 1 else {
            pendingSave = PendingSave(scans: scans)
            return
        }
        phase = .merging
        do {
            let merged = try await ScanPlatform.merge(scans, files: files)
            let plan = FloorPlanModel(rooms: merged.scans.map(\.geometry))
            pendingSave = PendingSave(scans: merged.scans, mergedPlan: plan, mergedUSDZ: merged.usdzURL)
        } catch {
            mergeNotice = String(localized: "The rooms could not be combined into one plan, so they will be saved individually.")
                + "\n\n" + error.localizedDescription
            pendingSave = PendingSave(scans: scans, mergeFailed: true)
        }
        phase = .review
    }
}

/// Result of merging several scanned rooms.
struct MergedHome {
    var scans: [CapturedScan]
    var usdzURL: URL?
}

enum ScanError: LocalizedError {
    case unsupported
    case nothingToMerge

    var errorDescription: String? {
        switch self {
        case .unsupported: String(localized: "Scanning needs a LiDAR sensor.")
        case .nothingToMerge: String(localized: "There are no rooms to combine.")
        }
    }
}
