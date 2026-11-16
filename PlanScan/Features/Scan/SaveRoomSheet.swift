// Save sheet after a scan: room name(s) and type(s), target project, then persistence with USDZ export.
import SwiftData
import SwiftUI

@MainActor
struct SaveRoomSheet: View {
    let pending: PendingSave
    let preferredProjectID: UUID?
    let onSaved: (_ roomID: UUID, _ projectID: UUID) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.updatedAt, order: .reverse) private var allProjects: [Project]
    @State private var names: [String]
    @State private var types: [RoomType]
    @State private var projectID: UUID?
    @State private var newProjectName = ""
    @State private var didPickDefault = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(pending: PendingSave, preferredProjectID: UUID?, onSaved: @escaping (_ roomID: UUID, _ projectID: UUID) -> Void) {
        self.pending = pending
        self.preferredProjectID = preferredProjectID
        self.onSaved = onSaved
        _names = State(initialValue: pending.scans.map(\.suggestedName))
        _types = State(initialValue: pending.scans.map(\.suggestedType))
    }

    private var projects: [Project] { allProjects.filter { !$0.isSample } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(pending.scans.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Room name", text: $names[index])
                                .font(.headline)
                            Picker("Room type", selection: $types[index]) {
                                ForEach(RoomType.allCases, id: \.self) { type in
                                    Label(type.displayName, systemImage: type.systemImage).tag(type)
                                }
                            }
                            Text(verbatim: env.formatter.area(RoomMetrics(room: pending.scans[index].geometry).floorArea))
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(pending.isWholeHome ? "Rooms" : "Room")
                }

                Section {
                    Picker("Project", selection: $projectID) {
                        ForEach(projects) { project in
                            Text(verbatim: project.name).tag(Optional(project.id))
                        }
                        Text("New project").tag(UUID?.none)
                    }
                    if projectID == nil {
                        TextField("Project name", text: $newProjectName)
                    }
                } header: {
                    Text("Project")
                }

                if pending.mergeFailed {
                    Section {
                        Label("The rooms will be saved without a combined plan.", systemImage: "info.circle")
                            .font(.footnote)
                    }
                } else if pending.mergedPlan != nil {
                    Section {
                        Label("A whole-floor plan will be added to the project.", systemImage: "square.grid.3x3.topleft.filled")
                            .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(pending.isWholeHome ? Text("Save home") : Text("Save room"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert(Text("Could not save"), isPresented: Binding(get: { errorMessage != nil },
                                                                set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: errorMessage ?? "")
            }
            .onAppear(perform: pickDefaultProject)
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func pickDefaultProject() {
        guard !didPickDefault else { return }
        didPickDefault = true
        if let preferredProjectID, projects.contains(where: { $0.id == preferredProjectID }) {
            projectID = preferredProjectID
        } else if let home = projects.first(where: { $0.name == AppConfig.defaultProjectName }) ?? projects.first {
            projectID = home.id
        } else {
            projectID = nil
            newProjectName = AppConfig.defaultProjectName
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let project: Project
        if let projectID, let existing = projects.first(where: { $0.id == projectID }) {
            project = existing
        } else {
            project = env.projects.createProject(named: newProjectName)
        }
        do {
            var firstRoomID: UUID?
            var savedGeometries: [RoomGeometry] = []
            for (index, scan) in pending.scans.enumerated() {
                var geometry = scan.geometry
                let name = names[index].trimmingCharacters(in: .whitespacesAndNewlines)
                geometry.name = name.isEmpty ? scan.suggestedName : name
                geometry.type = types[index]
                let usdz = await ScanPlatform.exportUSDZ(scan, files: env.files)
                let record = try env.projects.saveRoom(geometry, in: project, captureData: scan.captureData, usdzSource: usdz)
                if let usdz { env.files.removeItem(at: usdz) }
                if firstRoomID == nil { firstRoomID = record.id }
                savedGeometries.append(geometry)
            }
            if pending.mergedPlan != nil, savedGeometries.count > 1 {
                try env.projects.saveMergedPlan(FloorPlanModel(rooms: savedGeometries), mergedUSDZ: pending.mergedUSDZ, for: project)
            }
            if let mergedUSDZ = pending.mergedUSDZ { env.files.removeItem(at: mergedUSDZ) }
            Haptics.shared.success()
            if let firstRoomID {
                onSaved(firstRoomID, project.id)
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
