// Room detail: editable header (name, type, source, quality) and Plan | 3D | Details, with export and calculators.
import SwiftData
import SwiftUI

enum RoomDetailTab: String, CaseIterable, Identifiable {
    case plan, threeD, details
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .plan: "Plan"
        case .threeD: "3D"
        case .details: "Details"
        }
    }
}

@MainActor
struct RoomDetailView: View {
    let roomID: UUID

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Query private var results: [RoomRecord]
    @State private var tab: RoomDetailTab = .plan
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDelete = false
    @State private var exportSubject: ExportSubject?
    @State private var showCalculators = false
    @State private var paywallReason: PaywallReason?

    init(roomID: UUID) {
        self.roomID = roomID
        _results = Query(filter: #Predicate<RoomRecord> { $0.id == roomID })
    }

    var body: some View {
        Group {
            if let room = results.first, let geometry = env.projects.geometry(for: room) {
                content(room, geometry: geometry)
            } else {
                ContentUnavailableView("Room not found", systemImage: "questionmark.square.dashed")
            }
        }
        .appBackground()
        .paywallCover($paywallReason)
        .sheet(item: $exportSubject) { subject in
            ExportSheet(subject: subject)
        }
        .sheet(isPresented: $showCalculators) {
            CalculatorsHubView(roomID: roomID)
        }
    }

    private func content(_ room: RoomRecord, geometry: RoomGeometry) -> some View {
        VStack(spacing: 12) {
            header(room)
            Picker("View", selection: $tab) {
                ForEach(RoomDetailTab.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.margin)
            .sensoryFeedback(.selection, trigger: tab) { _, _ in env.settings.hapticsEnabled }

            switch tab {
            case .plan:
                PlanCanvasScreen(plan: FloorPlanModel(room: geometry), title: room.name)
            case .threeD:
                Plan3DView(plan: FloorPlanModel(room: geometry), usdzURL: env.projects.usdzURL(for: room),
                           isScanned: room.source == .scanned)
            case .details:
                RoomDetailsTab(geometry: geometry)
            }
        }
        .navigationTitle(Text(verbatim: room.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    exportSubject = ExportSubject.room(room, store: env.projects)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("Export"))
                Menu {
                    Button {
                        openCalculators()
                    } label: {
                        Label("Calculators", systemImage: "function")
                    }
                    Button {
                        renameText = room.name
                        showRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDelete = true
                    } label: {
                        Label("Delete room", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Text("More"))
            }
        }
        .alert(Text("Rename room"), isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") { env.projects.rename(room, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(Text("Delete this room?"), isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete room", role: .destructive) { delete(room) }
        } message: {
            Text("The plan, 3D model and calculator notes of this room will be deleted.")
        }
    }

    private func header(_ room: RoomRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                renameText = room.name
                showRename = true
            } label: {
                HStack(spacing: 8) {
                    Text(verbatim: room.name)
                        .font(.expanded(.title2, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Rename room"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        Picker("Room type", selection: Binding(get: { room.type }, set: { env.projects.setType($0, for: room) })) {
                            ForEach(RoomType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.systemImage).tag(type)
                            }
                        }
                    } label: {
                        Chip(verbatim: room.type.displayName, systemImage: room.type.systemImage, isSelected: true)
                    }
                    Badge(verbatim: room.source.displayName, systemImage: room.source.systemImage, tint: Theme.blue)
                    if let quality = room.quality {
                        Badge(verbatim: quality.qualityName, systemImage: quality == .low ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                              tint: quality == .high ? Theme.mint : (quality == .medium ? Theme.amber : Theme.coral))
                        if quality == .low {
                            Text("Consider rescanning")
                                .font(.caption)
                                .foregroundStyle(Theme.coral)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.margin)
        .padding(.top, 4)
    }

    private func openCalculators() {
        if env.gate.isUnlocked(.calculators) {
            showCalculators = true
        } else {
            paywallReason = .feature(.calculators)
        }
    }

    private func delete(_ room: RoomRecord) {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            env.projects.delete(room)
        }
    }
}
