// App entry point: creates the SwiftData container and the AppEnvironment, and shows RootView.
import SwiftData
import SwiftUI

@main
@MainActor
struct PlanScanApp: App {
    private let container: ModelContainer
    @State private var environment: AppEnvironment

    init() {
        let container = Self.makeContainer()
        self.container = container
        _environment = State(initialValue: AppEnvironment(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .preferredColorScheme(.dark)
                .tint(Theme.cyan)
        }
        .modelContainer(container)
    }

    /// Opens the persistent store; if it cannot be opened (e.g. after an incompatible change during development)
    /// the store is reset, and as a last resort an in-memory store keeps the app usable.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Project.self, RoomRecord.self])
        let configuration = ModelConfiguration(schema: schema)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }
        let storeURL = configuration.url
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [memory])
        } catch {
            fatalError("PlanScan could not create its data store: \(error.localizedDescription)")
        }
    }
}
