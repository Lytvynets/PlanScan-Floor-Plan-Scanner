// Scan tab: mode and project pickers, scanning tips and "Start scanning", or a friendly card when LiDAR is unavailable.
import SwiftData
import SwiftUI

@MainActor
struct ScanHomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Project.updatedAt, order: .reverse) private var allProjects: [Project]
    @State private var mode: ScanMode = .singleRoom
    @State private var selectedProjectID: UUID?
    @State private var paywallReason: PaywallReason?
    @State private var showSession = false
    @State private var showManualBuilder = false
    @State private var showTips = false
    @State private var startAfterTips = false

    private var projects: [Project] { allProjects.filter { !$0.isSample } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if ScanCapability.isSupported {
                        supportedContent
                    } else {
                        unsupportedCard
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, 12)
            }
            .appBackground()
            .navigationTitle("Scan")
        }
        .fullScreenCover(isPresented: $showSession) {
            ScanSessionView(mode: mode, projectID: selectedProjectID) { roomID, projectID in
                if mode == .wholeHome {
                    env.router.openProject(projectID)
                    if !env.settings.hasSavedFirstRoom {
                        env.settings.hasSavedFirstRoom = true
                        env.router.celebrateFirstPlan()
                    }
                } else {
                    env.didSaveRoom(roomID, projectID: projectID)
                }
            }
        }
        .sheet(isPresented: $showManualBuilder) {
            ManualRoomBuilderView(preferredProjectID: selectedProjectID)
        }
        .sheet(isPresented: $showTips, onDismiss: {
            if startAfterTips {
                startAfterTips = false
                start()
            }
        }) {
            ScanTipsView {
                env.settings.hasSeenScanTips = true
                startAfterTips = true
                showTips = false
            }
            .glassSheet(detents: [.large])
        }
        .paywallCover($paywallReason)
        .onAppear(perform: applyPreferredProject)
        .onChange(of: env.router.preferredScanProjectID) { applyPreferredProject() }
    }

    private func applyPreferredProject() {
        if let preferred = env.router.preferredScanProjectID {
            selectedProjectID = preferred
            env.router.preferredScanProjectID = nil
        }
    }

    // MARK: Supported

    private var supportedContent: some View {
        VStack(spacing: 20) {
            hero
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Mode")
                HStack(spacing: 10) {
                    modeCard(.singleRoom, title: "Single room", subtitle: "One room, about a minute", systemImage: "viewfinder")
                    modeCard(.wholeHome, title: "Whole home", subtitle: "Several rooms, one plan", systemImage: "house.fill")
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Save to")
                Menu {
                    Picker("Project", selection: $selectedProjectID) {
                        ForEach(projects) { project in
                            Text(verbatim: project.name).tag(Optional(project.id))
                        }
                        Text(verbatim: AppConfig.defaultProjectName).tag(UUID?.none)
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Theme.cyan)
                        Text(verbatim: selectedProjectName)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .font(.body.weight(.medium))
                    .padding(16)
                    .glassCardBackground(cornerRadius: 16)
                }
            }
            Button {
                showTips = true
            } label: {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Theme.amber)
                    Text("Scanning tips")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textTertiary)
                }
                .font(.body.weight(.medium))
                .padding(16)
                .glassCardBackground(cornerRadius: 16)
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
            PrimaryButton("Start scanning", systemImage: "viewfinder") {
                start()
            }
            .padding(.top, 4)
        }
    }

    private var selectedProjectName: String {
        if let selectedProjectID, let project = projects.first(where: { $0.id == selectedProjectID }) {
            return project.name
        }
        return AppConfig.defaultProjectName
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Image(systemName: "viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.accentGradient)
                .symbolEffect(.pulse, options: .repeating)
                .frame(height: 76)
            Text("Scan a room")
                .font(.expanded(.title2, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Walk slowly along the walls. PlanScan detects walls, doors, windows and furniture.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .glassCardBackground()
    }

    private func modeCard(_ value: ScanMode, title: LocalizedStringKey, subtitle: LocalizedStringKey, systemImage: String) -> some View {
        let isSelected = mode == value
        return Button {
            if value == .wholeHome && !env.gate.isUnlocked(.wholeHome) {
                paywallReason = .feature(.wholeHome)
                return
            }
            Haptics.shared.selection()
            withAnimation(Theme.quickSpring) { mode = value }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(isSelected ? Theme.cyan : Theme.textSecondary)
                    Spacer()
                    if value == .wholeHome && !env.gate.isUnlocked(.wholeHome) {
                        Badge("PRO", systemImage: "lock.fill", tint: Theme.amber)
                    }
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .glassCardBackground(cornerRadius: 18, highlighted: isSelected)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func start() {
        if mode == .wholeHome && !env.gate.isUnlocked(.wholeHome) {
            paywallReason = .feature(.wholeHome)
            return
        }
        if !env.gate.canAddRoom(savedRoomCount: env.projects.savedRoomCount()) {
            paywallReason = .roomLimit
            return
        }
        if !env.settings.hasSeenScanTips {
            showTips = true
            return
        }
        showSession = true
    }

    // MARK: Unsupported

    private var unsupportedCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "sensor.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accentGradient)
                .padding(.top, 8)
            Text("Scanning needs a LiDAR sensor")
                .font(.expanded(.title3, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Room scanning works on iPhone Pro models from iPhone 12 Pro and on iPad Pro 2020 or later. Everything else works on this device too.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("Create a room manually", systemImage: "square.and.pencil") {
                if env.gate.canAddRoom(savedRoomCount: env.projects.savedRoomCount()) {
                    showManualBuilder = true
                } else {
                    paywallReason = .roomLimit
                }
            }
            SecondaryButton("Open the sample project", systemImage: "sparkles", tint: Theme.cyan) {
                env.openSampleProject()
            }
        }
        .padding(22)
        .glassCardBackground()
        .padding(.top, 12)
    }
}

/// Paged scanning tips shown before the first scan (and on demand afterwards).
@MainActor
struct ScanTipsView: View {
    let onStart: () -> Void
    @State private var page = 0

    private struct Tip: Identifiable {
        let id: Int
        let systemImage: String
        let title: LocalizedStringKey
        let text: LocalizedStringKey
    }

    private let tips: [Tip] = [
        Tip(id: 0, systemImage: "lightbulb.max.fill", title: "Good light", text: "Turn on the lights and open the curtains so the camera sees every surface."),
        Tip(id: 1, systemImage: "tortoise.fill", title: "Move slowly", text: "Walk at a steady, slow pace and keep the phone upright."),
        Tip(id: 2, systemImage: "arrow.left.and.right", title: "Edge to edge", text: "Scan each wall from corner to corner, including the corners themselves."),
        Tip(id: 3, systemImage: "door.left.hand.closed", title: "Close doors", text: "Closed doors are detected more reliably than open ones."),
        Tip(id: 4, systemImage: "exclamationmark.triangle.fill", title: "Avoid mirrors and glass", text: "Full-height mirrors and glass walls can confuse the sensor."),
        Tip(id: 5, systemImage: "ruler.fill", title: "Rooms up to about 9 × 9 m", text: "Scan larger spaces room by room with Whole home mode."),
    ]

    var body: some View {
        VStack(spacing: 18) {
            Text("Scanning tips")
                .font(.expanded(.title3, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 24)
            TabView(selection: $page) {
                ForEach(tips) { tip in
                    VStack(spacing: 18) {
                        Image(systemName: tip.systemImage)
                            .font(.system(size: 52))
                            .foregroundStyle(Theme.accentGradient)
                            .symbolEffect(.bounce, value: page)
                            .frame(height: 80)
                        Text(tip.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(tip.text)
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassCardBackground()
                    .padding(.horizontal, Theme.margin)
                    .tag(tip.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            PageIndicator(count: tips.count, index: page)
            PrimaryButton(page == tips.count - 1 ? "Start scanning" : "Next", systemImage: page == tips.count - 1 ? "viewfinder" : nil) {
                if page == tips.count - 1 {
                    onStart()
                } else {
                    withAnimation(Theme.spring) { page += 1 }
                }
            }
            .padding(.horizontal, Theme.margin)
            Button("Skip tips") { onStart() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 16)
        }
        .appBackground()
    }
}
