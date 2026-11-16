// Full-screen scanning session: RoomCaptureView plus glass overlays (timer, Done, review, next room, merge, errors).
import SwiftUI
import UIKit

@MainActor
struct ScanSessionView: View {
    let onSaved: (_ roomID: UUID, _ projectID: UUID) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var model: ScanCoordinator
    @State private var showCancelConfirm = false

    init(mode: ScanMode, projectID: UUID?, onSaved: @escaping (_ roomID: UUID, _ projectID: UUID) -> Void) {
        self.onSaved = onSaved
        _model = State(initialValue: ScanCoordinator(mode: mode, projectID: projectID))
    }

    var body: some View {
        ZStack {
            RoomCaptureContainer(model: model)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                if model.thermalWarning {
                    thermalBanner
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                bottomArea
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(Theme.spring, value: model.phase)
            .animation(Theme.spring, value: model.thermalWarning)
        }
        .statusBarHidden(true)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            model.activate()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            model.deactivate()
        }
        .confirmationDialog(Text("Discard this scan?"), isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Discard scan", role: .destructive) {
                model.cancelCapture?()
                dismiss()
            }
            Button("Keep scanning", role: .cancel) {}
        } message: {
            Text("Rooms that are not saved will be lost.")
        }
        .sheet(item: $model.pendingSave) { pending in
            SaveRoomSheet(pending: pending, preferredProjectID: model.projectID) { roomID, projectID in
                dismiss()
                onSaved(roomID, projectID)
            }
        }
        .alert(Text("Rooms saved separately"), isPresented: Binding(get: { model.mergeNotice != nil },
                                                                    set: { if !$0 { model.mergeNotice = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: model.mergeNotice ?? "")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                if model.phase == .scanning || !model.collected.isEmpty || model.current != nil {
                    showCancelConfirm = true
                } else {
                    dismiss()
                }
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            if model.mode == .wholeHome {
                Text("Room \(model.roomNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = model.phase == .scanning ? max(0, Int(context.date.timeIntervalSince(model.startedAt))) : 0
                Text(verbatim: String(format: "%02d:%02d", seconds / 60, seconds % 60))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(.ultraThinMaterial, in: Capsule())
                    .opacity(model.phase == .scanning ? 1 : 0.4)
            }
        }
    }

    private var thermalBanner: some View {
        Label("Your iPhone is getting hot — finish this room soon", systemImage: "thermometer.sun.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.background)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.amber, in: Capsule())
    }

    // MARK: Bottom area by phase

    @ViewBuilder
    private var bottomArea: some View {
        switch model.phase {
        case .scanning:
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let enabled = model.canFinishRoom(at: context.date)
                PrimaryButton("Done", systemImage: "checkmark", isEnabled: enabled) {
                    model.finishRoom()
                }
            }
            .padding(.bottom, 8)
        case .processing:
            statusCard(title: "Processing your room…", systemImage: nil, showsProgress: true)
        case .merging:
            statusCard(title: "Combining rooms into one plan…", systemImage: nil, showsProgress: true)
        case .review:
            reviewCard
        case .betweenRooms:
            VStack(spacing: 14) {
                Label("Walk to the next room — keep the camera pointing ahead", systemImage: "figure.walk")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("\(model.collected.count) rooms captured")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                PrimaryButton("Start next room", systemImage: "viewfinder") {
                    model.startNextRoom()
                }
                SecondaryButton("Finish home", systemImage: "house.fill") {
                    Task { await model.finishHome(files: env.files) }
                }
            }
            .padding(18)
            .glassCardBackground()
        case .interrupted(let message), .failed(let message):
            VStack(spacing: 14) {
                Label {
                    Text(verbatim: message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.amber)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                PrimaryButton("Start again", systemImage: "arrow.clockwise") {
                    model.restartAfterProblem()
                }
                if !model.collected.isEmpty {
                    SecondaryButton("Finish home", systemImage: "house.fill") {
                        Task { await model.finishHome(files: env.files) }
                    }
                }
            }
            .padding(18)
            .glassCardBackground()
        }
    }

    private func statusCard(title: LocalizedStringKey, systemImage: String?, showsProgress: Bool) -> some View {
        HStack(spacing: 12) {
            if showsProgress {
                ProgressView().tint(.white)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassCardBackground()
        .padding(.bottom, 8)
    }

    private var reviewCard: some View {
        VStack(spacing: 12) {
            if let scan = model.current {
                let metrics = RoomMetrics(room: scan.geometry)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: scan.suggestedName)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(verbatim: env.formatter.area(metrics.floorArea))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    if let quality = scan.geometry.quality {
                        Badge(verbatim: quality.qualityName,
                              systemImage: quality == .low ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                              tint: quality == .high ? Theme.mint : (quality == .medium ? Theme.amber : Theme.coral))
                    }
                }
            }
            if model.mode == .wholeHome {
                PrimaryButton("Save & scan next room", systemImage: "plus.viewfinder") {
                    model.saveAndScanNext()
                }
                HStack(spacing: 10) {
                    SecondaryButton("Rescan", systemImage: "arrow.counterclockwise") { model.rescan() }
                    SecondaryButton("Finish home", systemImage: "house.fill") {
                        Task { await model.finishHome(files: env.files) }
                    }
                }
            } else {
                PrimaryButton("Save room", systemImage: "square.and.arrow.down") {
                    model.saveCurrentRoom()
                }
                SecondaryButton("Rescan", systemImage: "arrow.counterclockwise") { model.rescan() }
            }
        }
        .padding(18)
        .glassCardBackground()
    }
}
