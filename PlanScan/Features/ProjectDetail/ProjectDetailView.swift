// Project detail: totals, whole-floor card, rooms grid and actions (scan, manual room, export, rename, delete).
import SwiftData
import SwiftUI

@MainActor
struct ProjectDetailView: View {
    let projectID: UUID

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Query private var results: [Project]
    @State private var showManualBuilder = false
    @State private var exportSubject: ExportSubject?
    @State private var paywallReason: PaywallReason?
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDelete = false

    init(projectID: UUID) {
        self.projectID = projectID
        _results = Query(filter: #Predicate<Project> { $0.id == projectID })
    }

    var body: some View {
        Group {
            if let project = results.first {
                content(project)
            } else {
                ContentUnavailableView("Project not found", systemImage: "questionmark.folder")
            }
        }
        .appBackground()
        .paywallCover($paywallReason)
        .sheet(isPresented: $showManualBuilder) {
            ManualRoomBuilderView(preferredProjectID: projectID)
        }
        .sheet(item: $exportSubject) { subject in
            ExportSheet(subject: subject)
        }
    }

    @ViewBuilder
    private func content(_ project: Project) -> some View {
        let rooms = project.sortedRooms
        let wholeFloor = env.projects.wholeFloorPlan(for: project)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                summary(project, roomCount: rooms.count)
                if let wholeFloor {
                    NavigationLink(value: ProjectsRoute.wholeFloor(project.id)) {
                        wholeFloorCard(wholeFloor)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
                }
                actions(project)
                SectionHeader("Rooms")
                if rooms.isEmpty {
                    ContentUnavailableView {
                        Label("No rooms yet", systemImage: "square.dashed")
                    } description: {
                        Text("Scan a room or add one manually.")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                        ForEach(rooms) { room in
                            NavigationLink(value: ProjectsRoute.room(room.id)) {
                                RoomCard(room: room)
                            }
                            .buttonStyle(PressableButtonStyle(pressedScale: 0.97))
                            .scrollTransition { view, phase in
                                view.opacity(phase.isIdentity ? 1 : 0.5).scaleEffect(phase.isIdentity ? 1 : 0.95)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
        }
        .navigationTitle(Text(verbatim: project.name))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        renameText = project.name
                        showRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDelete = true
                    } label: {
                        Label("Delete project", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel(Text("More"))
                }
            }
        }
        .alert(Text("Rename project"), isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") { env.projects.rename(project, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(Text("Delete this project?"), isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete project", role: .destructive) { delete(project) }
        } message: {
            Text("All rooms, plans and 3D models in it will be deleted.")
        }
    }

    private func summary(_ project: Project, roomCount: Int) -> some View {
        HStack(spacing: 12) {
            MetricTile("Total area", value: env.formatter.area(project.totalArea), systemImage: "square.dashed", tint: Theme.cyan)
            MetricTile("Rooms", value: "\(roomCount)", systemImage: "square.split.2x2.fill", tint: Theme.mint)
        }
    }

    private func wholeFloorCard(_ plan: FloorPlanModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Whole floor", systemImage: "square.grid.3x3.topleft.filled")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textTertiary)
            }
            PlanThumbnail(plan: plan, showsFurniture: true)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(14)
        .glassCardBackground()
    }

    private func actions(_ project: Project) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                SecondaryButton("Scan a room", systemImage: "viewfinder", tint: Theme.cyan) {
                    env.router.startScan(in: project.id)
                }
                SecondaryButton("Add manually", systemImage: "square.and.pencil") {
                    if env.gate.canAddRoom(savedRoomCount: env.projects.savedRoomCount()) {
                        showManualBuilder = true
                    } else {
                        paywallReason = .roomLimit
                    }
                }
            }
            SecondaryButton("Export project", systemImage: "square.and.arrow.up") {
                exportSubject = ExportSubject.project(project, store: env.projects)
            }
            .disabled(project.rooms.isEmpty)
            .opacity(project.rooms.isEmpty ? 0.5 : 1)
        }
    }

    private func delete(_ project: Project) {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            env.projects.delete(project)
        }
    }
}

@MainActor
struct RoomCard: View {
    @Environment(AppEnvironment.self) private var env
    let room: RoomRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomThumbnail(imageURL: env.projects.thumbnailURL(for: room), plan: env.projects.plan(for: room))
                .frame(height: 110)
                .clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: room.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: room.type.systemImage)
                    Text(verbatim: env.formatter.area(room.area))
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .glassCardBackground(cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }
}

/// Combined plan of all rooms that share coordinates (whole-home scans and the sample).
@MainActor
struct WholeFloorView: View {
    let projectID: UUID
    @Environment(AppEnvironment.self) private var env
    @Query private var results: [Project]
    @State private var mode = 0

    init(projectID: UUID) {
        self.projectID = projectID
        _results = Query(filter: #Predicate<Project> { $0.id == projectID })
    }

    var body: some View {
        VStack(spacing: 12) {
            if let project = results.first, let plan = env.projects.wholeFloorPlan(for: project) {
                Picker("View", selection: $mode) {
                    Text("Plan").tag(0)
                    Text("3D").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.margin)
                if mode == 0 {
                    PlanCanvasScreen(plan: plan, title: project.name)
                } else {
                    Plan3DView(plan: plan, usdzURL: env.projects.mergedUSDZURL(for: project), isScanned: project.mergedPlanFile != nil)
                }
            } else {
                ContentUnavailableView("No combined plan", systemImage: "square.dashed")
            }
        }
        .appBackground()
        .navigationTitle(Text("Whole floor"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
