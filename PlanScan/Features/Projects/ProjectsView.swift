// Projects tab: searchable, sortable grid of project cards with rename/delete and the empty state.
import SwiftData
import SwiftUI

enum ProjectSort: String, CaseIterable, Identifiable {
    case recent, name, area
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .recent: "Recent"
        case .name: "Name"
        case .area: "Area"
        }
    }
}

@MainActor
struct ProjectsView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @State private var searchText = ""
    @State private var sort: ProjectSort = .recent
    @State private var renamingProject: Project?
    @State private var renameText = ""
    @State private var deletingProject: Project?
    @Namespace private var zoomNamespace

    private var visibleProjects: [Project] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty ? projects : projects.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.address.localizedCaseInsensitiveContains(query)
        }
        switch sort {
        case .recent: return filtered.sorted { $0.updatedAt > $1.updatedAt }
        case .name: return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .area: return filtered.sorted { $0.totalArea > $1.totalArea }
        }
    }

    var body: some View {
        @Bindable var router = env.router
        NavigationStack(path: $router.projectsPath) {
            Group {
                if projects.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .appBackground()
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $sort) {
                            ForEach(ProjectSort.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            .navigationDestination(for: ProjectsRoute.self) { route in
                switch route {
                case .project(let id):
                    ProjectDetailView(projectID: id)
                        .zoomTransitionDestination(id: id, in: zoomNamespace)
                case .room(let id):
                    RoomDetailView(roomID: id)
                case .wholeFloor(let id):
                    WholeFloorView(projectID: id)
                }
            }
        }
        .alert(Text("Rename project"), isPresented: Binding(get: { renamingProject != nil },
                                                            set: { if !$0 { renamingProject = nil } })) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let project = renamingProject { env.projects.rename(project, to: renameText) }
                renamingProject = nil
            }
            Button("Cancel", role: .cancel) { renamingProject = nil }
        }
        .confirmationDialog(Text("Delete this project?"), isPresented: Binding(get: { deletingProject != nil },
                                                                              set: { if !$0 { deletingProject = nil } }),
                            titleVisibility: .visible) {
            Button("Delete project", role: .destructive) {
                if let project = deletingProject { env.projects.delete(project) }
                deletingProject = nil
            }
        } message: {
            Text("All rooms, plans and 3D models in it will be deleted.")
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 14) {
                ForEach(visibleProjects) { project in
                    NavigationLink(value: ProjectsRoute.project(project.id)) {
                        ProjectCard(project: project)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.97))
                    .zoomTransitionSource(id: project.id, in: zoomNamespace)
                    .contextMenu {
                        Button {
                            renameText = project.name
                            renamingProject = project
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deletingProject = project
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.5)
                            .scaleEffect(phase.isIdentity ? 1 : 0.94)
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
            if visibleProjects.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: Text("Search projects"))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Scan your first room", systemImage: "viewfinder")
        } description: {
            Text("Floor plans you scan or draw appear here. Try the sample project to explore every feature.")
        } actions: {
            Button {
                env.router.startScan(in: nil)
            } label: {
                Text("Scan your first room")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.blue)
            Button("Open the sample project") {
                env.openSampleProject()
            }
            .tint(Theme.cyan)
        }
    }
}

@MainActor
struct ProjectCard: View {
    @Environment(AppEnvironment.self) private var env
    let project: Project

    var body: some View {
        let roomCount = project.rooms.count
        VStack(alignment: .leading, spacing: 0) {
            PlanThumbnail(plan: env.projects.displayPlan(for: project), showsFurniture: false)
                .frame(height: 118)
                .clipped()
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(verbatim: project.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if project.isSample {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(Theme.amber)
                            .accessibilityLabel(Text("Sample"))
                    }
                }
                HStack(spacing: 6) {
                    Text("\(roomCount) rooms")
                    Text(verbatim: "·")
                    Text(verbatim: env.formatter.area(project.totalArea))
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Text(project.updatedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .glassCardBackground()
        .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
