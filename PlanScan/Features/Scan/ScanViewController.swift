// RoomCaptureView host (device only): runs single-room and whole-home RoomPlan sessions and reports to ScanCoordinator.
import SwiftUI
import UIKit

#if canImport(RoomPlan) && !targetEnvironment(simulator)
import ARKit
import RoomPlan

/// RoomCaptureViewDelegate inherits NSCoding; UIViewController already conforms, which is why it hosts the delegates.
final class ScanViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
    private let model: ScanCoordinator
    private let arSession = ARSession()
    private var captureView: RoomCaptureView?
    private var isRunning = false
    private var userStopped = false
    private var observers: [NSObjectProtocol] = []

    init(model: ScanCoordinator) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let captureView: RoomCaptureView
        if model.mode == .wholeHome {
            captureView = RoomCaptureView(frame: view.bounds, arSession: arSession)
        } else {
            captureView = RoomCaptureView(frame: view.bounds)
        }
        captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        captureView.delegate = self
        captureView.captureSession.delegate = self
        view.addSubview(captureView)
        self.captureView = captureView

        model.startCapture = { [weak self] in self?.startSession() }
        model.stopCapture = { [weak self] in self?.stopSession() }
        model.cancelCapture = { [weak self] in self?.cancelSession() }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.didInterrupt() }
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isRunning && model.phase == .scanning {
            startSession()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelSession()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    // MARK: Session control

    private func startSession() {
        guard let captureView else { return }
        userStopped = false
        isRunning = true
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
        model.captureDidStart()
    }

    /// Ends the current room; RoomCaptureView then processes it and calls `captureView(didPresent:error:)`.
    private func stopSession() {
        guard let captureView, isRunning else { return }
        userStopped = true
        isRunning = false
        if model.mode == .wholeHome {
            captureView.captureSession.stop(pauseARSession: false)
        } else {
            captureView.captureSession.stop()
        }
    }

    private func cancelSession() {
        guard isRunning else { return }
        userStopped = true
        isRunning = false
        captureView?.captureSession.stop()
    }

    // MARK: RoomCaptureViewDelegate

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if let error {
            reportFailure(error)
            return false
        }
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        if let error {
            reportFailure(error)
            return
        }
        let number = model.roomNumber
        let scan = ScanPlatform.makeScan(from: processedResult, number: number)
        Task { @MainActor in self.model.didProcess(scan) }
    }

    // MARK: RoomCaptureSessionDelegate

    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        guard let error, !userStopped else { return }
        isRunning = false
        Task { @MainActor in
            self.model.didFail(String(localized: "Scan interrupted — please start again.") + "\n\n" + error.localizedDescription)
        }
    }

    private func reportFailure(_ error: Error) {
        isRunning = false
        Task { @MainActor in
            self.model.didFail(String(localized: "The room could not be processed.") + "\n\n" + error.localizedDescription)
        }
    }
}

@MainActor
struct RoomCaptureContainer: UIViewControllerRepresentable {
    let model: ScanCoordinator

    func makeUIViewController(context: Context) -> ScanViewController {
        ScanViewController(model: model)
    }

    func updateUIViewController(_ controller: ScanViewController, context: Context) {}
}

#else

/// Simulator stub: scanning is never offered here (ScanCapability.isSupported is false).
@MainActor
struct RoomCaptureContainer: View {
    let model: ScanCoordinator

    var body: some View {
        ContentUnavailableView("Scanning needs a LiDAR sensor", systemImage: "viewfinder",
                               description: Text("Use the sample project or create a room manually."))
            .background(Color.black)
    }
}

#endif
