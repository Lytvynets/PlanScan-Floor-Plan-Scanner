// Main tab bar (Projects · Scan · Tools · Settings) with the first-floor-plan celebration overlay.
import SwiftUI

@MainActor
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var router = env.router
        @Bindable var projects = env.projects
        TabView(selection: $router.selectedTab) {
            ProjectsView()
                .tabItem { Label("Projects", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.projects)
            ScanHomeView()
                .tabItem { Label("Scan", systemImage: "viewfinder") }
                .tag(AppTab.scan)
            ToolsView()
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver.fill") }
                .tag(AppTab.tools)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(Theme.cyan)
        .overlay {
            if router.isCelebrating {
                FirstPlanCelebration(trigger: router.celebrationTrigger) {
                    withAnimation(Theme.spring) { router.isCelebrating = false }
                }
                .transition(.opacity)
            }
        }
        .alert(Text("Something went wrong"),
               isPresented: Binding(get: { projects.lastErrorMessage != nil },
                                    set: { if !$0 { projects.lastErrorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: projects.lastErrorMessage ?? "")
        }
    }
}

/// "Your first floor plan!" with a particle burst, shown once after the first saved room.
@MainActor
struct FirstPlanCelebration: View {
    let trigger: Int
    let onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { onDone() }
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(Theme.mint)
                    .symbolEffect(.bounce, value: appeared)
                Text("Your first floor plan!")
                    .font(.expanded(.title2, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Measured, drawn and saved. Explore it in 2D and 3D.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .glassCardBackground()
            .padding(.horizontal, 40)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            ParticleBurst(trigger: trigger, fireOnAppear: true)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(Theme.spring) { appeared = true }
            Haptics.shared.success()
        }
        .task(id: trigger) {
            try? await Task.sleep(for: .seconds(2.6))
            onDone()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
    }
}
