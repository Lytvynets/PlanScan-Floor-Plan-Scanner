// Dependency container injected into SwiftUI (settings, store, projects, router) and in-app navigation state.
import Foundation
import Observation
import SwiftData

enum AppTab: Hashable {
    case projects, scan, tools, settings
}

enum ProjectsRoute: Hashable {
    case project(UUID)
    case room(UUID)
    case wholeFloor(UUID)
}

@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .projects
    var projectsPath: [ProjectsRoute] = []
    /// Shows the "Your first floor plan!" celebration overlay.
    var isCelebrating = false
    var celebrationTrigger = 0
    /// Project preselected in the Scan tab (set by "Scan a room" in a project).
    var preferredScanProjectID: UUID?

    func startScan(in projectID: UUID?) {
        preferredScanProjectID = projectID
        selectedTab = .scan
    }

    func openProject(_ id: UUID) {
        selectedTab = .projects
        projectsPath = [.project(id)]
    }

    func openRoom(_ roomID: UUID, in projectID: UUID?) {
        selectedTab = .projects
        if let projectID {
            projectsPath = [.project(projectID), .room(roomID)]
        } else {
            projectsPath = [.room(roomID)]
        }
    }

    func celebrateFirstPlan() {
        celebrationTrigger += 1
        isCelebrating = true
    }
}

@Observable
@MainActor
final class AppEnvironment {
    let settings: AppSettings
    let store: StoreManager
    let projects: ProjectStore
    let router: AppRouter
    let files: FileStore
    /// Set when bootstrapping finished (sample seeded, StoreKit started).
    private(set) var isBootstrapped = false

    init(container: ModelContainer) {
        let files = FileStore.makeDefault()
        self.files = files
        settings = AppSettings()
        store = StoreManager()
        projects = ProjectStore(context: container.mainContext, files: files)
        router = AppRouter()
        #if DEBUG
        store.debugProOverride = settings.debugProOverride
        #endif
    }

    var gate: FeatureGate { FeatureGate(store: store) }
    var formatter: UnitFormatter { settings.formatter }

    /// Runs during the splash: seeds the sample project on first launch and starts StoreKit.
    func bootstrap() {
        guard !isBootstrapped else { return }
        isBootstrapped = true
        store.start()
        SampleDataLoader.seedIfNeeded(store: projects, settings: settings)
    }

    /// Opens the sample project, re-creating it if it was deleted.
    func openSampleProject() {
        do {
            let project = try SampleDataLoader.ensureSample(store: projects)
            router.openProject(project.id)
        } catch {
            projects.lastErrorMessage = error.localizedDescription
        }
    }

    /// Called after a room is saved: opens it and celebrates the very first floor plan.
    func didSaveRoom(_ roomID: UUID, projectID: UUID?) {
        router.openRoom(roomID, in: projectID)
        if !settings.hasSavedFirstRoom {
            settings.hasSavedFirstRoom = true
            router.celebrateFirstPlan()
        }
    }
}
